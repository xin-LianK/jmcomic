import 'package:flutter/material.dart';

import '../models/album.dart';
import '../services/jm_api.dart';
import '../services/library_store.dart';
import 'detail_screen.dart';
import 'reader_screen.dart';

enum CatalogMode { latest, search, day, week, month }

enum CatalogView { grid, list }

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.api,
    this.initialSearchQuery,
    this.initialSearchType = 'site',
  });

  final JmApi api;
  final String? initialSearchQuery;
  final String initialSearchType;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _searchController = TextEditingController();
  CatalogMode _mode = CatalogMode.latest;
  CatalogView _view = CatalogView.grid;
  String _category = 'hanman';
  String _orderBy = 'mr';
  String _timeRange = 'a';
  String _searchType = 'site';
  int _page = 1;
  late Future<AlbumPage> _future;
  ReadingProgress? _continueReading;
  List<FavoriteAlbum> _favorites = const [];

  static const _categories = {
    '0': '全部',
    'doujin': '同人',
    'single': '单本',
    'short': '短篇',
    'hanman': '韩漫',
    'meiman': '美漫',
    '3D': '3D',
    'english_site': '英文',
  };
  static const _orders = {'mr': '最新', 'mv': '观看', 'mp': '图片数', 'tf': '点赞'};
  static const _times = {'a': '全部', 't': '今日', 'w': '本周', 'm': '本月'};
  static const _searchTypes = {
    'site': '站内',
    'work': '作品',
    'author': '作者',
    'tag': '标签',
    'actor': '角色'
  };

  @override
  void initState() {
    super.initState();
    final initialQuery = widget.initialSearchQuery?.trim();
    if (initialQuery != null && initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
      _searchType = widget.initialSearchType;
      _mode = CatalogMode.search;
    }
    _future = _load();
    _loadLibraryState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<AlbumPage> _load({bool forceRefresh = false}) {
    switch (_mode) {
      case CatalogMode.search:
        return widget.api.search(
          query: _searchController.text.trim(),
          page: _page,
          searchType: _searchType,
          orderBy: _orderBy,
          timeRange: _timeRange,
          forceRefresh: forceRefresh,
        );
      case CatalogMode.day:
        return widget.api.ranking(
            period: 'day',
            page: _page,
            category: _category,
            forceRefresh: forceRefresh);
      case CatalogMode.week:
        return widget.api.ranking(
            period: 'week',
            page: _page,
            category: _category,
            forceRefresh: forceRefresh);
      case CatalogMode.month:
        return widget.api.ranking(
            period: 'month',
            page: _page,
            category: _category,
            forceRefresh: forceRefresh);
      case CatalogMode.latest:
        return widget.api.categories(
            page: _page,
            category: _category,
            orderBy: _orderBy,
            timeRange: _timeRange,
            forceRefresh: forceRefresh);
    }
  }

  Future<void> _refresh(
      {bool resetPage = false, bool forceRefresh = false}) async {
    if (resetPage) _page = 1;
    final future = _load(forceRefresh: forceRefresh);
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // FutureBuilder renders the error state.
    }
  }

  void _submitSearch() {
    _mode = CatalogMode.search;
    _refresh(resetPage: true);
  }

  void _openAlbum(AlbumSummary album) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => DetailScreen(api: widget.api, albumId: album.id)))
        .then((_) => _loadLibraryState());
  }

  Future<void> _loadLibraryState() async {
    final progress = await LibraryStore.instance.loadContinueReading();
    final favorites = await LibraryStore.instance.loadFavorites();
    if (!mounted) return;
    setState(() {
      _continueReading = progress;
      _favorites = favorites.take(8).toList();
    });
  }

  void _openContinueReading(ReadingProgress progress) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          api: widget.api,
          photoId: progress.photoId,
          title: progress.photoTitle.isEmpty
              ? progress.episodeTitle
              : progress.photoTitle,
          albumId: progress.albumId,
          albumTitle: progress.albumTitle,
          coverUrl: progress.coverUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 560;
    return RefreshIndicator(
      onRefresh: () => _refresh(forceRefresh: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(_gutter(context), compact ? 8 : 14,
                  _gutter(context), compact ? 6 : 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!compact) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'JM Library',
                            style: theme.textTheme.headlineMedium,
                          ),
                        ),
                        _ViewToggle(
                            value: _view,
                            onChanged: (value) =>
                                setState(() => _view = value)),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_continueReading != null || _favorites.isNotEmpty) ...[
                    _LibraryShortcuts(
                      progress: _continueReading,
                      favorites: _favorites,
                      onContinue: _continueReading == null
                          ? null
                          : () => _openContinueReading(_continueReading!),
                      onFavorite: (album) => _openAlbum(
                        AlbumSummary(
                            id: album.albumId,
                            title: album.title,
                            coverUrl: album.coverUrl),
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 10),
                  ],
                  _SearchBar(
                    controller: _searchController,
                    onSubmit: _submitSearch,
                    searchType: _searchType,
                    searchTypes: _searchTypes,
                    onSearchTypeChanged: (value) =>
                        setState(() => _searchType = value),
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  Row(
                    children: [
                      Expanded(
                        child: _ModeStrip(
                          value: _mode,
                          onChanged: (value) {
                            _mode = value;
                            _refresh(resetPage: true);
                          },
                        ),
                      ),
                      if (compact) ...[
                        const SizedBox(width: 8),
                        _ViewToggle(
                            value: _view,
                            onChanged: (value) =>
                                setState(() => _view = value)),
                      ],
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 10),
                  _FilterStrip(
                    category: _category,
                    orderBy: _orderBy,
                    timeRange: _timeRange,
                    categories: _categories,
                    orders: _orders,
                    times: _times,
                    showSort: _mode == CatalogMode.latest ||
                        _mode == CatalogMode.search,
                    onCategoryChanged: (value) {
                      _category = value;
                      _refresh(resetPage: true);
                    },
                    onOrderChanged: (value) {
                      _orderBy = value;
                      _refresh(resetPage: true);
                    },
                    onTimeChanged: (value) {
                      _timeRange = value;
                      _refresh(resetPage: true);
                    },
                  ),
                ],
              ),
            ),
          ),
          FutureBuilder<AlbumPage>(
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
                  child: _StateMessage(
                    icon: Icons.cloud_off_outlined,
                    title: '列表读取失败',
                    body: snapshot.error.toString(),
                    actionLabel: '重试',
                    onAction: () => _refresh(),
                  ),
                );
              }
              final pageData = snapshot.data!;
              if (pageData.albums.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _StateMessage(
                    icon: Icons.search_off_outlined,
                    title: '没有结果',
                    body: '换个关键词、分类或排序条件再试。',
                    actionLabel: '重新搜索',
                    onAction: _submitSearch,
                  ),
                );
              }

              final pager = _Pager(
                page: _page,
                pageCount: pageData.pageCount,
                total: pageData.total,
                onPrevious: _page > 1
                    ? () {
                        _page--;
                        _refresh();
                      }
                    : null,
                onNext: _page < pageData.pageCount
                    ? () {
                        _page++;
                        _refresh();
                      }
                    : null,
              );

              return SliverMainAxisGroup(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                        _gutter(context), 8, _gutter(context), 16),
                    sliver: _view == CatalogView.grid
                        ? SliverLayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.crossAxisExtent;
                              final columns = width >= 1300
                                  ? 8
                                  : width >= 1050
                                      ? 7
                                      : width >= 820
                                          ? 5
                                          : width >= 560
                                              ? 4
                                              : 3;
                              final aspectRatio = width < 560 ? .70 : .66;
                              return SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: aspectRatio,
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final album = pageData.albums[index];
                                    return _CompactAlbumTile(
                                        album: album,
                                        api: widget.api,
                                        onOpen: () => _openAlbum(album));
                                  },
                                  childCount: pageData.albums.length,
                                ),
                              );
                            },
                          )
                        : SliverList.separated(
                            itemCount: pageData.albums.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              final album = pageData.albums[index];
                              return _AlbumListRow(
                                  album: album,
                                  api: widget.api,
                                  onOpen: () => _openAlbum(album));
                            },
                          ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                        _gutter(context), 0, _gutter(context), 24),
                    sliver: SliverToBoxAdapter(child: pager),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  double _gutter(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 480) return 12;
    if (width < 900) return 16;
    return 22;
  }
}

