import 'dart:async';

import 'package:flutter/material.dart';

import '../models/album.dart';
import '../models/download_job.dart';
import '../services/jm_api.dart';
import '../theme/animal_theme.dart';
import 'reader_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key, required this.api});

  final JmApi api;

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  Timer? _timer;
  List<DownloadJob> _jobs = const [];
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String _rootPath = '';

  @override
  void initState() {
    super.initState();
    _loadDownloads(showLoading: true);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_jobs.any(_isActiveJob)) {
        _loadDownloads();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadDownloads({bool showLoading = false}) async {
    if (_refreshing) return;
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    setState(() => _refreshing = true);
    try {
      final jobs = await widget.api.downloads();
      final health = await widget.api.health();
      final rootPath = health['downloadDir']?.toString() ?? '';
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _rootPath = rootPath;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _refresh() {
    _loadDownloads();
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
    final groups = _groupJobs(_jobs);
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('下载队列', style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        _rootPath.isEmpty
                            ? '服务器下载任务会保存在后端配置的下载目录。'
                            : '服务器下载目录：$_rootPath',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.outline),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _refreshing ? null : _refresh,
                  icon: _refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ),
        if (_loading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(_error!, textAlign: TextAlign.center)),
          )
        else if (_jobs.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyDownloads(onRefresh: _refresh),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 24),
            sliver: SliverList.separated(
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final group = groups[index];
                return _DownloadGroupCard(
                  api: widget.api,
                  albumId: group.albumId,
                  title: group.title,
                  jobs: group.jobs,
                  onChanged: _refresh,
                );
              },
            ),
          ),
      ],
    );
  }

  List<_DownloadGroup> _groupJobs(List<DownloadJob> jobs) {
    final groups = <String, List<DownloadJob>>{};
    for (final job in jobs) {
      final key = job.albumId.isNotEmpty ? job.albumId : job.jmId;
      groups.putIfAbsent(key, () => []).add(job);
    }
    return groups.entries.map((entry) {
      final title = entry.value
          .map((job) => job.albumTitle)
          .firstWhere((title) => title.isNotEmpty, orElse: () => '');
      return _DownloadGroup(
        albumId: entry.key,
        title: title,
        jobs: entry.value,
      );
    }).toList();
  }
}

bool _isActiveJob(DownloadJob job) {
  return job.status == 'queued' ||
      job.status == 'running' ||
      job.status == 'cancelling' ||
      job.pdfMerge.active;
}

class _DownloadGroup {
  const _DownloadGroup({
    required this.albumId,
    required this.title,
    required this.jobs,
  });

  final String albumId;
  final String title;
  final List<DownloadJob> jobs;
}

class _DownloadGroupCard extends StatelessWidget {
  const _DownloadGroupCard({
    required this.api,
    required this.albumId,
    required this.title,
    required this.jobs,
    required this.onChanged,
  });

  final JmApi api;
  final String albumId;
  final String title;
  final List<DownloadJob> jobs;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = jobs.any(_isActiveJob);
    return Container(
      decoration: AnimalTheme.cardDecoration(context),
      child: ExpansionTile(
        initiallyExpanded: active || jobs.length == 1,
        leading: Icon(
            active ? Icons.downloading_outlined : Icons.library_books_outlined),
        title: Text(
          title.isEmpty ? 'JM$albumId' : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text('${jobs.length} 个任务'),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        children: [
          for (final job in jobs)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _DownloadJobCard(api: api, job: job, onChanged: onChanged),
            ),
        ],
      ),
    );
  }
}

class _DownloadJobCard extends StatefulWidget {
  const _DownloadJobCard({
    required this.api,
    required this.job,
    required this.onChanged,
  });

  final JmApi api;
  final DownloadJob job;
  final VoidCallback onChanged;

  @override
  State<_DownloadJobCard> createState() => _DownloadJobCardState();
}

class _DownloadJobCardState extends State<_DownloadJobCard> {
  bool _busy = false;

  DownloadJob get job => widget.job;

