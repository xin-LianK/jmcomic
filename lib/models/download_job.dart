class DownloadChapter {
  const DownloadChapter({
    required this.id,
    required this.index,
    required this.title,
    required this.status,
    this.message = '',
    required this.totalImages,
    required this.completedImages,
    this.failedImages = 0,
    required this.downloadedBytes,
    required this.outputPath,
    required this.fileSize,
  });

  final String id;
  final int index;
  final String title;
  final String status;
  final String message;
  final int totalImages;
  final int completedImages;
  final int failedImages;
  final int downloadedBytes;
  final String outputPath;
  final int fileSize;

  factory DownloadChapter.fromJson(Map<String, dynamic> json) {
    return DownloadChapter(
      id: json['id']?.toString() ?? '',
      index: (json['index'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      totalImages: (json['totalImages'] as num?)?.toInt() ?? 0,
      completedImages: (json['completedImages'] as num?)?.toInt() ?? 0,
      failedImages: (json['failedImages'] as num?)?.toInt() ?? 0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      outputPath: json['outputPath']?.toString() ?? '',
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'index': index,
        'title': title,
        'status': status,
        'message': message,
        'totalImages': totalImages,
        'completedImages': completedImages,
        'failedImages': failedImages,
        'downloadedBytes': downloadedBytes,
        'outputPath': outputPath,
        'fileSize': fileSize,
      };
}

class DownloadJob {
  const DownloadJob({
    required this.id,
    required this.kind,
    required this.jmId,
    required this.albumId,
    required this.albumTitle,
    required this.episodeTitle,
    required this.episodeIndex,
    required this.status,
    required this.message,
    required this.cancelRequested,
    required this.progress,
    required this.totalImages,
    required this.completedImages,
    this.failedImages = 0,
    required this.downloadedBytes,
    required this.speedBps,
    required this.outputPaths,
    required this.previewImageCount,
    required this.previewUrl,
    required this.chapters,
    required this.pdfMerge,
    this.deduped = false,
    this.dedupeReason = '',
    this.priority = 0,
    this.createdAt,
    this.updatedAt,
    this.startedAt,
    this.finishedAt,
  });

  final String id;
  final String kind;
  final String jmId;
  final String albumId;
  final String albumTitle;
  final String episodeTitle;
  final int episodeIndex;
  final String status;
  final String message;
  final bool cancelRequested;
  final double progress;
  final int totalImages;
  final int completedImages;
  final int failedImages;
  final int downloadedBytes;
  final double speedBps;
  final List<String> outputPaths;
  final int previewImageCount;
  final String previewUrl;
  final List<DownloadChapter> chapters;
  final PdfMergeState pdfMerge;
  final bool deduped;
  final String dedupeReason;
  final int priority;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  double get normalizedProgress => totalImages == 0
      ? progress
      : (completedImages / totalImages).clamp(0, 1).toDouble();

  factory DownloadJob.fromJson(Map<String, dynamic> json) {
    return DownloadJob(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      jmId: json['jmId']?.toString() ?? '',
      albumId: json['albumId']?.toString() ?? json['jmId']?.toString() ?? '',
      albumTitle: json['albumTitle']?.toString() ?? '',
      episodeTitle: json['episodeTitle']?.toString() ?? '',
      episodeIndex: (json['episodeIndex'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      cancelRequested: json['cancelRequested'] == true,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      totalImages: (json['totalImages'] as num?)?.toInt() ?? 0,
      completedImages: (json['completedImages'] as num?)?.toInt() ?? 0,
      failedImages: (json['failedImages'] as num?)?.toInt() ?? 0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      speedBps: (json['speedBps'] as num?)?.toDouble() ?? 0,
      outputPaths: (json['outputPaths'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      previewImageCount: (json['previewImageCount'] as num?)?.toInt() ?? 0,
      previewUrl: json['previewUrl']?.toString() ?? '',
      chapters: (json['chapters'] as List? ?? const [])
          .map((item) =>
              DownloadChapter.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      pdfMerge: json['pdfMerge'] is Map
          ? PdfMergeState.fromJson(
              Map<String, dynamic>.from(json['pdfMerge'] as Map))
          : PdfMergeState.idle,
      deduped: json['deduped'] == true,
      dedupeReason: json['dedupeReason']?.toString() ?? '',
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      createdAt: _dateTimeFromJson(json['createdAt'] ?? json['created_at']),
      updatedAt: _dateTimeFromJson(json['updatedAt'] ?? json['updated_at']),
      startedAt: _dateTimeFromJson(json['startedAt'] ?? json['started_at']),
      finishedAt: _dateTimeFromJson(json['finishedAt'] ?? json['finished_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'jmId': jmId,
        'albumId': albumId,
        'albumTitle': albumTitle,
        'episodeTitle': episodeTitle,
        'episodeIndex': episodeIndex,
        'status': status,
        'message': message,
        'cancelRequested': cancelRequested,
        'progress': progress,
        'totalImages': totalImages,
        'completedImages': completedImages,
        'failedImages': failedImages,
        'downloadedBytes': downloadedBytes,
        'speedBps': speedBps,
        'outputPaths': outputPaths,
        'previewImageCount': previewImageCount,
        'previewUrl': previewUrl,
        'chapters': chapters.map((item) => item.toJson()).toList(),
        'pdfMerge': pdfMerge.toJson(),
        'deduped': deduped,
        'dedupeReason': dedupeReason,
        'priority': priority,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
      };

  DownloadJob copyWith({
    String? id,
    String? kind,
    String? jmId,
    String? albumId,
    String? albumTitle,
    String? episodeTitle,
    int? episodeIndex,
    String? status,
    String? message,
    bool? cancelRequested,
    double? progress,
    int? totalImages,
    int? completedImages,
    int? failedImages,
    int? downloadedBytes,
    double? speedBps,
    List<String>? outputPaths,
    int? previewImageCount,
    String? previewUrl,
    List<DownloadChapter>? chapters,
    PdfMergeState? pdfMerge,
    bool? deduped,
    String? dedupeReason,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return DownloadJob(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      jmId: jmId ?? this.jmId,
      albumId: albumId ?? this.albumId,
      albumTitle: albumTitle ?? this.albumTitle,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      episodeIndex: episodeIndex ?? this.episodeIndex,
      status: status ?? this.status,
      message: message ?? this.message,
      cancelRequested: cancelRequested ?? this.cancelRequested,
      progress: progress ?? this.progress,
      totalImages: totalImages ?? this.totalImages,
      completedImages: completedImages ?? this.completedImages,
      failedImages: failedImages ?? this.failedImages,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      speedBps: speedBps ?? this.speedBps,
      outputPaths: outputPaths ?? this.outputPaths,
      previewImageCount: previewImageCount ?? this.previewImageCount,
      previewUrl: previewUrl ?? this.previewUrl,
      chapters: chapters ?? this.chapters,
      pdfMerge: pdfMerge ?? this.pdfMerge,
      deduped: deduped ?? this.deduped,
      dedupeReason: dedupeReason ?? this.dedupeReason,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value == null) return null;
  if (value is num) {
    if (value <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch((value * 1000).round());
  }
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

class PdfMergeState {
  static const idle = PdfMergeState(
    status: 'idle',
    message: '',
    progress: 0,
    totalChapters: 0,
    completedChapters: 0,
    failedChapters: 0,
    outputPaths: [],
    startedAt: null,
    finishedAt: null,
    workers: 3,
  );

  const PdfMergeState({
    required this.status,
    required this.message,
    required this.progress,
    required this.totalChapters,
    required this.completedChapters,
    required this.failedChapters,
    required this.outputPaths,
    required this.startedAt,
    required this.finishedAt,
    required this.workers,
  });

  final String status;
  final String message;
  final double progress;
  final int totalChapters;
  final int completedChapters;
  final int failedChapters;
  final List<String> outputPaths;
  final double? startedAt;
  final double? finishedAt;
  final int workers;

  bool get active => status == 'queued' || status == 'running';

  factory PdfMergeState.fromJson(Map<String, dynamic> json) {
    return PdfMergeState(
      status: json['status']?.toString() ?? 'idle',
      message: json['message']?.toString() ?? '',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      totalChapters: (json['totalChapters'] as num?)?.toInt() ?? 0,
      completedChapters: (json['completedChapters'] as num?)?.toInt() ?? 0,
      failedChapters: (json['failedChapters'] as num?)?.toInt() ?? 0,
      outputPaths: (json['outputPaths'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      startedAt: (json['startedAt'] as num?)?.toDouble(),
      finishedAt: (json['finishedAt'] as num?)?.toDouble(),
      workers: (json['workers'] as num?)?.toInt() ?? 3,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'message': message,
        'progress': progress,
        'totalChapters': totalChapters,
        'completedChapters': completedChapters,
        'failedChapters': failedChapters,
        'outputPaths': outputPaths,
        'startedAt': startedAt,
        'finishedAt': finishedAt,
        'workers': workers,
      };
}

class DownloadQueueStatus {
  static const idle = DownloadQueueStatus(
    paused: false,
    running: 0,
    queued: 0,
    active: 0,
    maxWorkers: 1,
    nextJobId: '',
  );

  const DownloadQueueStatus({
    required this.paused,
    required this.running,
    required this.queued,
    required this.active,
    required this.maxWorkers,
    required this.nextJobId,
  });

  final bool paused;
  final int running;
  final int queued;
  final int active;
  final int maxWorkers;
  final String nextJobId;

  bool get hasWork => active > 0 || running > 0 || queued > 0;

  factory DownloadQueueStatus.fromJson(Map<String, dynamic> json) {
    return DownloadQueueStatus(
      paused: json['paused'] == true,
      running: (json['running'] as num?)?.toInt() ?? 0,
      queued: (json['queued'] as num?)?.toInt() ?? 0,
      active: (json['active'] as num?)?.toInt() ?? 0,
      maxWorkers: (json['maxWorkers'] as num?)?.toInt() ?? 1,
      nextJobId: json['nextJobId']?.toString() ?? '',
    );
  }

  factory DownloadQueueStatus.fromJobs(List<DownloadJob> jobs) {
    final running = jobs.where((job) => job.status == 'running').length;
    final queuedJobs = jobs.where((job) => job.status == 'queued').toList();
    return DownloadQueueStatus(
      paused: false,
      running: running,
      queued: queuedJobs.length,
      active: running + queuedJobs.length,
      maxWorkers: 1,
      nextJobId: queuedJobs.isEmpty ? '' : queuedJobs.first.id,
    );
  }

  Map<String, dynamic> toJson() => {
        'paused': paused,
        'running': running,
        'queued': queued,
        'active': active,
        'maxWorkers': maxWorkers,
        'nextJobId': nextJobId,
      };
}

class DownloadsResponse {
  const DownloadsResponse({
    required this.jobs,
    required this.queue,
  });

  final List<DownloadJob> jobs;
  final DownloadQueueStatus queue;

  factory DownloadsResponse.fromJson(Map<String, dynamic> json) {
    final jobs = (json['jobs'] as List? ?? const [])
        .map((item) =>
            DownloadJob.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return DownloadsResponse(
      jobs: jobs,
      queue: json['queue'] is Map
          ? DownloadQueueStatus.fromJson(
              Map<String, dynamic>.from(json['queue'] as Map))
          : DownloadQueueStatus.fromJobs(jobs),
    );
  }
}

class DownloadBatchItem {
  const DownloadBatchItem({
    required this.jobId,
    required this.status,
    this.chapterId = '',
    this.error = '',
  });

  final String jobId;
  final String chapterId;
  final String status;
  final String error;

  factory DownloadBatchItem.fromJson(Map<String, dynamic> json) {
    return DownloadBatchItem(
      jobId: json['jobId']?.toString() ?? '',
      chapterId: json['chapterId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      error: json['error']?.toString() ?? '',
    );
  }
}

class DownloadBatchResponse extends DownloadsResponse {
  const DownloadBatchResponse({
    required super.jobs,
    required super.queue,
    required this.matched,
    required this.queued,
    required this.failed,
    required this.items,
  });

  final int matched;
  final int queued;
  final int failed;
  final List<DownloadBatchItem> items;

  factory DownloadBatchResponse.fromJson(Map<String, dynamic> json) {
    final base = DownloadsResponse.fromJson(json);
    return DownloadBatchResponse(
      jobs: base.jobs,
      queue: base.queue,
      matched: (json['matched'] as num?)?.toInt() ?? 0,
      queued: (json['queued'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      items: (json['items'] as List? ?? const [])
          .map((item) =>
              DownloadBatchItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}

class ClearCompletedDownloadsResponse extends DownloadsResponse {
  const ClearCompletedDownloadsResponse({
    required super.jobs,
    required super.queue,
    required this.removed,
    required this.deleteFiles,
    required this.deleteErrors,
  });

  final int removed;
  final bool deleteFiles;
  final List<String> deleteErrors;

  factory ClearCompletedDownloadsResponse.fromJson(Map<String, dynamic> json) {
    final base = DownloadsResponse.fromJson(json);
    return ClearCompletedDownloadsResponse(
      jobs: base.jobs,
      queue: base.queue,
      removed: (json['removed'] as num?)?.toInt() ?? 0,
      deleteFiles: json['deleteFiles'] == true,
      deleteErrors: (json['deleteErrors'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