class _LibraryShortcuts extends StatelessWidget {
  const _LibraryShortcuts({
    required this.progress,
    required this.favorites,
    required this.onContinue,
    required this.onFavorite,
  });

  final ReadingProgress? progress;
  final List<FavoriteAlbum> favorites;
  final VoidCallback? onContinue;
  final ValueChanged<FavoriteAlbum> onFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (progress != null)
          InkWell(
            onTap: onContinue,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: .32)),
              ),
              child: Row(
                children: [
                  Icon(Icons.play_circle_outline,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '继续阅读 JM${progress!.albumId} · ${progress!.episodeTitle.isEmpty ? progress!.photoTitle : progress!.episodeTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        if (favorites.isNotEmpty) ...[
          if (progress != null) const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final album in favorites)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.favorite_outline, size: 16),
                      label: Text('JM${album.albumId}', maxLines: 1),
                      onPressed: () => onFavorite(album),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.value, required this.onChanged});

  final CatalogView value;
  final ValueChanged<CatalogView> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleIcon(
            icon: Icons.grid_view,
            tooltip: '宫格',
            selected: value == CatalogView.grid,
            onTap: () => onChanged(CatalogView.grid),
          ),
          _ToggleIcon(
            icon: Icons.view_list,
            tooltip: '列表',
            selected: value == CatalogView.list,
            onTap: () => onChanged(CatalogView.list),
          ),
        ],
      ),
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  const _ToggleIcon(
      {required this.icon,
      required this.tooltip,
      required this.selected,
      required this.onTap});

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 38,
          height: 34,
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: .9)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon,
              size: 18, color: selected ? scheme.onPrimary : scheme.onSurface),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onSubmit,
    required this.searchType,
    required this.searchTypes,
    required this.onSearchTypeChanged,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final String searchType;
  final Map<String, String> searchTypes;
  final ValueChanged<String> onSearchTypeChanged;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 560;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: narrow ? 14 : 15),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '搜索本子、作者、标签或车号',
              hintStyle: TextStyle(fontSize: narrow ? 14 : 15),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: narrow ? 88 : 120,
          child: DropdownButtonFormField<String>(
            initialValue: searchType,
            isExpanded: true,
            style: Theme.of(context).textTheme.labelLarge,
            items: searchTypes.entries
                .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (value) {
              if (value != null) onSearchTypeChanged(value);
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: onSubmit,
          style: IconButton.styleFrom(
            fixedSize: Size.square(narrow ? 42 : 48),
            padding: EdgeInsets.zero,
          ),
          icon: const Icon(Icons.arrow_forward),
        ),
      ],
    );
  }
}

