import 'dart:async';

import 'package:flutter/material.dart';

import '../models/download_job.dart';
import '../services/jm_api.dart';
import 'reader_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key, required this.api});

  final JmApi api;

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  late Future<List<DownloadJob>> _future;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _future = widget.api.downloads();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _future = widget.api.downloads());
  }

  void _openPreview(DownloadJob job) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen.downloadPreview(
          api: widget.api,
          jobId: job.id,
          title: '${job.kind == 'album' ? '本子' : '章节'} JM${job.jmId} 预览',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final gutter = width < 480 ? 12.0 : width < 900 ? 16.0 : 22.0;
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
                        '进度、网速和保存路径会随本地服务自动更新。',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(onPressed: _refresh, icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
        ),
        FutureBuilder<List<DownloadJob>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text(snapshot.error.toString(), textAlign: TextAlign.center)),
              );
            }
            final jobs = snapshot.data!;
            if (jobs.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyDownloads(onRefresh: _refresh),
              );
            }
            return SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 24),
              sliver: SliverList.separated(
                itemCount: jobs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  return _DownloadJobCard(job: job, onPreview: job.previewImageCount > 0 ? () => _openPreview(job) : null);
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DownloadJobCard extends StatelessWidget {
  const _DownloadJobCard({required this.job, required this.onPreview});

  final DownloadJob job;
  final VoidCallback? onPreview;

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
    final progress = job.status == 'done' ? 1.0 : job.progress.clamp(0, 1).toDouble();
    final countText = job.totalImages > 0 ? '${job.completedImages}/${job.totalImages} 张' : '${job.completedImages} 张';
    final title = '${job.kind == 'album' ? '本子' : '章节'} JM${job.jmId}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .44),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_statusIcon(), color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
              ),
              _StatusPill(text: _statusText(), color: color),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: job.status == 'running' || job.status == 'done' || progress > 0 ? progress : null,
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
              _JobMetric(icon: Icons.storage_outlined, label: _formatBytes(job.downloadedBytes)),
              if (job.previewImageCount > 0) _JobMetric(icon: Icons.visibility_outlined, label: '${job.previewImageCount} 张可预览'),
            ],
          ),
          if (job.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(job.message, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 10),
          _PathLine(path: _outputPath()),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  progress > 0 ? '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%' : '等待进度',
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onPreview,
                icon: const Icon(Icons.chrome_reader_mode_outlined, size: 18),
                label: const Text('网页预览'),
              ),
            ],
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
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
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
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .45)),
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
          Icon(Icons.folder_outlined, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 7),
          Expanded(
            child: SelectableText(
              path,
              maxLines: 1,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
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
          Icon(Icons.download_for_offline_outlined, size: 44, color: theme.colorScheme.primary),
          const SizedBox(height: 14),
          Text('还没有下载任务', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('在详情页点击下载整本或下载章节后，这里会显示实时进度和保存目录。', textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('刷新')),
        ],
      ),
    );
  }
}
