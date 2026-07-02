class DownloadChapter {
  const DownloadChapter({
    required this.id,
    required this.index,
    required this.title,
    required this.status,
    required this.totalImages,
    required this.completedImages,
    required this.downloadedBytes,
    required this.outputPath,
    required this.fileSize,
  });

  final String id;
  final int index;
  final String title;
  final String status;
  final int totalImages;
  final int completedImages;
  final int downloadedBytes;
  final String outputPath;
  final int fileSize;

  factory DownloadChapter.fromJson(Map<String, dynamic> json) {
    return DownloadChapter(
      id: json['id']?.toString() ?? '',
      index: (json['index'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      totalImages: (json['totalImages'] as num?)?.toInt() ?? 0,
      completedImages: (json['completedImages'] as num?)?.toInt() ?? 0,
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
        'totalImages': totalImages,
        'completedImages': completedImages,
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
    required this.downloadedBytes,
    required this.speedBps,
    required this.outputPaths,
    required this.previewImageCount,
    required this.previewUrl,
    required this.chapters,
    required this.pdfMerge,
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
  final int downloadedBytes;
  final double speedBps;
  final List<String> outputPaths;
  final int previewImageCount;
  final String previewUrl;
  final List<DownloadChapter> chapters;
  final PdfMergeState pdfMerge;

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
        'downloadedBytes': downloadedBytes,
        'speedBps': speedBps,
        'outputPaths': outputPaths,
        'previewImageCount': previewImageCount,
        'previewUrl': previewUrl,
        'chapters': chapters.map((item) => item.toJson()).toList(),
        'pdfMerge': pdfMerge.toJson(),
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
    int? downloadedBytes,
    double? speedBps,
    List<String>? outputPaths,
    int? previewImageCount,
    String? previewUrl,
    List<DownloadChapter>? chapters,
    PdfMergeState? pdfMerge,
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
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      speedBps: speedBps ?? this.speedBps,
      outputPaths: outputPaths ?? this.outputPaths,
      previewImageCount: previewImageCount ?? this.previewImageCount,
      previewUrl: previewUrl ?? this.previewUrl,
      chapters: chapters ?? this.chapters,
      pdfMerge: pdfMerge ?? this.pdfMerge,
    );
  }
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
