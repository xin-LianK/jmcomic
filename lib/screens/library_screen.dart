import 'package:flutter/material.dart';

import '../services/jm_api.dart';
import '../services/library_store.dart';
import '../theme/animal_theme.dart';
import 'detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.api,
    required this.refreshTick,
  });

  final JmApi api;
  final int refreshTick;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late Future<_LibraryData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick ||
        oldWidget.api.baseUrl != widget.api.baseUrl) {
      _refresh();
    }
  }

  Future<_LibraryData> _load() async {
    final favorites = await LibraryStore.instance.loadFavorites();
    final recent = await LibraryStore.instance.loadRecentAlbums();
    final history = await LibraryStore.instance.loadReadingHistory();
    var watchlist = <WatchedAlbum>[];
    try {
      watchlist = await widget.api.watchlist();
    } catch (_) {
      watchlist = const [];
    }
    return _LibraryData(
      favorites: favorites,
      recent: recent,
      history: history,
      watchlist: watchlist,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // FutureBuilder renders the error state.
    }
  }

  void _openAlbum(String albumId) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => DetailScreen(api: widget.api, albumId: albumId),
          ),
        )
        .then((_) => _refresh());
  }

  Future<void> _setAutoDownload(FavoriteAlbum album, bool enabled) async {
    try {
      await widget.api.setWatchedAlbum(
        id: album.albumId,
        title: album.title,
        coverUrl: album.coverUrl,
        enabled: enabled,
      );
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(enabled ? '已开启定时下载' : '已关闭定时下载')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('定时下载设置失败：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final gutter = width < 480
        ? 12.0
        : width < 900
            ? 16.0
            : 22.0;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('书架', style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(
                          '收藏的本子优先展示，看过的本子会保留最近阅读位置。',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: '刷新',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
          ),
          FutureBuilder<_LibraryData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _LibraryEmpty(
                    icon: Icons.error_outline,
                    title: '书架读取失败',
                    body: snapshot.error.toString(),
                  ),
                );
              }

              final data = snapshot.data!;
              if (data.favorites.isEmpty &&
                  data.recent.isEmpty &&
                  data.history.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _LibraryEmpty(
                    icon: Icons.bookmark_add_outlined,
                    title: '书架还是空的',
                    body: '收藏本子或开始阅读后，这里会自动出现记录。',
                  ),
                );
              }

              return SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 24),
                sliver: SliverToBoxAdapter(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 760;
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _FavoritesSection(
                                favorites: data.favorites,
                                api: widget.api,
                                autoDownloadIds: data.autoDownloadIds,
                                onOpen: _openAlbum,
                                onAutoDownloadChanged: _setAutoDownload,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 2,
                              child: _RecentSection(
                                recent: data.recent,
                                api: widget.api,
                                onOpen: _openAlbum,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 2,
                              child: _HistorySection(
                                history: data.history,
                                api: widget.api,
                                onOpen: _openAlbum,
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FavoritesSection(
                            favorites: data.favorites,
                            api: widget.api,
                            autoDownloadIds: data.autoDownloadIds,
                            onOpen: _openAlbum,
                            onAutoDownloadChanged: _setAutoDownload,
                          ),
                          const SizedBox(height: 22),
                          _RecentSection(
                            recent: data.recent,
                            api: widget.api,
                            onOpen: _openAlbum,
                          ),
                          const SizedBox(height: 22),
                          _HistorySection(
                            history: data.history,
                            api: widget.api,
                            onOpen: _openAlbum,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FavoritesSection extends StatelessWidget {
  const _FavoritesSection({
    required this.favorites,
    required this.api,
    required this.autoDownloadIds,
    required this.onOpen,
    required this.onAutoDownloadChanged,
  });

  final List<FavoriteAlbum> favorites;
  final JmApi api;
  final Set<String> autoDownloadIds;
  final ValueChanged<String> onOpen;
  final void Function(FavoriteAlbum album, bool enabled) onAutoDownloadChanged;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1200
        ? 5
        : width >= 900
            ? 4
            : width >= 560
                ? 3
                : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
            icon: Icons.favorite, title: '收藏', count: favorites.length),
        const SizedBox(height: 10),
        if (favorites.isEmpty)
          const _SectionEmpty(text: '点详情页右上角的心形图标就能收藏。')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: favorites.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: .56,
            ),
            itemBuilder: (context, index) {
              final album = favorites[index];
              return _FavoriteTile(
                album: album,
                api: api,
                autoDownload: autoDownloadIds.contains(album.albumId),
                onAutoDownloadChanged: (enabled) =>
                    onAutoDownloadChanged(album, enabled),
                onTap: () => onOpen(album.albumId),
              );
            },
          ),
      ],
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection({
    required this.recent,
    required this.api,
    required this.onOpen,
  });

  final List<RecentAlbum> recent;
  final JmApi api;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
            icon: Icons.visibility_outlined,
            title: '最近浏览',
            count: recent.length),
        const SizedBox(height: 10),
        if (recent.isEmpty)
          const _SectionEmpty(text: '打开过详情页的本子会出现在这里。')
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final album = recent[index];
              return _RecentRow(
                album: album,
                api: api,
                onTap: () => onOpen(album.albumId),
              );
            },
          ),
      ],
    );
  }
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({
    required this.history,
    required this.api,
    required this.onOpen,
  });

  final List<ReadingProgress> history;
  final JmApi api;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(icon: Icons.history, title: '看过', count: history.length),
        const SizedBox(height: 10),
        if (history.isEmpty)
          const _SectionEmpty(text: '阅读过的本子会出现在这里。')
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final progress = history[index];
              return _HistoryRow(
                  progress: progress,
                  api: api,
                  onTap: () => onOpen(progress.albumId));
            },
          ),
      ],
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({
    required this.album,
    required this.api,
    required this.autoDownload,
    required this.onAutoDownloadChanged,
    required this.onTap,
  });

  final FavoriteAlbum album;
  final JmApi api;
  final bool autoDownload;
  final ValueChanged<bool> onAutoDownloadChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AnimalTheme.radius(AnimalTheme.radiusLg),
      child: Ink(
        decoration: AnimalTheme.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _CoverImage(api: api, coverUrl: album.coverUrl),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: _TinyPill(text: 'JM${album.albumId}'),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 9, 9, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title.isEmpty ? '未命名本子' : album.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
                  ),
                  const SizedBox(height: 5),
                  _AlbumUpdateText(
                    updateDate: album.updateDate,
                    updateWeekday: album.updateWeekday,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.cloud_download_outlined,
                          size: 15, color: theme.colorScheme.secondary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text('定时下载',
                            style: theme.textTheme.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Switch(
                        value: autoDownload,
                        onChanged: onAutoDownloadChanged,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow(
      {required this.progress, required this.api, required this.onTap});

  final ReadingProgress progress;
  final JmApi api;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = progress.episodeTitle.isEmpty
        ? progress.photoTitle
        : progress.episodeTitle;
    return InkWell(
      onTap: onTap,
      borderRadius: AnimalTheme.radius(AnimalTheme.radiusLg),
      child: Ink(
        padding: const EdgeInsets.all(8),
        decoration:
            AnimalTheme.cardDecoration(context, radius: AnimalTheme.radiusLg),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AnimalTheme.radiusMd),
                child: _CoverImage(api: api, coverUrl: progress.coverUrl),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    progress.albumTitle.isEmpty
                        ? 'JM${progress.albumId}'
                        : progress.albumTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
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

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.album,
    required this.api,
    required this.onTap,
  });

  final RecentAlbum album;
  final JmApi api;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AnimalTheme.radius(AnimalTheme.radiusLg),
      child: Ink(
        padding: const EdgeInsets.all(8),
        decoration:
            AnimalTheme.cardDecoration(context, radius: AnimalTheme.radiusLg),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AnimalTheme.radiusMd),
                child: _CoverImage(api: api, coverUrl: album.coverUrl),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title.isEmpty ? 'JM${album.albumId}' : album.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  _AlbumUpdateText(
                    updateDate: album.updateDate,
                    updateWeekday: album.updateWeekday,
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

class _AlbumUpdateText extends StatelessWidget {
  const _AlbumUpdateText({
    required this.updateDate,
    required this.updateWeekday,
  });

  final String updateDate;
  final String updateWeekday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = updateDate.isEmpty
        ? '更新待同步'
        : '$updateDate${updateWeekday.isEmpty ? '' : ' · $updateWeekday更新'}';
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style:
          theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.api, required this.coverUrl});

  final JmApi api;
  final String coverUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (coverUrl.isEmpty) {
      return ColoredBox(
        color: AnimalTheme.softPaper(context),
        child: Icon(Icons.image_outlined, color: scheme.outline),
      );
    }
    return Image.network(
      api.assetUrl(coverUrl),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: AnimalTheme.softPaper(context),
        child: Icon(Icons.image_not_supported_outlined, color: scheme.outline),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(
      {required this.icon, required this.title, required this.count});

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(width: 8),
        _TinyPill(text: '$count'),
      ],
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: AnimalTheme.pillDecoration(
        context,
        selected: true,
        color: scheme.primary.withValues(alpha: .9),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: AnimalTheme.cardDecoration(
        context,
        color: AnimalTheme.softPaper(context),
        elevated: false,
      ),
      child: Text(text,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.outline)),
    );
  }
}

class _LibraryEmpty extends StatelessWidget {
  const _LibraryEmpty(
      {required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 44, color: theme.colorScheme.primary),
          const SizedBox(height: 14),
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class _LibraryData {
  const _LibraryData({
    required this.favorites,
    required this.recent,
    required this.history,
    required this.watchlist,
  });

  final List<FavoriteAlbum> favorites;
  final List<RecentAlbum> recent;
  final List<ReadingProgress> history;
  final List<WatchedAlbum> watchlist;

  Set<String> get autoDownloadIds => watchlist
      .where((item) => item.enabled)
      .map((item) => item.id)
      .where((item) => item.isNotEmpty)
      .toSet();
}