class _ModeStrip extends StatelessWidget {
  const _ModeStrip({required this.value, required this.onChanged});
  final CatalogMode value;
  final ValueChanged<CatalogMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ModePill(
              value: CatalogMode.latest,
              current: value,
              icon: Icons.category_outlined,
              label: '分类',
              onTap: onChanged),
          _ModePill(
              value: CatalogMode.search,
              current: value,
              icon: Icons.manage_search_outlined,
              label: '搜索',
              onTap: onChanged),
          _ModePill(
              value: CatalogMode.day,
              current: value,
              icon: Icons.today_outlined,
              label: '日榜',
              onTap: onChanged),
          _ModePill(
              value: CatalogMode.week,
              current: value,
              icon: Icons.calendar_view_week_outlined,
              label: '周榜',
              onTap: onChanged),
          _ModePill(
              value: CatalogMode.month,
              current: value,
              icon: Icons.calendar_month_outlined,
              label: '月榜',
              onTap: onChanged),
        ],
      ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill(
      {required this.value,
      required this.current,
      required this.icon,
      required this.label,
      required this.onTap});

  final CatalogMode value;
  final CatalogMode current;
  final IconData icon;
  final String label;
  final ValueChanged<CatalogMode> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = value == current;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: .84)
                : theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: .42),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected
                    ? Colors.transparent
                    : theme.colorScheme.outlineVariant.withValues(alpha: .6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface),
              const SizedBox(width: 6),
              Text(
                label,
                softWrap: false,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.category,
    required this.orderBy,
    required this.timeRange,
    required this.categories,
    required this.orders,
    required this.times,
    required this.showSort,
    required this.onCategoryChanged,
    required this.onOrderChanged,
    required this.onTimeChanged,
  });

  final String category;
  final String orderBy;
  final String timeRange;
  final Map<String, String> categories;
  final Map<String, String> orders;
  final Map<String, String> times;
  final bool showSort;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onOrderChanged;
  final ValueChanged<String> onTimeChanged;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;
    final drops = [
      _Drop(
          value: category,
          values: categories,
          onChanged: onCategoryChanged,
          icon: Icons.category_outlined),
      if (showSort)
        _Drop(
            value: orderBy,
            values: orders,
            onChanged: onOrderChanged,
            icon: Icons.sort_outlined),
      if (showSort)
        _Drop(
            value: timeRange,
            values: times,
            onChanged: onTimeChanged,
            icon: Icons.schedule_outlined),
    ];

    if (compact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final drop in drops)
              Padding(padding: const EdgeInsets.only(right: 6), child: drop),
          ],
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: drops);
  }
}

