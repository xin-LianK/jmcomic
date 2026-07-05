import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/album.dart';
import '../models/download_job.dart';
import '../models/photo.dart';

class JmApiException implements Exception {
  const JmApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class VisualSettings {
  const VisualSettings({
    required this.barkUrls,
    required this.watchIntervalMinutes,
    required this.downloadWorkers,
    required this.photoWorkers,
    required this.imageWorkers,
    required this.createPdf,
    required this.pdfMergeWorkers,
    required this.downloadsPaused,
  });

  final List<String> barkUrls;
  final int watchIntervalMinutes;
  final int downloadWorkers;
  final int photoWorkers;
  final int imageWorkers;
  final bool createPdf;
  final int pdfMergeWorkers;
  final bool downloadsPaused;

  factory VisualSettings.fromJson(Map<String, dynamic> json) {
    return VisualSettings(
      barkUrls: (json['barkUrls'] as List? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      watchIntervalMinutes:
          (json['watchIntervalMinutes'] as num?)?.toInt() ?? 60,
      downloadWorkers: (json['downloadWorkers'] as num?)?.toInt() ?? 1,
      photoWorkers: (json['photoWorkers'] as num?)?.toInt() ?? 20,
      imageWorkers: (json['imageWorkers'] as num?)?.toInt() ?? 30,
      createPdf: json['createPdf'] == true,
      pdfMergeWorkers: (json['pdfMergeWorkers'] as num?)?.toInt() ?? 3,
      downloadsPaused: json['downloadsPaused'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'barkUrls': barkUrls,
        'watchIntervalMinutes': watchIntervalMinutes,
        'downloadWorkers': downloadWorkers,
        'photoWorkers': photoWorkers,
        'imageWorkers': imageWorkers,
        'createPdf': createPdf,
        'pdfMergeWorkers': pdfMergeWorkers,
        'downloadsPaused': downloadsPaused,
      };
}

class WatchedAlbum {
  const WatchedAlbum({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.enabled,
    required this.knownEpisodeIds,
    required this.updateDate,
    required this.updateWeekday,
  });

  final String id;
  final String title;
  final String coverUrl;
  final bool enabled;
  final List<String> knownEpisodeIds;
  final String updateDate;
  final String updateWeekday;

  factory WatchedAlbum.fromJson(Map<String, dynamic> json) {
    return WatchedAlbum(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      enabled: json['enabled'] == true,
      knownEpisodeIds: (json['knownEpisodeIds'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      updateDate: json['updateDate']?.toString() ?? '',
      updateWeekday: json['updateWeekday']?.toString() ?? '',
    );
  }
}

class JmSchedulerRunStatus {
  const JmSchedulerRunStatus({
    required this.enabled,
    required this.running,
    required this.intervalMinutes,
    required this.nextRunAt,
    required this.lastStartedAt,
    required this.lastFinishedAt,
    required this.lastDurationSeconds,
    required this.lastCandidateCount,
    required this.lastSuccessCount,
    required this.lastFailedCount,
    required this.lastAlbumIds,
    required this.lastFailedIds,
    required this.lastError,
    this.batchSize,
    this.maxAgeMinutes,
    this.pages,
    this.category,
    this.orderBy,
    this.timeRange,
  });

  final bool enabled;
  final bool running;
  final int intervalMinutes;
  final String nextRunAt;
  final String lastStartedAt;
  final String lastFinishedAt;
  final int lastDurationSeconds;
  final int lastCandidateCount;
  final int lastSuccessCount;
  final int lastFailedCount;
  final List<String> lastAlbumIds;
  final List<String> lastFailedIds;
  final String lastError;
  final int? batchSize;
  final int? maxAgeMinutes;
  final int? pages;
  final String? category;
  final String? orderBy;
  final String? timeRange;

  factory JmSchedulerRunStatus.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return JmSchedulerRunStatus(
      enabled: data['enabled'] == true,
      running: data['running'] == true,
      intervalMinutes: (data['intervalMinutes'] as num?)?.toInt() ?? 0,
      nextRunAt: data['nextRunAt']?.toString() ?? '',
      lastStartedAt: data['lastStartedAt']?.toString() ?? '',
      lastFinishedAt: data['lastFinishedAt']?.toString() ?? '',
      lastDurationSeconds:
          (data['lastDurationSeconds'] as num?)?.toInt() ?? 0,
      lastCandidateCount: (data['lastCandidateCount'] as num?)?.toInt() ?? 0,
      lastSuccessCount: (data['lastSuccessCount'] as num?)?.toInt() ?? 0,
      lastFailedCount: (data['lastFailedCount'] as num?)?.toInt() ?? 0,
      lastAlbumIds: _stringList(data['lastAlbumIds']),
      lastFailedIds: _stringList(data['lastFailedIds']),
      lastError: data['lastError']?.toString() ?? '',
      batchSize: (data['batchSize'] as num?)?.toInt(),
      maxAgeMinutes: (data['maxAgeMinutes'] as num?)?.toInt(),
      pages: (data['pages'] as num?)?.toInt(),
      category: data['category']?.toString(),
      orderBy: data['orderBy']?.toString(),
      timeRange: data['timeRange']?.toString(),
    );
  }
}

class JmTaskRun {
  const JmTaskRun({
    required this.id,
    required this.taskType,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.durationSeconds,
    required this.candidateCount,
    required this.successCount,
    required this.failedCount,
    required this.albumIds,
    required this.failedIds,
    required this.error,
  });

  final int id;
  final String taskType;
  final String status;
  final String startedAt;
  final String finishedAt;
  final int durationSeconds;
  final int candidateCount;
  final int successCount;
  final int failedCount;
  final List<String> albumIds;
  final List<String> failedIds;
  final String error;

  factory JmTaskRun.fromJson(Map<String, dynamic> json) {
    return JmTaskRun(
      id: (json['id'] as num?)?.toInt() ?? 0,
      taskType: json['taskType']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      startedAt: json['startedAt']?.toString() ?? '',
      finishedAt: json['finishedAt']?.toString() ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      candidateCount: (json['candidateCount'] as num?)?.toInt() ?? 0,
      successCount: (json['successCount'] as num?)?.toInt() ?? 0,
      failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
      albumIds: _stringList(json['albumIds']),
      failedIds: _stringList(json['failedIds']),
      error: json['error']?.toString() ?? '',
    );
  }
}

class JmWatchRuntimeStatus {
  const JmWatchRuntimeStatus({
    required this.enabled,
    required this.running,
    required this.intervalMinutes,
    required this.watchCount,
    required this.enabledCount,
    required this.lastCheckedAt,
    required this.nextCheckAt,
  });

  final bool enabled;
  final bool running;
  final int intervalMinutes;
  final int watchCount;
  final int enabledCount;
  final int lastCheckedAt;
  final int nextCheckAt;

  factory JmWatchRuntimeStatus.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return JmWatchRuntimeStatus(
      enabled: data['enabled'] == true,
      running: data['running'] == true,
      intervalMinutes: (data['intervalMinutes'] as num?)?.toInt() ?? 0,
      watchCount: (data['watchCount'] as num?)?.toInt() ?? 0,
      enabledCount: (data['enabledCount'] as num?)?.toInt() ?? 0,
      lastCheckedAt: (data['lastCheckedAt'] as num?)?.toInt() ?? 0,
      nextCheckAt: (data['nextCheckAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class JmSchedulerStatus {
  const JmSchedulerStatus({
    required this.metadataSync,
    required this.latestDiscovery,
    required this.watch,
    required this.recentRuns,
  });

  final JmSchedulerRunStatus metadataSync;
  final JmSchedulerRunStatus latestDiscovery;
  final JmWatchRuntimeStatus watch;
  final List<JmTaskRun> recentRuns;

  factory JmSchedulerStatus.fromJson(Map<String, dynamic> json) {
    return JmSchedulerStatus(
      metadataSync: JmSchedulerRunStatus.fromJson(
          json['metadataSync'] is Map
              ? Map<String, dynamic>.from(json['metadataSync'] as Map)
              : null),
      latestDiscovery: JmSchedulerRunStatus.fromJson(
          json['latestDiscovery'] is Map
              ? Map<String, dynamic>.from(json['latestDiscovery'] as Map)
              : null),
      watch: JmWatchRuntimeStatus.fromJson(json['watch'] is Map
          ? Map<String, dynamic>.from(json['watch'] as Map)
          : null),
      recentRuns: (json['recentRuns'] as List? ?? const [])
          .map((item) => JmTaskRun.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}

class JmSchedulerRunTriggerResponse {
  const JmSchedulerRunTriggerResponse({
    required this.taskType,
    required this.started,
    required this.message,
  });

  final String taskType;
  final bool started;
  final String message;

  factory JmSchedulerRunTriggerResponse.fromJson(Map<String, dynamic> json) {
    return JmSchedulerRunTriggerResponse(
      taskType: json['taskType']?.toString() ?? '',
      started: json['started'] == true,
      message: json['message']?.toString() ?? '',
    );
  }
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList();
}

class JmApi {
  JmApi({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = (baseUrl == null || baseUrl.trim().isEmpty
                ? defaultBaseUrl()
                : baseUrl.trim())
            .replaceAll(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  static final Map<String, AlbumPage> _albumPageCache = {};

  static String defaultBaseUrl() {
    const configured = String.fromEnvironment('JM_API_BASE', defaultValue: '');
    if (configured.trim().isNotEmpty) {
      return configured.trim();
    }
    return 'http://192.168.2.118:8766';
  }

  static List<String> defaultApiPrefixes() {
    const configured = String.fromEnvironment('JM_API_PREFIX', defaultValue: '');
    if (configured.trim().isNotEmpty) {
      return [configured.trim().replaceAll(RegExp(r'/$'), '')];
    }
    return const ['/api/jm', '/api'];
  }

  Uri _uri(String path, [Map<String, String?> query = const {}]) {
    final filtered = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value != null && value.isNotEmpty) {
        filtered[entry.key] = value;
      }
    }
    return Uri.parse('$baseUrl$path').replace(queryParameters: filtered);
  }

  String assetUrl(String path) {
    if (path.startsWith('http')) return path;
    return '$baseUrl$path';
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client.get(uri);
    return _decode(response);
  }

  Future<Map<String, dynamic>> _postJson(Uri uri, Object body) async {
    final response = await _client.post(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> _withApiFallback(
    Future<Map<String, dynamic>> Function(String prefix) request,
  ) async {
    JmApiException? lastError;
    for (final prefix in defaultApiPrefixes()) {
      try {
        return await request(prefix);
      } on JmApiException catch (error) {
        lastError = error;
        if (!error.message.startsWith('HTTP 404:')) {
          rethrow;
        }
      }
    }
    throw lastError ?? const JmApiException('API endpoint not found');
  }

  Future<Map<String, dynamic>> _getApiJson(
    String path, [
    Map<String, String?> query = const {},
  ]) {
    return _withApiFallback((prefix) => _getJson(_uri('$prefix$path', query)));
  }

  Future<Map<String, dynamic>> _postApiJson(String path, Object body) {
    return _withApiFallback((prefix) => _postJson(_uri('$prefix$path'), body));
  }

  Future<Map<String, dynamic>> _putApiJson(String path, Object body) {
    return _withApiFallback((prefix) => _putJson(_uri('$prefix$path'), body));
  }

  Future<Map<String, dynamic>> _putJson(Uri uri, Object body) async {
    final response = await _client.put(
      uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? detail;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        detail = body['detail']?.toString();
      } catch (_) {
        detail = null;
      }
      throw JmApiException(
          'HTTP ${response.statusCode}: ${detail ?? response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> health() async {
    JmApiException? lastError;
    final paths = <String>{
      for (final prefix in defaultApiPrefixes()) '$prefix/health',
      '/health',
    }.toList();
    for (final path in paths) {
      try {
        return await _getJson(_uri(path));
      } on JmApiException catch (error) {
        lastError = error;
        if (!error.message.startsWith('HTTP 404:')) {
          rethrow;
        }
      }
    }
    throw lastError ?? const JmApiException('Health endpoint not found');
  }

  Future<AlbumPage> _getAlbumPage(Uri uri, {bool forceRefresh = false}) async {
    final key = uri.toString();
    if (!forceRefresh && _albumPageCache.containsKey(key)) {
      return _albumPageCache[key]!;
    }
    final path = uri.path.replaceFirst(RegExp(r'^/api(/jm)?'), '');
    final json = await _getApiJson(path, uri.queryParameters);
    final page = AlbumPage.fromJson(json);
    _albumPageCache[key] = page;
    return page;
  }

  Future<AlbumPage> search({
    required String query,
    int page = 1,
    String searchType = 'site',
    String orderBy = 'mr',
    String timeRange = 'a',
    bool forceRefresh = false,
  }) async {
    return _getAlbumPage(
        _uri('/api/albums/search', {
          'query': query,
          'page': '$page',
          'search_type': searchType,
          'order_by': orderBy,
          'time_range': timeRange,
        }),
        forceRefresh: forceRefresh);
  }

  Future<AlbumPage> categories({
    int page = 1,
    String category = '0',
    String orderBy = 'mr',
    String timeRange = 'a',
    bool forceRefresh = false,
  }) async {
    return _getAlbumPage(
        _uri('/api/albums/categories', {
          'page': '$page',
          'category': category,
          'order_by': orderBy,
          'time_range': timeRange,
        }),
        forceRefresh: forceRefresh);
  }

  Future<AlbumPage> ranking({
    required String period,
    int page = 1,
    String category = '0',
    bool forceRefresh = false,
  }) async {
    return _getAlbumPage(
        _uri('/api/albums/ranking/$period', {
          'page': '$page',
          'category': category,
        }),
        forceRefresh: forceRefresh);
  }

  Future<AlbumDetail> album(String id) async {
    final json = await _getApiJson('/albums/$id');
    return AlbumDetail.fromJson(json);
  }

  Future<PhotoDetail> photo(String id) async {
    final json = await _getApiJson('/photos/$id');
    return PhotoDetail.fromJson(json);
  }

  Future<PhotoDetail> downloadPreview(String jobId) async {
    final json = await _getApiJson('/downloads/$jobId/preview');
    return PhotoDetail.fromJson(json);
  }

  Future<PhotoDetail> downloadChapterPreview(
      String jobId, String chapterId) async {
    final json =
        await _getApiJson('/downloads/$jobId/chapters/$chapterId/preview');
    return PhotoDetail.fromJson(json);
  }

  Future<DownloadJob> downloadAlbum(String id, {String albumTitle = ''}) async {
    final json = await _postApiJson('/downloads/albums', {
      'id': id,
      'albumId': id,
      'albumTitle': albumTitle,
    });
    return DownloadJob.fromJson(json);
  }

  Future<DownloadJob> downloadPhoto(
    String id, {
    String albumId = '',
    String albumTitle = '',
    String episodeTitle = '',
    int episodeIndex = 0,
  }) async {
    final json = await _postApiJson('/downloads/photos', {
      'id': id,
      'albumId': albumId,
      'albumTitle': albumTitle,
      'episodeTitle': episodeTitle,
      'episodeIndex': episodeIndex,
    });
    return DownloadJob.fromJson(json);
  }

  Future<DownloadsResponse> downloads() async {
    final json = await _getApiJson('/downloads');
    return DownloadsResponse.fromJson(json);
  }

  Future<DownloadsResponse> recoverDownloads({bool sourceLookup = true}) async {
    final json = await _withApiFallback((prefix) => _postJson(
          _uri('$prefix/downloads/recover', {
            'source_lookup': sourceLookup ? 'true' : 'false',
          }),
          {},
        ));
    return DownloadsResponse.fromJson(json);
  }

  Future<DownloadBatchResponse> retryFailedDownloads() async {
    final json = await _postApiJson('/downloads/batch/retry-failed', {});
    return DownloadBatchResponse.fromJson(json);
  }

  Future<DownloadBatchResponse> downloadMissingImages() async {
    final json = await _postApiJson('/downloads/batch/download-missing', {});
    return DownloadBatchResponse.fromJson(json);
  }

  Future<ClearCompletedDownloadsResponse> clearCompletedDownloads({
    bool deleteFiles = false,
  }) async {
    final json = await _postApiJson('/downloads/batch/clear-completed', {
      'deleteFiles': deleteFiles,
    });
    return ClearCompletedDownloadsResponse.fromJson(json);
  }

  Future<DownloadsResponse> pauseDownloadQueue() async {
    final json = await _postApiJson('/downloads/queue/pause', {});
    return DownloadsResponse.fromJson(json);
  }

  Future<DownloadsResponse> resumeDownloadQueue() async {
    final json = await _postApiJson('/downloads/queue/resume', {});
    return DownloadsResponse.fromJson(json);
  }

  Future<DownloadJob> cancelDownload(String jobId) async {
    final json = await _postApiJson('/downloads/$jobId/cancel', {});
    return DownloadJob.fromJson(json);
  }

  Future<DownloadJob> resumeDownload(String jobId) async {
    final json = await _postApiJson('/downloads/$jobId/resume', {});
    return DownloadJob.fromJson(json);
  }

  Future<DownloadsResponse> updateDownloadPriority(
      String jobId, String action) async {
    final json = await _postApiJson('/downloads/$jobId/priority', {
      'action': action,
    });
    return DownloadsResponse.fromJson(json);
  }

  Future<DownloadJob> mergeDownloadPdf(String jobId) async {
    final json = await _postApiJson('/downloads/$jobId/pdf', {});
    return DownloadJob.fromJson(json);
  }

  Future<VisualSettings> settings() async {
    final json = await _getApiJson('/settings');
    return VisualSettings.fromJson(json);
  }

  Future<VisualSettings> saveSettings(VisualSettings settings) async {
    final json = await _putApiJson('/settings', settings.toJson());
    return VisualSettings.fromJson(json);
  }

  Future<JmSchedulerStatus> schedulerStatus() async {
    final json = await _getApiJson('/scheduler/status');
    return JmSchedulerStatus.fromJson(json);
  }

  Future<JmSchedulerRunTriggerResponse> runSchedulerTask(
      String taskType) async {
    final json = await _postApiJson('/scheduler/run/$taskType', {});
    return JmSchedulerRunTriggerResponse.fromJson(json);
  }

  Future<List<WatchedAlbum>> watchlist() async {
    final json = await _getApiJson('/watchlist');
    return (json['albums'] as List? ?? const [])
        .map((item) =>
            WatchedAlbum.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<WatchedAlbum> setWatchedAlbum({
    required String id,
    required String title,
    required String coverUrl,
    required bool enabled,
    List<String> knownEpisodeIds = const [],
  }) async {
    final json = await _putApiJson('/watchlist/$id', {
      'id': id,
      'title': title,
      'coverUrl': coverUrl,
      'enabled': enabled,
      'knownEpisodeIds': knownEpisodeIds,
    });
    return WatchedAlbum.fromJson(json);
  }
}
