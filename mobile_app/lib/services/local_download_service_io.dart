import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/album.dart';
import '../models/download_job.dart';
import '../models/photo.dart';
import 'jm_api.dart';

class LocalDownloadService {
  LocalDownloadService._();

  static final LocalDownloadService instance = LocalDownloadService._();
  static const _downloadsKey = 'jm_visual_local_downloads_v1';

  Future<List<DownloadJob>> downloads() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_downloadsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map((item) =>
              DownloadJob.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<String> downloadsRoot() async => (await _rootDirectory()).path;

  Future<DownloadJob> downloadAlbum(
    JmApi api,
    AlbumDetail album, {
    ValueChanged<DownloadJob>? onChanged,
  }) async {
    var job = _newJob(kind: 'album', jmId: album.id, albumId: album.id);
    job = await _saveAndNotify(job, onChanged);
    final startedAt = DateTime.now();
    final outputPaths = <String>{};
    var totalImages = 0;
    var completedImages = 0;
    var downloadedBytes = 0;

    try {
      final albumDir = await _albumDirectory(album);
      outputPaths.add(albumDir.path);
      job = await _saveAndNotify(
        job.copyWith(message: '正在读取章节', outputPaths: outputPaths.toList()),
        onChanged,
      );

      for (final episode in album.episodes) {
        final photo = await api.photo(episode.id);
        totalImages += photo.images.length;
        job = await _saveAndNotify(
          _progressJob(
            job,
            totalImages: totalImages,
            completedImages: completedImages,
            downloadedBytes: downloadedBytes,
            startedAt: startedAt,
            message: '下载第 ${episode.index} 话',
            outputPaths: outputPaths.toList(),
          ),
          onChanged,
        );
        final result = await _downloadPhotoImages(
          api: api,
          album: album,
          episode: episode,
          photo: photo,
          startedAt: startedAt,
          initialJob: job,
          initialCompletedImages: completedImages,
          initialDownloadedBytes: downloadedBytes,
          totalImages: totalImages,
          outputPaths: outputPaths,
          onChanged: onChanged,
        );
        job = result.job;
        completedImages = result.completedImages;
        downloadedBytes = result.downloadedBytes;
        outputPaths
          ..clear()
          ..addAll(result.outputPaths);
      }

      return _saveAndNotify(
        _progressJob(
          job,
          totalImages: totalImages,
          completedImages: completedImages,
          downloadedBytes: downloadedBytes,
          startedAt: startedAt,
          status: 'done',
          message: '已保存到本机',
          outputPaths: outputPaths.toList(),
        ),
        onChanged,
      );
    } catch (error) {
      return _saveAndNotify(
        job.copyWith(
            status: 'failed',
            message: error.toString(),
            outputPaths: outputPaths.toList()),
        onChanged,
      );
    }
  }

  Future<DownloadJob> downloadPhoto(
    JmApi api,
    AlbumDetail album,
    Episode episode, {
    ValueChanged<DownloadJob>? onChanged,
  }) async {
    var job = _newJob(kind: 'photo', jmId: episode.id, albumId: album.id);
    job = await _saveAndNotify(job.copyWith(message: '正在读取章节'), onChanged);
    final startedAt = DateTime.now();
    final outputPaths = <String>{};

    try {
      final photo = await api.photo(episode.id);
      final result = await _downloadPhotoImages(
        api: api,
        album: album,
        episode: episode,
        photo: photo,
        startedAt: startedAt,
        initialJob: job,
        initialCompletedImages: 0,
        initialDownloadedBytes: 0,
        totalImages: photo.images.length,
        outputPaths: outputPaths,
        onChanged: onChanged,
      );

      return _saveAndNotify(
        _progressJob(
          result.job,
          totalImages: photo.images.length,
          completedImages: result.completedImages,
          downloadedBytes: result.downloadedBytes,
          startedAt: startedAt,
          status: 'done',
          message: '已保存到本机',
          outputPaths: result.outputPaths.toList(),
        ),
        onChanged,
      );
    } catch (error) {
      return _saveAndNotify(
        job.copyWith(
            status: 'failed',
            message: error.toString(),
            outputPaths: outputPaths.toList()),
        onChanged,
      );
    }
  }

  DownloadJob _newJob({
    required String kind,
    required String jmId,
    required String albumId,
  }) {
    return DownloadJob(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      kind: kind,
      jmId: jmId,
      albumId: albumId,
      albumTitle: '',
      episodeTitle: '',
      episodeIndex: 0,
      status: 'running',
      message: '准备下载到本机',
      progress: 0,
      totalImages: 0,
      completedImages: 0,
      downloadedBytes: 0,
      speedBps: 0,
      outputPaths: const [],
      previewImageCount: 0,
      previewUrl: '',
      chapters: const [],
    );
  }

  Future<_PhotoDownloadResult> _downloadPhotoImages({
    required JmApi api,
    required AlbumDetail album,
    required Episode episode,
    required PhotoDetail photo,
    required DateTime startedAt,
    required DownloadJob initialJob,
    required int initialCompletedImages,
    required int initialDownloadedBytes,
    required int totalImages,
    required Set<String> outputPaths,
    required ValueChanged<DownloadJob>? onChanged,
  }) async {
    var job = initialJob;
    var completedImages = initialCompletedImages;
    var downloadedBytes = initialDownloadedBytes;
    final directory = await _episodeDirectory(album, episode);
    outputPaths.add(directory.path);

    for (final image in photo.images) {
      final file = File('${directory.path}/${_imageFilename(image)}');
      if (!file.existsSync()) {
        final response = await http.get(Uri.parse(api.assetUrl(image.url)));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw JmApiException(
              '图片 ${image.index} 下载失败：HTTP ${response.statusCode}');
        }
        await file.writeAsBytes(response.bodyBytes);
        downloadedBytes += response.bodyBytes.length;
      } else {
        downloadedBytes += file.lengthSync();
      }
      completedImages += 1;
      job = await _saveAndNotify(
        _progressJob(
          job,
          totalImages: totalImages,
          completedImages: completedImages,
          downloadedBytes: downloadedBytes,
          startedAt: startedAt,
          message: '已保存 $completedImages/$totalImages 张',
          outputPaths: outputPaths.toList(),
        ),
        onChanged,
      );
    }

    return _PhotoDownloadResult(
      job: job,
      completedImages: completedImages,
      downloadedBytes: downloadedBytes,
      outputPaths: outputPaths,
    );
  }