class _Drop extends StatelessWidget {
  const _Drop(
      {required this.value,
      required this.values,
      required this.onChanged,
      required this.icon});
  final String value;
  final Map<String, String> values;
  final ValueChanged<String> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 560;
    return SizedBox(
      width: compact ? 110 : 122,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        style: Theme.of(context).textTheme.labelLarge,
        icon: Icon(icon, size: 18),
        items: values.entries
            .map((entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)))
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _CompactAlbumTile extends StatelessWidget {
  const _CompactAlbumTile(
      {required this.album, required this.api, required this.onOpen});
  final AlbumSummary album;
  final JmApi api;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 560;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: .42),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: .5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(api.assetUrl(album.coverUrl),
                        fit: BoxFit.cover),
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .62),
                            borderRadius: BorderRadius.circular(5)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          child: Text('JM${album.id}',
                              style: theme.textTheme.labelSmall),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(compact ? 6 : 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title.isEmpty ? '未命名' : album.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: (compact
                            ? theme.textTheme.labelMedium
                            : theme.textTheme.labelLarge)
                        ?.copyWith(fontWeight: FontWeight.w800, height: 1.12),
                  ),
                  const SizedBox(height: 4),
                  _UpdateLine(album: album, compact: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumListRow extends StatelessWidget {
  const _AlbumListRow(
      {required this.album, required this.api, required this.onOpen});
  final AlbumSummary album;
  final JmApi api;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 560;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: .42),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: .5)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                api.assetUrl(album.coverUrl),
                width: compact ? 48 : 54,
                height: compact ? 68 : 76,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontSize: compact ? 14 : 15),
                  ),
                  const SizedBox(height: 6),
                  Text('JM${album.id}',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.secondary)),
                  const SizedBox(height: 4),
                  _UpdateLine(album: album, compact: compact),
                  const SizedBox(height: 4),
                  Text(album.tags.take(4).join(' / '),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
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

class _UpdateLine extends StatelessWidget {
  const _UpdateLine({required this.album, required this.compact});

  final AlbumSummary album;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = album.updateDate.isEmpty ? '更新待同步' : album.updateDate;
    final weekday =
        album.updateWeekday.isEmpty ? '更新日未知' : '${album.updateWeekday}更新';
    return Row(
      children: [
        Icon(Icons.update_outlined,
            size: compact ? 13 : 14, color: theme.colorScheme.tertiary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '$date · $weekday',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      ],
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager(
      {required this.page,
      required this.pageCount,
      required this.total,
      required this.onPrevious,
      required this.onNext});
  final int page;
  final int pageCount;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$page / $pageCount', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('共 $total 个结果', style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                  onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
              const SizedBox(width: 8),
              IconButton.filled(
                  onPressed: onNext, icon: const Icon(Icons.chevron_right)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage(
      {required this.icon,
      required this.title,
      required this.body,
      required this.actionLabel,
      required this.onAction});
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

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
              textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 18),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
