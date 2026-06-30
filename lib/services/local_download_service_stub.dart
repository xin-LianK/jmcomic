import 'package:flutter/foundation.dart';

import '../models/album.dart';
import '../models/download_job.dart';
import 'jm_api.dart';

class LocalDownloadService {
  LocalDownloadService._();

  static final LocalDownloadService instance = LocalDownloadService._();

  Future<List<DownloadJob>> downloads() async => const [];

  Future<String> downloadsRoot() async => '当前平台不支持写入本地文件';

  Future<DownloadJob> downloadAlbum(
    JmApi api,
    AlbumDetail album, {
    ValueChanged<DownloadJob>? onChanged,
  }) {
    throw UnsupportedError('当前平台不支持 APP 本地下载，请在 Android 或 iOS 客户端中使用。');
  }

  Future<DownloadJob> downloadPhoto(
    JmApi api,
    AlbumDetail album,
    Episode episode, {
    ValueChanged<DownloadJob>? onChanged,
  }) {
    throw UnsupportedError('当前平台不支持 APP 本地下载，请在 Android 或 iOS 客户端中使用。');
  }
}
