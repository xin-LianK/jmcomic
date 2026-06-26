import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class FavoriteAlbum {
  const FavoriteAlbum({
    required this.albumId,
    required this.title,
    required this.coverUrl,
    required this.savedAt,
    this.updateDate = '',
    this.updateWeekday = '',
  });

  final String albumId;
  final String title;
  final String coverUrl;
  final DateTime savedAt;
  final String updateDate;
  final String updateWeekday;

  Map<String, dynamic> toJson() => {
        'albumId': albumId,
        'title': title,
        'coverUrl': coverUrl,
        'savedAt': savedAt.toIso8601String(),
        'updateDate': updateDate,
        'updateWeekday': updateWeekday,
      };

  factory FavoriteAlbum.fromJson(Map<String, dynamic> json) {
    return FavoriteAlbum(
      albumId: json['albumId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updateDate: json['updateDate']?.toString() ?? '',
      updateWeekday: json['updateWeekday']?.toString() ?? '',
    );
  }
}

class RecentAlbum {
  const RecentAlbum({
    required this.albumId,
    required this.title,
    required this.coverUrl,
    required this.viewedAt,
    this.updateDate = '',
    this.updateWeekday = '',
  });

  final String albumId;
  final String title;
  final String coverUrl;
  final DateTime viewedAt;
  final String updateDate;
  final String updateWeekday;

  Map<String, dynamic> toJson() => {
        'albumId': albumId,
        'title': title,
        'coverUrl': coverUrl,
        'viewedAt': viewedAt.toIso8601String(),
        'updateDate': updateDate,
        'updateWeekday': updateWeekday,
      };

  factory RecentAlbum.fromJson(Map<String, dynamic> json) {
    return RecentAlbum(
      albumId: json['albumId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      viewedAt: DateTime.tryParse(json['viewedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updateDate: json['updateDate']?.toString() ?? '',
      updateWeekday: json['updateWeekday']?.toString() ?? '',
    );
  }
}

class ReadingProgress {
  const ReadingProgress({
    required this.albumId,
    required this.albumTitle,
    this.coverUrl = '',
    required this.photoId,
    required this.photoTitle,
    required this.episodeIndex,
    required this.episodeTitle,
    required this.updatedAt,
    this.readPhotoIds = const [],
  });

  final String albumId;
  final String albumTitle;
  final String coverUrl;
  final String photoId;
  final String photoTitle;
  final int episodeIndex;
  final String episodeTitle;
  final DateTime updatedAt;
  final List<String> readPhotoIds;

  Map<String, dynamic> toJson() => {
        'albumId': albumId,
        'albumTitle': albumTitle,
        'coverUrl': coverUrl,
        'photoId': photoId,
        'photoTitle': photoTitle,
        'episodeIndex': episodeIndex,
        'episodeTitle': episodeTitle,
        'updatedAt': updatedAt.toIso8601String(),
        'readPhotoIds': readPhotoIds,
      };

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      albumId: json['albumId']?.toString() ?? '',
      albumTitle: json['albumTitle']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      photoId: json['photoId']?.toString() ?? '',
      photoTitle: json['photoTitle']?.toString() ?? '',
      episodeIndex: (json['episodeIndex'] as num?)?.toInt() ?? 0,
      episodeTitle: json['episodeTitle']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      readPhotoIds: (json['readPhotoIds'] as List? ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }

  ReadingProgress copyWith({
    String? albumId,
    String? albumTitle,
    String? coverUrl,
    String? photoId,
    String? photoTitle,
    int? episodeIndex,
    String? episodeTitle,
    DateTime? updatedAt,
    List<String>? readPhotoIds,
  }) {
    return ReadingProgress(
      albumId: albumId ?? this.albumId,
      albumTitle: albumTitle ?? this.albumTitle,
      coverUrl: coverUrl ?? this.coverUrl,
      photoId: photoId ?? this.photoId,
      photoTitle: photoTitle ?? this.photoTitle,
      episodeIndex: episodeIndex ?? this.episodeIndex,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      updatedAt: updatedAt ?? this.updatedAt,
      readPhotoIds: readPhotoIds ?? this.readPhotoIds,
    );
  }
}

class LibraryStore {
  LibraryStore._();

  static final LibraryStore instance = LibraryStore._();

  static const _favoritesKey = 'jm_visual_favorites_v1';
  static const _continueKey = 'jm_visual_continue_v1';
  static const _historyKey = 'jm_visual_reading_history_v1';
  static const _recentKey = 'jm_visual_recent_albums_v1';

  Future<List<FavoriteAlbum>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoritesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map((item) =>
              FavoriteAlbum.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    } catch (_) {
      return const [];
    }
  }

  Future<bool> isFavorite(String albumId) async {
    final favorites = await loadFavorites();
    return favorites.any((item) => item.albumId == albumId);
  }

  Future<bool> toggleFavorite(FavoriteAlbum album) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await loadFavorites();
    final index = favorites.indexWhere((item) => item.albumId == album.albumId);
    var saved = true;
    if (index >= 0) {
      favorites.removeAt(index);
      saved = false;
    } else {
      favorites.insert(
        0,
        FavoriteAlbum(
          albumId: album.albumId,
          title: album.title,
          coverUrl: album.coverUrl,
          savedAt: DateTime.now(),
          updateDate: album.updateDate,
          updateWeekday: album.updateWeekday,
        ),
      );
      saved = true;
    }
    await prefs.setString(_favoritesKey,
        jsonEncode(favorites.map((item) => item.toJson()).toList()));
    return saved;
  }

  Future<List<RecentAlbum>> loadRecentAlbums() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final items = decoded
          .map((item) =>
              RecentAlbum.fromJson(Map<String, dynamic>.from(item as Map)))
          .where((item) => item.albumId.isNotEmpty)
          .toList();
      items.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
      return items;
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveRecentAlbum(RecentAlbum album) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await loadRecentAlbums();
    items.removeWhere((item) => item.albumId == album.albumId);
    items.insert(
      0,
      RecentAlbum(
        albumId: album.albumId,
        title: album.title,
        coverUrl: album.coverUrl,
        viewedAt: DateTime.now(),
        updateDate: album.updateDate,
        updateWeekday: album.updateWeekday,
      ),
    );
    final capped = items.take(60).toList();
    await prefs.setString(
        _recentKey, jsonEncode(capped.map((item) => item.toJson()).toList()));
  }

  Future<ReadingProgress?> loadContinueReading() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_continueKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        return ReadingProgress.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
      } catch (_) {
        // Fall through to the per-album history added after the original single-record store.
      }
    }

    final history = await loadReadingHistory();
    return history.isEmpty ? null : history.first;
  }

  Future<List<ReadingProgress>> loadReadingHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) {
      final legacy = await _loadLegacyContinueReading(prefs);
      return legacy == null ? const [] : [legacy];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final items = decoded
          .map((item) =>
              ReadingProgress.fromJson(Map<String, dynamic>.from(item as Map)))
          .where((item) => item.albumId.isNotEmpty)
          .toList();
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items;
    } catch (_) {
      return const [];
    }
  }

  Future<ReadingProgress?> loadAlbumProgress(String albumId) async {
    final history = await loadReadingHistory();
    for (final item in history) {
      if (item.albumId == albumId) return item;
    }

    final legacy = await loadContinueReading();
    return legacy?.albumId == albumId ? legacy : null;
  }

  Future<Set<String>> loadReadEpisodeIds(String albumId) async {
    final progress = await loadAlbumProgress(albumId);
    if (progress == null) return <String>{};
    return {
      ...progress.readPhotoIds,
      if (progress.photoId.isNotEmpty) progress.photoId,
    };
  }

  Future<void> saveContinueReading(ReadingProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadReadingHistory();
    final existingIndex =
        history.indexWhere((item) => item.albumId == progress.albumId);
    final previous =
        existingIndex >= 0 ? history.removeAt(existingIndex) : null;
    final readIds = <String>{
      if (previous != null) ...previous.readPhotoIds,
      ...progress.readPhotoIds,
      if (progress.photoId.isNotEmpty) progress.photoId,
    }.toList();
    final merged = progress.copyWith(
      coverUrl:
          progress.coverUrl.isNotEmpty ? progress.coverUrl : previous?.coverUrl,
      albumTitle: progress.albumTitle.isNotEmpty
          ? progress.albumTitle
          : previous?.albumTitle,
      readPhotoIds: readIds,
      updatedAt: DateTime.now(),
    );
    history.insert(0, merged);
    await prefs.setString(
        _historyKey, jsonEncode(history.map((item) => item.toJson()).toList()));
    await prefs.setString(_continueKey, jsonEncode(merged.toJson()));
  }

  Future<ReadingProgress?> _loadLegacyContinueReading(
      SharedPreferences prefs) async {
    final raw = prefs.getString(_continueKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final progress = ReadingProgress.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
      if (progress.albumId.isEmpty) return null;
      return progress.copyWith(
        readPhotoIds: {
          ...progress.readPhotoIds,
          if (progress.photoId.isNotEmpty) progress.photoId,
        }.toList(),
      );
    } catch (_) {
      return null;
    }
  }
}