  DownloadJob _progressJob(
    DownloadJob job, {
    required int totalImages,
    required int completedImages,
    required int downloadedBytes,
    required DateTime startedAt,
    String? status,
    String? message,
    List<String>? outputPaths,
  }) {
    final elapsed = DateTime.now().difference(startedAt).inMilliseconds / 1000;
    final progress = totalImages == 0
        ? 0.0
        : (completedImages / totalImages).clamp(0, 1).toDouble();
    return job.copyWith(
      status: status ?? job.status,
      message: message ?? job.message,
      progress: progress,
      totalImages: totalImages,
      completedImages: completedImages,
      downloadedBytes: downloadedBytes,
      speedBps: elapsed <= 0 ? 0 : downloadedBytes / elapsed,
      outputPaths: outputPaths ?? job.outputPaths,
      previewImageCount: completedImages,
    );
  }

  Future<DownloadJob> _saveAndNotify(
      DownloadJob job, ValueChanged<DownloadJob>? onChanged) async {
    final prefs = await SharedPreferences.getInstance();
    final jobs = await downloads();
    final index = jobs.indexWhere((item) => item.id == job.id);
    if (index >= 0) {
      jobs[index] = job;
    } else {
      jobs.insert(0, job);
    }
    await prefs.setString(
        _downloadsKey, jsonEncode(jobs.map((item) => item.toJson()).toList()));
    onChanged?.call(job);
    return job;
  }

  Future<Directory> _rootDirectory() async {
    final base = Platform.isAndroid
        ? (await getExternalStorageDirectory()) ??
            await getApplicationDocumentsDirectory()
        : await getApplicationDocumentsDirectory();
    final directory = Directory('${base.path}/JMVisual');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> _albumDirectory(AlbumDetail album) async {
    final root = await _rootDirectory();
    final title = _safeName(album.title.isEmpty ? 'Album' : album.title);
    final directory = Directory('${root.path}/JM${album.id}_$title');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> _episodeDirectory(
      AlbumDetail album, Episode episode) async {
    final albumDir = await _albumDirectory(album);
    final title = _safeName(
        episode.title.isEmpty ? 'Chapter_${episode.index}' : episode.title);
    final directory = Directory(
        '${albumDir.path}/${episode.index.toString().padLeft(3, '0')}_$title');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _imageFilename(PhotoImage image) {
    final fallback = '${image.index.toString().padLeft(5, '0')}.jpg';
    final source =
        image.filename.trim().isEmpty ? fallback : image.filename.trim();
    final safe = _safeName(source);
    if (safe.contains('.')) {
      return '${image.index.toString().padLeft(5, '0')}_$safe';
    }
    return '${image.index.toString().padLeft(5, '0')}_$safe.jpg';
  }

  String _safeName(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return 'untitled';
    return cleaned.length > 80 ? cleaned.substring(0, 80).trim() : cleaned;
  }
}

class _PhotoDownloadResult {
  const _PhotoDownloadResult({
    required this.job,
    required this.completedImages,
    required this.downloadedBytes,
    required this.outputPaths,
  });

  final DownloadJob job;
  final int completedImages;
  final int downloadedBytes;
  final Set<String> outputPaths;
}
