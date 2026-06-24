class AlbumSummary {
  const AlbumSummary({
    required this.id,
    required this.title,
    required this.coverUrl,
    this.author = '',
    this.tags = const [],
  });

  final String id;
  final String title;
  final String coverUrl;
  final String author;
  final List<String> tags;

  factory AlbumSummary.fromJson(Map<String, dynamic> json) {
    return AlbumSummary(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      tags: (json['tags'] as List? ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

class AlbumPage {
  const AlbumPage({
    required this.total,
    required this.pageSize,
    required this.pageCount,
    required this.albums,
  });

  final int total;
  final int pageSize;
  final int pageCount;
  final List<AlbumSummary> albums;

  factory AlbumPage.fromJson(Map<String, dynamic> json) {
    return AlbumPage(
      total: (json['total'] as num?)?.toInt() ?? 0,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? 0,
      pageCount: (json['pageCount'] as num?)?.toInt() ?? 1,
      albums: (json['albums'] as List? ?? const [])
          .map((item) => AlbumSummary.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}

class Episode {
  const Episode({
    required this.id,
    required this.index,
    required this.title,
  });

  final String id;
  final int index;
  final String title;

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id']?.toString() ?? '',
      index: (json['index'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
    );
  }
}

class AlbumDetail {
  const AlbumDetail({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.episodes,
    this.authors = const [],
    this.tags = const [],
    this.actors = const [],
    this.works = const [],
    this.description = '',
    this.pageCount = 0,
    this.views = '',
    this.likes = '',
    this.commentCount = '',
    this.pubDate = '',
    this.updateDate = '',
  });

  final String id;
  final String title;
  final String coverUrl;
  final List<Episode> episodes;
  final List<String> authors;
  final List<String> tags;
  final List<String> actors;
  final List<String> works;
  final String description;
  final int pageCount;
  final String views;
  final String likes;
  final String commentCount;
  final String pubDate;
  final String updateDate;

  factory AlbumDetail.fromJson(Map<String, dynamic> json) {
    List<String> stringList(String key) {
      return (json[key] as List? ?? const []).map((e) => e.toString()).toList();
    }

    return AlbumDetail(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      episodes: (json['episodes'] as List? ?? const [])
          .map((item) => Episode.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      authors: stringList('authors'),
      tags: stringList('tags'),
      actors: stringList('actors'),
      works: stringList('works'),
      description: json['description']?.toString() ?? '',
      pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
      views: json['views']?.toString() ?? '',
      likes: json['likes']?.toString() ?? '',
      commentCount: json['commentCount']?.toString() ?? '',
      pubDate: json['pubDate']?.toString() ?? '',
      updateDate: json['updateDate']?.toString() ?? '',
    );
  }
}
