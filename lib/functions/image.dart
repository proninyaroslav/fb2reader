import 'dart:typed_data';

class ImageInfo {
  Uint8List? imageBytes;
  String title;
  String author;
  String fileName;
  double progress;

  ImageInfo(
      {this.imageBytes,
      required this.title,
      required this.author,
      required this.fileName,
      required this.progress});

  Map<String, dynamic> toJson() {
    return {
      'imageBytes': imageBytes,
      'title': title,
      'author': author,
      'fileName': fileName,
      'progress': progress,
    };
  }

  factory ImageInfo.fromJson(Map<String, dynamic> json) {
    return ImageInfo(
      imageBytes: Uint8List.fromList(List<int>.from(json['imageBytes'])),
      title: json['title'],
      author: json['author'],
      fileName: json['fileName'],
      progress: json['progress']?.toDouble() ?? 0.0,
    );
  }
}
