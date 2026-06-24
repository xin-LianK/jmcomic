import 'package:flutter/material.dart';

import '../models/photo.dart';
import '../services/jm_api.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.api,
    required this.photoId,
    required this.title,
  }) : loader = _loadOnlinePhoto;

  const ReaderScreen.downloadPreview({
    super.key,
    required this.api,
    required String jobId,
    required this.title,
  })  : photoId = jobId,
        loader = _loadDownloadedPreview;

  final JmApi api;
  final String photoId;
  final String title;
  final Future<PhotoDetail> Function(JmApi api, String id) loader;

  static Future<PhotoDetail> _loadOnlinePhoto(JmApi api, String id) => api.photo(id);
  static Future<PhotoDetail> _loadDownloadedPreview(JmApi api, String id) => api.downloadPreview(id);

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late Future<PhotoDetail> _future;
  bool _fitWidth = true;

  @override
  void initState() {
    super.initState();
    _future = widget.loader(widget.api, widget.photoId);
  }

  void _reload() {
    setState(() => _future = widget.loader(widget.api, widget.photoId));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF070D10),
      appBar: AppBar(
        title: Text(widget.title.isEmpty ? 'Photo ${widget.photoId}' : widget.title),
        actions: [
          IconButton(
            tooltip: _fitWidth ? '原始宽度' : '适应宽度',
            onPressed: () => setState(() => _fitWidth = !_fitWidth),
            icon: Icon(_fitWidth ? Icons.fit_screen_outlined : Icons.open_in_full_outlined),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<PhotoDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(snapshot.error.toString(), textAlign: TextAlign.center),
              ),
            );
          }

          final photo = snapshot.data!;
          return ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: photo.images.length,
            itemBuilder: (context, index) {
              final image = photo.images[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Center(
                  child: InteractiveViewer(
                    minScale: .7,
                    maxScale: 4,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: _fitWidth ? 980 : double.infinity),
                      child: ColoredBox(
                        color: scheme.surface,
                        child: Image.network(
                          widget.api.assetUrl(image.url),
                          width: double.infinity,
                          fit: _fitWidth ? BoxFit.fitWidth : BoxFit.contain,
                          loadingBuilder: (context, child, loading) {
                            if (loading == null) return child;
                            return AspectRatio(
                              aspectRatio: .72,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loading.expectedTotalBytes == null
                                      ? null
                                      : loading.cumulativeBytesLoaded / loading.expectedTotalBytes!,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => AspectRatio(
                            aspectRatio: .72,
                            child: Center(child: Text('图片 ${image.index} 读取失败')),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
