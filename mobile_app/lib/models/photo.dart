class PhotoImage {
  const PhotoImage({
    required this.index,
    required this.filename,
    required this.url,
  });

  final int index;
  final String filename;
  final String url;

  factory PhotoImage.fromJson(Map<String, dynamic> json) {
    return PhotoImage(
      index: (json['index'] as num?)?.toInt() ?? 0,
      filename: json['filename']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }
}

class PhotoDetail {
  const PhotoDetail({
    required this.id,
    required this.albumId,
    required this.title,
    required this.imageCount,
    required this.images,
  });

  final String id;
  final String albumId;
  final String title;
  final int imageCount;
  final List<PhotoImage> images;

  factory PhotoDetail.fromJson(Map<String, dynamic> json) {
    return PhotoDetail(
      id: json['id']?.toString() ?? '',
      albumId: json['albumId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      imageCount: (json['imageCount'] as num?)?.toInt() ?? 0,
      images: (json['images'] as List? ?? const [])
          .map((item) => PhotoImage.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}
