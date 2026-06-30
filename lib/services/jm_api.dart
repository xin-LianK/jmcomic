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
  });

  final List<String> barkUrls;
  final int watchIntervalMinutes;

  factory VisualSettings.fromJson(Map<String, dynamic> json) {
    return VisualSettings(
      barkUrls: (json['barkUrls'] as List? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      watchIntervalMinutes:
          (json['watchIntervalMinutes'] as num?)?.toInt() ?? 60,
    );
  }

  Map<String, dynamic> toJson() => {
        'barkUrls': barkUrls,
        'watchIntervalMinutes': watchIntervalMinutes,
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
          detail ?? 'HTTP ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> health() => _getJson(_uri('/health'));

  Future<AlbumPage> _getAlbumPage(Uri uri, {bool forceRefresh = false}) async {
    final key = uri.toString();
    if (!forceRefresh && _albumPageCache.containsKey(key)) {
      return _albumPageCache[key]!;
    }
    final json = await _getJson(uri);
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
    final json = await _getJson(_uri('/api/albums/$id'));
    return AlbumDetail.fromJson(json);
  }

  Future<PhotoDetail> photo(String id) async {
    final json = await _getJson(_uri('/api/photos/$id'));
    return PhotoDetail.fromJson(json);
  }

  Future<PhotoDetail> downloadPreview(String jobId) async {
    final json = await _getJson(_uri('/api/downloads/$jobId/preview'));
    return PhotoDetail.fromJson(json);
  }

  Future<DownloadJob> downloadAlbum(String id, {String albumTitle = ''}) async {
    final json = await _postJson(_uri('/api/downloads/albums'), {
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
    final json = await _postJson(_uri('/api/downloads/photos'), {
      'id': id,
      'albumId': albumId,
      'albumTitle': albumTitle,
      'episodeTitle': episodeTitle,
      'episodeIndex': episodeIndex,
    });
    return DownloadJob.fromJson(json);
  }

  Future<List<DownloadJob>> downloads() async {
    final json = await _getJson(_uri('/api/downloads'));
    return (json['jobs'] as List? ?? const [])
        .map((item) =>
            DownloadJob.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<VisualSettings> settings() async {
    final json = await _getJson(_uri('/api/settings'));
    return VisualSettings.fromJson(json);
  }

  Future<VisualSettings> saveSettings(VisualSettings settings) async {
    final json = await _putJson(_uri('/api/settings'), settings.toJson());
    return VisualSettings.fromJson(json);
  }

  Future<List<WatchedAlbum>> watchlist() async {
    final json = await _getJson(_uri('/api/watchlist'));
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
    final json = await _putJson(_uri('/api/watchlist/$id'), {
      'id': id,
      'title': title,
      'coverUrl': coverUrl,
      'enabled': enabled,
      'knownEpisodeIds': knownEpisodeIds,
    });
    return WatchedAlbum.fromJson(json);
  }
}