  Color _statusColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (job.status) {
      'done' => scheme.secondary,
      'failed' => scheme.error,
      'cancelled' => scheme.outline,
      'cancelling' => scheme.outline,
      'running' => scheme.tertiary,
      _ => scheme.outline,
    };
  }

  IconData _statusIcon() {
    return switch (job.status) {
      'done' => Icons.check_circle_outline,
      'failed' => Icons.error_outline,
      'cancelled' => Icons.cancel_outlined,
      'cancelling' => Icons.cancel_schedule_send_outlined,
      'running' => Icons.downloading_outlined,
      _ => Icons.hourglass_empty_outlined,
    };
  }

  String _statusText() {
    return switch (job.status) {
      'done' => '完成',
      'failed' => '失败',
      'cancelled' => '已取消',
      'cancelling' => '取消中',
      'running' => '下载中',
      'queued' => '排队中',
      _ => job.status,
    };
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

  String _speed() {
    if (job.status == 'queued') return '等待开始';
    if (job.speedBps <= 0) return '测速中';
    return '${_formatBytes(job.speedBps)}/s';
  }

  String _outputPath() {
    if (job.outputPaths.isEmpty) return '保存目录待创建';
    return job.outputPaths.first;
  }

  Color _pdfStatusColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (job.pdfMerge.status) {
      'done' => scheme.secondary,
      'failed' => scheme.error,
      'running' => scheme.tertiary,
      'queued' => scheme.outline,
      _ => scheme.outline,
    };
  }

  String _pdfStatusText() {
    return switch (job.pdfMerge.status) {
      'done' => 'PDF 已完成',
      'failed' => 'PDF 失败',
      'running' => 'PDF 合并中',
      'queued' => 'PDF 排队中',
      _ => '未合并 PDF',
    };
  }

  bool get _canCancel =>
      job.status == 'queued' ||
      job.status == 'running' ||
      job.status == 'cancelling';

  bool get _canMergePdf => job.status == 'done' && !job.pdfMerge.active;

  Future<void> _cancelDownload() async {
    if (_busy || !_canCancel) return;
    setState(() => _busy = true);
    try {
      await widget.api.cancelDownload(job.id);
      widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('取消失败：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mergePdf() async {
    if (_busy || !_canMergePdf) return;
    setState(() => _busy = true);
    try {
      await widget.api.mergeDownloadPdf(job.id);
      widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('启动 PDF 合并失败：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openPreview(BuildContext context, String title) {
    final episodes = _previewEpisodes();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen.downloadPreview(
          api: widget.api,
          jobId: job.id,
          initialPhotoId: episodes.isEmpty ? null : episodes.first.id,
          title: title,
          episodes: episodes,
        ),
      ),
    );
  }

  List<Episode> _previewEpisodes() {
    final chapters = job.chapters
        .where((chapter) =>
            chapter.completedImages > 0 || chapter.status == 'done')
        .toList()
      ..sort((left, right) {
        final byIndex = left.index.compareTo(right.index);
        if (byIndex != 0) return byIndex;
        return left.id.compareTo(right.id);
      });
    return chapters
        .map(
          (chapter) => Episode(
            id: chapter.id,
            index: chapter.index == 0 ? 1 : chapter.index,
            title: chapter.title.isEmpty
                ? (job.episodeTitle.isEmpty
                    ? (job.albumTitle.isEmpty
                        ? 'JM${chapter.id}'
                        : job.albumTitle)
                    : job.episodeTitle)
                : chapter.title,
            fileSize: chapter.fileSize,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor(context);
    final progress =
        job.status == 'done' ? 1.0 : job.progress.clamp(0, 1).toDouble();
    final countText = job.totalImages > 0
        ? '${job.completedImages}/${job.totalImages} 张'
        : '${job.completedImages} 张';
    final title = job.kind == 'album'
        ? (job.albumTitle.isEmpty ? '本子 JM${job.jmId}' : job.albumTitle)
        : (job.episodeTitle.isEmpty ? '章节 JM${job.jmId}' : job.episodeTitle);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AnimalTheme.cardDecoration(
        context,
        color: AnimalTheme.softPaper(context),
        radius: AnimalTheme.radiusMd,
        elevated: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_statusIcon(), color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall),
              ),
              _StatusPill(text: _statusText(), color: color),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AnimalTheme.radiusPill),
            child: LinearProgressIndicator(
              value: job.status == 'running' ||
                      job.status == 'done' ||
                      progress > 0
                  ? progress
                  : null,
              minHeight: 7,
              backgroundColor:
                  theme.colorScheme.outlineVariant.withValues(alpha: .35),
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _JobMetric(icon: Icons.image_outlined, label: countText),
              _JobMetric(icon: Icons.speed_outlined, label: _speed()),
              _JobMetric(
                  icon: Icons.storage_outlined,
                  label: _formatBytes(job.downloadedBytes)),
            ],
          ),
          if (job.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(job.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall),
          ],
          if (job.chapters.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ChapterStatusList(chapters: job.chapters),
          ],
          const SizedBox(height: 10),
          _PathLine(path: _outputPath()),
          if (job.pdfMerge.status != 'idle') ...[
            const SizedBox(height: 10),
            _PdfMergeProgress(
              state: job.pdfMerge,
              color: _pdfStatusColor(context),
              label: _pdfStatusText(),
            ),
          ],
          if (job.previewImageCount > 0 || _canCancel || job.status == 'done') ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (job.previewImageCount > 0)
                  FilledButton.tonalIcon(
                    onPressed: () => _openPreview(context, title),
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text('预览 ${job.previewImageCount} 张'),
                  ),
                if (job.status == 'done')
                  OutlinedButton.icon(
                    onPressed: _busy || !_canMergePdf ? null : _mergePdf,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(job.pdfMerge.status == 'done'
                        ? '重新合并 PDF'
                        : '合并 PDF'),
                  ),
                if (_canCancel)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _cancelDownload,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined),
                    label: const Text('取消'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            progress > 0
                ? '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}% · 保存在服务器'
                : '等待进度',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: AnimalTheme.pillDecoration(
        context,
        color: color.withValues(alpha: .14),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class _PdfMergeProgress extends StatelessWidget {
  const _PdfMergeProgress({
    required this.state,
    required this.color,
    required this.label,
  });

  final PdfMergeState state;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = state.completedChapters + state.failedChapters;
    final total = state.totalChapters;
    final progress = total == 0 ? state.progress : (done / total);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: AnimalTheme.cardDecoration(
        context,
        color: AnimalTheme.paper(context).withValues(alpha: .72),
        radius: AnimalTheme.radiusMd,
        elevated: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.picture_as_pdf_outlined, size: 16, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$label · $done/$total 章',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium,
                ),
              ),
              if (state.failedChapters > 0)
                _StatusPill(text: '失败 ${state.failedChapters}', color: color),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AnimalTheme.radiusPill),
            child: LinearProgressIndicator(
              value: state.active || progress > 0
                  ? progress.clamp(0, 1).toDouble()
                  : null,
              minHeight: 6,
              backgroundColor:
                  theme.colorScheme.outlineVariant.withValues(alpha: .35),
              color: color,
            ),
          ),
          if (state.message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              state.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChapterStatusList extends StatelessWidget {
  const _ChapterStatusList({required this.chapters});

  final List<DownloadChapter> chapters;

  Color _color(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      'done' => scheme.secondary,
      'failed' => scheme.error,
      'running' => scheme.tertiary,
      _ => scheme.outline,
    };
  }

  String _text(String status) {
    return switch (status) {
      'done' => '已下载',
      'failed' => '失败',
      'running' => '下载中',
      'queued' => '排队中',
      _ => status,
    };
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final chapter in chapters)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            decoration: AnimalTheme.cardDecoration(
              context,
              color: AnimalTheme.paper(context).withValues(alpha: .82),
              radius: AnimalTheme.radiusMd,
              elevated: false,
              borderColor:
                  theme.colorScheme.outlineVariant.withValues(alpha: .64),
            ),
            child: Row(
              children: [
                Icon(Icons.article_outlined,
                    size: 16, color: _color(context, chapter.status)),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.title.isEmpty
                            ? '章节 ${chapter.index == 0 ? chapter.id : chapter.index}'
                            : chapter.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chapter.totalImages > 0
                            ? '${chapter.completedImages}/${chapter.totalImages} 张 · ${_formatBytes(chapter.downloadedBytes)}'
                            : '${chapter.completedImages} 张 · ${_formatBytes(chapter.downloadedBytes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(
                    text: _text(chapter.status),
                    color: _color(context, chapter.status)),
              ],
            ),
          ),
      ],
    );
  }
}

class _JobMetric extends StatelessWidget {
  const _JobMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: AnimalTheme.pillDecoration(
        context,
        color: AnimalTheme.softPaper(context),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.secondary),
          const SizedBox(width: 5),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _PathLine extends StatelessWidget {
  const _PathLine({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: AnimalTheme.cardDecoration(
        context,
        color: AnimalTheme.paper(context).withValues(alpha: .72),
        radius: AnimalTheme.radiusMd,
        elevated: false,
      ),
      child: Row(
        children: [
          Icon(Icons.folder_outlined,
              size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 7),
          Expanded(
            child: SelectableText(
              path,
              maxLines: 1,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_for_offline_outlined,
              size: 44, color: theme.colorScheme.primary),
          const SizedBox(height: 14),
          Text('还没有下载任务', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('在详情页点击服务器下载后，图片会保存到后端下载目录，本页会显示服务器路径。',
              textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新')),
        ],
      ),
    );
  }
}
