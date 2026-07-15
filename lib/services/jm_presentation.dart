import '../models/download_job.dart';

String downloadEnqueueMessage(DownloadJob job) {
  final isPhoto = job.kind == 'photo';
  final title = isPhoto
      ? (job.episodeTitle.isEmpty ? 'JM${job.jmId}' : job.episodeTitle)
      : (job.albumTitle.isEmpty ? 'JM${job.jmId}' : job.albumTitle);
  if (!job.deduped) {
    return '${isPhoto ? '章节' : ''}已加入服务器下载队列：$title';
  }
  return switch (job.dedupeReason) {
    'already_active' => '已在下载：$title',
    'already_downloaded' => '已下载：$title',
    _ => '下载任务已存在：$title',
  };
}

String jmTaskRunStatusLabel(String value) => switch (value) {
      'succeeded' => '成功',
      'partial' => '部分成功',
      'failed' => '失败',
      _ => value,
    };
