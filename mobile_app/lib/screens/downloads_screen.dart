import 'dart:async';

import 'package:flutter/material.dart';

import '../models/download_job.dart';
import '../services/jm_api.dart';

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
      if (_jobs
          .any((job) => job.status == 'queued' || job.status == 'running')) {
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
                  albumId: group.albumId,
                  title: group.title,
                  jobs: group.jobs,
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
    required this.albumId,
    required this.title,
    required this.jobs,
  });

  final String albumId;
  final String title;
  final List<DownloadJob> jobs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active =
        jobs.any((job) => job.status == 'queued' || job.status == 'running');
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .32),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .5)),
      ),
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
              child: _DownloadJobCard(job: job),
            ),
        ],
      ),
    );
  }
}

class _DownloadJobCard extends StatelessWidget {
  const _DownloadJobCard({required this.job});

  final DownloadJob job;

  Color _statusColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (job.status) {
      'done' => scheme.secondary,
      'failed' => scheme.error,
      'running' => scheme.tertiary,
      _ => scheme.outline,
    };
  }

  IconData _statusIcon() {
    return switch (job.status) {
      'done' => Icons.check_circle_outline,
      'failed' => Icons.error_outline,
      'running' => Icons.downloading_outlined,
      _ => Icons.hourglass_empty_outlined,
    };
  }

  String _statusText() {
    return switch (job.status) {
      'done' => '完成',
      'failed' => '失败',
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
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .44),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .55)),
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
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: job.status == 'running' ||
                      job.status == 'done' ||
                      progress > 0
                  ? progress
                  : null,
              minHeight: 7,
              backgroundColor: Colors.black.withValues(alpha: .24),
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
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w800, fontSize: 12)),
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
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: .48),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: .4)),
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
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .45)),
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
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(6),
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
