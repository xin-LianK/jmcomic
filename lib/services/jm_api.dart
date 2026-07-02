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
  });

  final List<String> barkUrls;
  final int watchIntervalMinutes;
  final int downloadWorkers;
  final int photoWorkers;
  final int imageWorkers;
  final bool createPdf;
  final int pdfMergeWorkers;

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

  Future<List<DownloadJob>> downloads() async {
    final json = await _getApiJson('/downloads');
    return (json['jobs'] as List? ?? const [])
        .map((item) =>
            DownloadJob.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<DownloadJob> cancelDownload(String jobId) async {
    final json = await _postApiJson('/downloads/$jobId/cancel', {});
    return DownloadJob.fromJson(json);
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
