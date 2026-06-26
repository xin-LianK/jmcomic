import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/album.dart';
import '../services/jm_api.dart';
import '../services/library_store.dart';
import '../widgets/action_chip_button.dart';
import 'catalog_screen.dart';
import 'reader_screen.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    super.key,
    required this.api,
    required this.albumId,
  });

  final JmApi api;
  final String albumId;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late Future<AlbumDetail> _future;
  bool _downloadingAlbum = false;
  final Set<String> _downloadingEpisodeIds = {};
  bool _favorite = false;
  bool _favoriteSaving = false;
  ReadingProgress? _progress;
  Set<String> _readEpisodeIds = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _loadAlbum();
    _loadLocalState();
  }

  Future<AlbumDetail> _loadAlbum() async {
    final album = await widget.api.album(widget.albumId);
    await LibraryStore.instance.saveRecentAlbum(
      RecentAlbum(
        albumId: album.id,
        title: album.title,
        coverUrl: album.coverUrl,
        viewedAt: DateTime.now(),
        updateDate: album.updateDate,
        updateWeekday: album.updateWeekday,
      ),
    );
    return album;
  }

  Future<void> _loadLocalState() async {
    final favorite = await LibraryStore.instance.isFavorite(widget.albumId);
    final progress =
        await LibraryStore.instance.loadAlbumProgress(widget.albumId);
    final readEpisodeIds =
        await LibraryStore.instance.loadReadEpisodeIds(widget.albumId);
    if (!mounted) return;
    setState(() {
      _favorite = favorite;
      _progress = progress;
      _readEpisodeIds = readEpisodeIds;
    });
  }

  Future<void> _downloadAlbum(AlbumDetail album) async {
    setState(() => _downloadingAlbum = true);
    try {
      final job = await widget.api.downloadAlbum(
        album.id,
        albumTitle: album.title,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '已加入服务器下载队列：${job.albumTitle.isEmpty ? 'JM${job.jmId}' : job.albumTitle}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('服务器下载任务创建失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingAlbum = false);
    }
  }

  Future<void> _downloadPhoto(AlbumDetail album, Episode episode) async {
    setState(() => _downloadingEpisodeIds.add(episode.id));
    try {
      final job = await widget.api.downloadPhoto(
        episode.id,
        albumId: album.id,
        albumTitle: album.title,
        episodeTitle: episode.title,
        episodeIndex: episode.index,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '章节已加入服务器下载队列：${job.episodeTitle.isEmpty ? 'JM${job.jmId}' : job.episodeTitle}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('章节下载任务创建失败：$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingEpisodeIds.remove(episode.id));
      }
    }
  }

  Future<void> _toggleFavorite(AlbumDetail album) async {
    if (_favoriteSaving) return;
    final previous = _favorite;
    setState(() {
      _favorite = !previous;
      _favoriteSaving = true;
    });
    try {
      final saved = await LibraryStore.instance.toggleFavorite(
        FavoriteAlbum(
            albumId: album.id,
            title: album.title,
            coverUrl: album.coverUrl,
            savedAt: DateTime.now(),
            updateDate: album.updateDate,
            updateWeekday: album.updateWeekday),
      );
      if (!mounted) return;
      setState(() => _favorite = saved);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(saved ? '已收藏本子' : '已取消收藏')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _favorite = previous);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('收藏状态保存失败：$error')));
    } finally {
      if (mounted) setState(() => _favoriteSaving = false);
    }
  }

  void _openTag(String tag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('标签：$tag')),
          body: SafeArea(
            bottom: false,
            child: CatalogScreen(
                api: widget.api,
                initialSearchQuery: tag,
                initialSearchType: 'tag'),
          ),
        ),
      ),
    );
  }

  Future<void> _saveProgress(AlbumDetail album, Episode episode) async {
    await LibraryStore.instance.saveContinueReading(
      ReadingProgress(
        albumId: album.id,
        albumTitle: album.title,
        coverUrl: album.coverUrl,
        photoId: episode.id,
        photoTitle: episode.title,
        episodeIndex: episode.index,
        episodeTitle: episode.title,
        updatedAt: DateTime.now(),
      ),
    );
    await _loadLocalState();
  }

  void _openReader(AlbumDetail album, Episode episode) {
    _saveProgress(album, episode);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ReaderScreen(
              api: widget.api,
              photoId: episode.id,
              title: episode.title,
              albumId: album.id,
              albumTitle: album.title,
              coverUrl: album.coverUrl,
              episodes: album.episodes,
            ),
          ),
        )
        .then((_) => _loadLocalState());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: FutureBuilder<AlbumDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: () => setState(() => _future = _loadAlbum()),
            );
          }

          final album = snapshot.data!;
          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
                pinned: true,
                title: Text('JM${album.id}'),
                actions: [
                  IconButton(
                    tooltip: _favorite ? '取消收藏' : '收藏',
                    onPressed:
                        _favoriteSaving ? null : () => _toggleFavorite(album),
                    icon: _favoriteSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(_favorite
                            ? Icons.favorite
                            : Icons.favorite_outline),
                  ),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: () => setState(() => _future = _loadAlbum()),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 820;
                      final cover = _Cover(api: widget.api, album: album);
                      final info = _Info(
                        album: album,
                        progress: _progress,
                        downloadingAlbum: _downloadingAlbum,
                        onDownloadAlbum: _downloadingAlbum
                            ? null
                            : () => _downloadAlbum(album),
                        onContinue: _progress == null || album.episodes.isEmpty
                            ? null
                            : () {
                                final episode = album.episodes.firstWhere(
                                  (item) => item.id == _progress!.photoId,
                                  orElse: () => album.episodes.first,
                                );
                                _openReader(album, episode);
                              },
                        onTag: _openTag,
                      );
                      return wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 220, child: cover),
                                const SizedBox(width: 28),
                                Expanded(child: info),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: math.min(
                                      220.0, constraints.maxWidth * .58),
                                  child: cover,
                                ),
                                const SizedBox(height: 18),
                                info
                              ],
                            );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Row(
                    children: [
                      Expanded(
                          child:
                              Text('章节', style: theme.textTheme.titleMedium)),
                      Text(
                        '已看 ${_readEpisodeIds.length}/${album.episodes.length}',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverList.separated(
                  itemCount: album.episodes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final episode = album.episodes[index];
                    final watched = _readEpisodeIds.contains(episode.id);
                    final downloading =
                        _downloadingEpisodeIds.contains(episode.id);
                    return Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: .5),
                        border: Border.all(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: .5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        onTap: () => _openReader(album, episode),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: watched
                              ? theme.colorScheme.secondaryContainer
                              : theme.colorScheme.primaryContainer,
                          foregroundColor: watched
                              ? theme.colorScheme.onSecondaryContainer
                              : theme.colorScheme.onPrimaryContainer,
                          child: watched
                              ? const Icon(Icons.check, size: 18)
                              : Text('${episode.index}'),
                        ),
                        title: Text(
                          episode.title.isEmpty
                              ? '章节 ${episode.index}'
                              : episode.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_episodeSubtitle(episode, watched)),
                        trailing: IconButton.outlined(
                          tooltip: downloading ? '正在下载' : '下载章节',
                          onPressed: downloading
                              ? null
                              : () => _downloadPhoto(album, episode),
                          icon: downloading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.file_download_outlined),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _episodeSubtitle(Episode episode, bool watched) {
    final parts = <String>[
      'Photo ${episode.id}',
      if (episode.fileSize > 0) _formatBytes(episode.fileSize) else '大小未知',
      if (episode.pubDate.isNotEmpty) episode.pubDate,
      if (watched) '已看过',
    ];
    return parts.join(' · ');
  }

  String _formatBytes(num bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    final digits = value >= 100 || index == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[index]}';
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.api, required this.album});

  final JmApi api;
  final AlbumDetail album;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: .72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
          child: Image.network(
            api.assetUrl(album.coverUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.image_not_supported_outlined, color: scheme.outline),
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.album,
    required this.progress,
    required this.downloadingAlbum,
    required this.onDownloadAlbum,
    required this.onContinue,
    required this.onTag,
  });

  final AlbumDetail album;
  final ReadingProgress? progress;
  final bool downloadingAlbum;
  final VoidCallback? onDownloadAlbum;
  final VoidCallback? onContinue;
  final ValueChanged<String> onTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(album.title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Metric(
                icon: Icons.photo_library_outlined,
                label: '${album.pageCount} 页'),
            _Metric(
                icon: Icons.remove_red_eye_outlined,
                label: album.views.isEmpty ? '观看未知' : album.views),
            _Metric(
                icon: Icons.thumb_up_alt_outlined,
                label: album.likes.isEmpty ? '点赞未知' : album.likes),
            _Metric(
                icon: Icons.forum_outlined,
                label:
                    album.commentCount.isEmpty ? '评论未知' : album.commentCount),
          ],
        ),
        const SizedBox(height: 16),
        if (album.tags.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in album.tags.take(30))
                _TagPill(label: tag, onTap: () => onTag(tag)),
            ],
          ),
        const SizedBox(height: 18),
        if (album.authors.isNotEmpty)
          Text('作者：${album.authors.join(' / ')}',
              style: theme.textTheme.bodyMedium),
        if (album.pubDate.isNotEmpty || album.updateDate.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '发布 ${album.pubDate}    更新 ${album.updateDate}${album.updateWeekday.isEmpty ? '' : ' · ${album.updateWeekday}更新'}',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: scheme.outline),
            ),
          ),
        if (album.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(album.description, style: theme.textTheme.bodyLarge),
          ),
        const SizedBox(height: 22),
        if (progress != null) ...[
          _ContinuePanel(progress: progress!, onTap: onContinue),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ActionChipButton(
              icon: Icons.download_for_offline_outlined,
              label: downloadingAlbum ? '加入中' : '服务器下载',
              filled: true,
              onPressed: onDownloadAlbum,
            ),
            ActionChipButton(
              icon: Icons.menu_book_outlined,
              label: '${album.episodes.length} 个章节',
              onPressed: null,
            ),
          ],
        ),
      ],
    );
  }
}

class _ContinuePanel extends StatelessWidget {
  const _ContinuePanel({required this.progress, required this.onTap});

  final ReadingProgress progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = progress.episodeTitle.isEmpty
        ? progress.photoTitle
        : progress.episodeTitle;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: .34)),
        ),
        child: Row(
          children: [
            Icon(Icons.play_circle_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('继续阅读',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: theme.colorScheme.primary)),
                  const SizedBox(height: 2),
                  Text(
                    '第 ${progress.episodeIndex} 话 · ${title.isEmpty ? '未命名章节' : title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color:
                theme.colorScheme.surfaceContainerHighest.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: .55)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: theme.textTheme.labelSmall,
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withValues(alpha: .82),
            scheme.secondaryContainer.withValues(alpha: .74),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.report_problem_outlined, size: 46),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
