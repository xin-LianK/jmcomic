import 'package:flutter/material.dart';

import '../models/album.dart';
import '../services/jm_api.dart';
import '../widgets/action_chip_button.dart';
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

  @override
  void initState() {
    super.initState();
    _future = widget.api.album(widget.albumId);
  }

  Future<void> _downloadAlbum() async {
    setState(() => _downloadingAlbum = true);
    try {
      final job = await widget.api.downloadAlbum(widget.albumId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已加入下载队列：${job.jmId}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载任务创建失败：$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingAlbum = false);
    }
  }

  Future<void> _downloadPhoto(Episode episode) async {
    try {
      final job = await widget.api.downloadPhoto(episode.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('章节已加入队列：${job.jmId}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('章节任务创建失败：$error')),
        );
      }
    }
  }

  void _openReader(Episode episode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          api: widget.api,
          photoId: episode.id,
          title: episode.title,
        ),
      ),
    );
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
              onRetry: () => setState(() => _future = widget.api.album(widget.albumId)),
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
                    tooltip: '刷新',
                    onPressed: () => setState(() => _future = widget.api.album(widget.albumId)),
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
                        downloadingAlbum: _downloadingAlbum,
                        onDownloadAlbum: _downloadingAlbum ? null : _downloadAlbum,
                      );
                      return wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 260, child: cover),
                                const SizedBox(width: 28),
                                Expanded(child: info),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [cover, const SizedBox(height: 18), info],
                            );
                    },
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
                    return Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .5),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor: theme.colorScheme.onPrimaryContainer,
                          child: Text('${episode.index}'),
                        ),
                        title: Text(
                          episode.title.isEmpty ? '章节 ${episode.index}' : episode.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('Photo ${episode.id}'),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton.filledTonal(
                              tooltip: '阅读',
                              onPressed: () => _openReader(episode),
                              icon: const Icon(Icons.chrome_reader_mode_outlined),
                            ),
                            IconButton.outlined(
                              tooltip: '下载章节',
                              onPressed: () => _downloadPhoto(episode),
                              icon: const Icon(Icons.file_download_outlined),
                            ),
                          ],
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
            errorBuilder: (_, __, ___) => Icon(Icons.image_not_supported_outlined, color: scheme.outline),
          ),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
    required this.album,
    required this.downloadingAlbum,
    required this.onDownloadAlbum,
  });

  final AlbumDetail album;
  final bool downloadingAlbum;
  final VoidCallback? onDownloadAlbum;

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
            _Metric(icon: Icons.photo_library_outlined, label: '${album.pageCount} 页'),
            _Metric(icon: Icons.remove_red_eye_outlined, label: album.views.isEmpty ? '观看未知' : album.views),
            _Metric(icon: Icons.thumb_up_alt_outlined, label: album.likes.isEmpty ? '点赞未知' : album.likes),
            _Metric(icon: Icons.forum_outlined, label: album.commentCount.isEmpty ? '评论未知' : album.commentCount),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: album.tags.take(18).map((tag) => _TagPill(label: tag)).toList(),
        ),
        const SizedBox(height: 18),
        if (album.authors.isNotEmpty)
          Text('作者：${album.authors.join(' / ')}', style: theme.textTheme.bodyMedium),
        if (album.pubDate.isNotEmpty || album.updateDate.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '发布 ${album.pubDate}    更新 ${album.updateDate}',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline),
            ),
          ),
        if (album.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(album.description, style: theme.textTheme.bodyLarge),
          ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ActionChipButton(
              icon: Icons.download_for_offline_outlined,
              label: downloadingAlbum ? '加入中' : '下载整本',
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

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .58),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .6)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: theme.textTheme.labelMedium,
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
          Text(label, style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
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
