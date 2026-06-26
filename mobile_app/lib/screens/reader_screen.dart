import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/album.dart';
import '../models/photo.dart';
import '../services/jm_api.dart';
import '../services/library_store.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.api,
    required this.photoId,
    required this.title,
    this.albumId = '',
    this.albumTitle = '',
    this.coverUrl = '',
    this.episodes = const [],
  }) : loader = _loadOnlinePhoto;

  const ReaderScreen.downloadPreview({
    super.key,
    required this.api,
    required String jobId,
    required this.title,
  })  : photoId = jobId,
        albumId = '',
        albumTitle = '',
        coverUrl = '',
        episodes = const [],
        loader = _loadDownloadedPreview;

  final JmApi api;
  final String photoId;
  final String title;
  final String albumId;
  final String albumTitle;
  final String coverUrl;
  final List<Episode> episodes;
  final Future<PhotoDetail> Function(JmApi api, String id) loader;

  static Future<PhotoDetail> _loadOnlinePhoto(JmApi api, String id) =>
      api.photo(id);
  static Future<PhotoDetail> _loadDownloadedPreview(JmApi api, String id) =>
      api.downloadPreview(id);

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late Future<PhotoDetail> _future;
  late String _photoId;
  late String _title;
  bool _fitWidth = true;
  bool _controlsVisible = false;

  @override
  void initState() {
    super.initState();
    _photoId = widget.photoId;
    _title = widget.title;
    _future = widget.loader(widget.api, _photoId);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _saveProgress();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _reload() {
    setState(() => _future = widget.loader(widget.api, _photoId));
  }

  int get _episodeIndex =>
      widget.episodes.indexWhere((item) => item.id == _photoId);

  Episode? get _currentEpisode {
    final index = _episodeIndex;
    if (index < 0) return null;
    return widget.episodes[index];
  }

  void _saveProgress() {
    final episode = _currentEpisode;
    if (widget.albumId.isEmpty || episode == null) return;
    LibraryStore.instance.saveContinueReading(
      ReadingProgress(
        albumId: widget.albumId,
        albumTitle: widget.albumTitle,
        coverUrl: widget.coverUrl,
        photoId: episode.id,
        photoTitle: episode.title,
        episodeIndex: episode.index,
        episodeTitle: episode.title,
        updatedAt: DateTime.now(),
      ),
    );
  }

  void _openEpisode(Episode episode) {
    setState(() {
      _photoId = episode.id;
      _title = episode.title;
      _future = widget.loader(widget.api, episode.id);
    });
    _setControlsVisible(false);
    _saveProgress();
  }

  void _openNext() {
    final index = _episodeIndex;
    if (index < 0 || index >= widget.episodes.length - 1) return;
    _openEpisode(widget.episodes[index + 1]);
  }

  void _openPrevious() {
    final index = _episodeIndex;
    if (index <= 0) return;
    _openEpisode(widget.episodes[index - 1]);
  }

  void _openCatalog() {
    if (widget.episodes.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: widget.episodes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final episode = widget.episodes[index];
              final selected = episode.id == _photoId;
              return ListTile(
                selected: selected,
                leading: Text('${episode.index}'),
                title: Text(episode.title.isEmpty
                    ? '章节 ${episode.index}'
                    : episode.title),
                trailing: selected ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.of(context).pop();
                  _openEpisode(episode);
                },
              );
            },
          ),
        );
      },
    );
  }

  String get _displayTitle {
    final episode = _currentEpisode;
    final title = _title.isEmpty ? 'Photo $_photoId' : _title;
    if (episode == null) return title;
    return '第 ${episode.index} 话-$title';
  }

  void _toggleControls() {
    _setControlsVisible(!_controlsVisible);
  }

  void _setControlsVisible(bool visible) {
    setState(() => _controlsVisible = visible);
    SystemChrome.setEnabledSystemUIMode(
        visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF070D10),
      body: FutureBuilder<PhotoDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(snapshot.error.toString(),
                    textAlign: TextAlign.center),
              ),
            );
          }

          final photo = snapshot.data!;
          return Stack(
            children: [
              ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: photo.images.length,
                itemBuilder: (context, index) {
                  final image = photo.images[index];
                  return GestureDetector(
                    onTap: _toggleControls,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Center(
                        child: InteractiveViewer(
                          minScale: .7,
                          maxScale: 4,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                maxWidth: _fitWidth ? 980 : double.infinity),
                            child: ColoredBox(
                              color: scheme.surface,
                              child: Image.network(
                                widget.api.assetUrl(image.url),
                                width: double.infinity,
                                fit: _fitWidth
                                    ? BoxFit.fitWidth
                                    : BoxFit.contain,
                                loadingBuilder: (context, child, loading) {
                                  if (loading == null) return child;
                                  return AspectRatio(
                                    aspectRatio: .72,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loading.expectedTotalBytes ==
                                                null
                                            ? null
                                            : loading.cumulativeBytesLoaded /
                                                loading.expectedTotalBytes!,
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => AspectRatio(
                                  aspectRatio: .72,
                                  child: Center(
                                      child: Text('图片 ${image.index} 读取失败')),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_controlsVisible)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _ReaderTopBar(
                    title: _displayTitle,
                    fitWidth: _fitWidth,
                    onBack: () => Navigator.of(context).maybePop(),
                    onToggleFit: () => setState(() => _fitWidth = !_fitWidth),
                    onReload: _reload,
                  ),
                ),
              if (_controlsVisible)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 18 + MediaQuery.paddingOf(context).bottom,
                  child: _ReaderControls(
                    canPrevious: _episodeIndex > 0,
                    canNext: _episodeIndex >= 0 &&
                        _episodeIndex < widget.episodes.length - 1,
                    canCatalog: widget.episodes.isNotEmpty,
                    onPrevious: _openPrevious,
                    onCatalog: _openCatalog,
                    onNext: _openNext,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReaderTopBar extends StatelessWidget {
  const _ReaderTopBar({
    required this.title,
    required this.fitWidth,
    required this.onBack,
    required this.onToggleFit,
    required this.onReload,
  });

  final String title;
  final bool fitWidth;
  final VoidCallback onBack;
  final VoidCallback onToggleFit;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .78),
        border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: .10))),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, padding.top + 4, 8, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: '返回',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: fitWidth ? '原始宽度' : '适应宽度',
              onPressed: onToggleFit,
              icon: Icon(fitWidth
                  ? Icons.fit_screen_outlined
                  : Icons.open_in_full_outlined),
            ),
            IconButton(
              tooltip: '刷新',
              onPressed: onReload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderControls extends StatelessWidget {
  const _ReaderControls({
    required this.canPrevious,
    required this.canNext,
    required this.canCatalog,
    required this.onPrevious,
    required this.onCatalog,
    required this.onNext,
  });

  final bool canPrevious;
  final bool canNext;
  final bool canCatalog;
  final VoidCallback onPrevious;
  final VoidCallback onCatalog;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .74),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: canPrevious ? onPrevious : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('上一章'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: canCatalog ? onCatalog : null,
                icon: const Icon(Icons.list_alt_outlined),
                label: const Text('目录'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: canNext ? onNext : null,
                icon: const Icon(Icons.chevron_right),
                label: const Text('下一章'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
