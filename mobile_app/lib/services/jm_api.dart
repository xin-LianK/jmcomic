import 'dart:convert';

import 'package:flutter/foundation.dart';
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

class JmApi {
  JmApi({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = (baseUrl == null || baseUrl.trim().isEmpty ? defaultBaseUrl() : baseUrl.trim())
            .replaceAll(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static String defaultBaseUrl() {
    const configured = String.fromEnvironment('JM_API_BASE', defaultValue: '');
    if (configured.trim().isNotEmpty) {
      return configured.trim();
    }
    if (kIsWeb) {
      return Uri.base.origin;
    }
    return 'http://127.0.0.1:8766';
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

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? detail;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        detail = body['detail']?.toString();
      } catch (_) {
        detail = null;
      }
      throw JmApiException(detail ?? 'HTTP ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> health() => _getJson(_uri('/health'));

  Future<AlbumPage> search({
    required String query,
    int page = 1,
    String searchType = 'site',
    String orderBy = 'mr',
    String timeRange = 'a',
  }) async {
    final json = await _getJson(_uri('/api/albums/search', {
      'query': query,
      'page': '$page',
      'search_type': searchType,
      'order_by': orderBy,
      'time_range': timeRange,
    }));
    return AlbumPage.fromJson(json);
  }

  Future<AlbumPage> categories({
    int page = 1,
    String category = '0',
    String orderBy = 'mr',
    String timeRange = 'a',
  }) async {
    final json = await _getJson(_uri('/api/albums/categories', {
      'page': '$page',
      'category': category,
      'order_by': orderBy,
      'time_range': timeRange,
    }));
    return AlbumPage.fromJson(json);
  }

  Future<AlbumPage> ranking({
    required String period,
    int page = 1,
    String category = '0',
  }) async {
    final json = await _getJson(_uri('/api/albums/ranking/$period', {
      'page': '$page',
      'category': category,
    }));
    return AlbumPage.fromJson(json);
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

  Future<DownloadJob> downloadAlbum(String id) async {
    final json = await _postJson(_uri('/api/downloads/albums'), {'id': id});
    return DownloadJob.fromJson(json);
  }

  Future<DownloadJob> downloadPhoto(String id) async {
    final json = await _postJson(_uri('/api/downloads/photos'), {'id': id});
    return DownloadJob.fromJson(json);
  }

  Future<List<DownloadJob>> downloads() async {
    final json = await _getJson(_uri('/api/downloads'));
    return (json['jobs'] as List? ?? const [])
        .map((item) => DownloadJob.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
