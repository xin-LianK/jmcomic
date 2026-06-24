class DownloadJob {
  const DownloadJob({
    required this.id,
    required this.kind,
    required this.jmId,
    required this.status,
    required this.message,
    required this.progress,
    required this.totalImages,
    required this.completedImages,
    required this.downloadedBytes,
    required this.speedBps,
    required this.outputPaths,
    required this.previewImageCount,
    required this.previewUrl,
  });

  final String id;
  final String kind;
  final String jmId;
  final String status;
  final String message;
  final double progress;
  final int totalImages;
  final int completedImages;
  final int downloadedBytes;
  final double speedBps;
  final List<String> outputPaths;
  final int previewImageCount;
  final String previewUrl;

  factory DownloadJob.fromJson(Map<String, dynamic> json) {
    return DownloadJob(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      jmId: json['jmId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      totalImages: (json['totalImages'] as num?)?.toInt() ?? 0,
      completedImages: (json['completedImages'] as num?)?.toInt() ?? 0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      speedBps: (json['speedBps'] as num?)?.toDouble() ?? 0,
      outputPaths: (json['outputPaths'] as List? ?? const []).map((e) => e.toString()).toList(),
      previewImageCount: (json['previewImageCount'] as num?)?.toInt() ?? 0,
      previewUrl: json['previewUrl']?.toString() ?? '',
    );
  }
}
