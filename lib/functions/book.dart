import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:merlin/functions/image.dart';
import 'package:path_provider/path_provider.dart';

class LastPosition {
  int paragraph;
  double offset;

  LastPosition({required this.paragraph, required this.offset});

  Map<String, dynamic> toJson() {
    return {'paragraph': paragraph, 'offset': offset};
  }

  factory LastPosition.fromJson(Map<String, dynamic> json) {
    return LastPosition(
      paragraph: json['paragraph'],
      offset: json['offset'],
    );
  }

  @override
  String toString() {
    return 'LastPosition {paragraph: $paragraph, offset: $offset}';
  }
}

class BookSequence {
  String name;
  String? number;

  BookSequence({required this.name, required this.number});

  Map<String, dynamic> toJson() {
    return {'name': name, 'number': number};
  }

  factory BookSequence.fromJson(Map<String, dynamic> json) {
    return BookSequence(
      name: json['name'],
      number: json['number'],
    );
  }

  @override
  String toString() {
    return 'BookSequence {name: $name, number: $number}';
  }
}

class BookInfo {
  String filePath;
  String fileText;
  String title;
  String author;
  double? lastPosition; // маяк BookInfo
  int version;
  LastPosition? lp;
  BookSequence? sequence;
  DateTime dateAdded;

  BookInfo(
      {required this.filePath,
      required this.fileText,
      required this.title,
      required this.author,
      required this.sequence,
      required this.dateAdded,
      this.version = 1,
      this.lastPosition = 0,
      this.lp});

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'fileText': fileText,
      'title': title,
      'author': author,
      'lastPosition': lastPosition,
      'lp': lp?.toJson(),
      'sequence': sequence?.toJson(),
      'dateAdded': dateAdded.toIso8601String(),
    };
  }

  void setPosZero() {
    lastPosition = 0;
  }

  factory BookInfo.fromJson(Map<String, dynamic> json) {
    return BookInfo(
        filePath: json['filePath'],
        fileText: json['fileText'],
        title: json['title'],
        author: json['author'],
        lastPosition: json['lastPosition'],
        lp: LastPosition.fromJson(json['lp']),
        sequence: json['sequence'] == null
            ? null
            : BookSequence.fromJson(json['sequence']),
        dateAdded: (json['dateAdded'] == null
                ? null
                : DateTime.tryParse(json['dateAdded'])) ??
            DateTime.fromMillisecondsSinceEpoch(0));
  }
}

class Book {
  final String filePath;
  final String text;
  final String title;
  final String customTitle;
  final String author;
  final double? lastPosition;
  final Uint8List? imageBytes;
  final double? progress;
  final LastPosition? lp;
  final int version;
  final BookSequence? sequence;
  final DateTime dateAdded;

  Book(
      {required this.filePath,
      required this.text,
      required this.title,
      required this.customTitle,
      required this.author,
      this.lastPosition = 0,
      required this.sequence,
      required this.dateAdded,
      this.imageBytes,
      this.progress,
      this.lp,
      this.version = 0});

  factory Book.combine(BookInfo bookInfo, ImageInfo imageInfo) {
    return Book(
        filePath: bookInfo.filePath,
        text: bookInfo.fileText,
        title: bookInfo.title,
        customTitle: bookInfo.title,
        author: bookInfo.author,
        lastPosition: bookInfo.lastPosition,
        imageBytes: imageInfo.imageBytes,
        progress: imageInfo.progress,
        version: bookInfo.version,
        sequence: bookInfo.sequence,
        dateAdded: bookInfo.dateAdded);
  }

  @override
  String toString() {
    return 'Book {filePath: $filePath, title: $title, author: $author, lastPosition: $lastPosition, progress: $progress, text: ${text.substring(0, (text.length * 0.1).toInt())}}, sequence: $sequence';
  }

  Map<String, dynamic> toJson() {
    return {
      'filePath': filePath,
      'title': title,
      'customTitle': title,
      'author': author,
      'progress': progress,
      'lastPosition': lastPosition,
      'text': text,
      'imageBytes': imageBytes?.toList(),
      'version': 2,
      'lp': lp?.toJson(),
      'sequence': sequence?.toJson(),
      'dateAdded': dateAdded.toIso8601String(),
    };
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
        filePath: json['filePath'],
        title: json['title'],
        customTitle: json['customTitle'],
        author: json['author'],
        progress: json['progress'],
        lastPosition: json['lastPosition'],
        text: json['text'],
        imageBytes: json['imageBytes'] != null
            ? Uint8List.fromList(json['imageBytes'].cast<int>())
            : null,
        lp: LastPosition.fromJson(
            json['lp'] ?? {'paragraph': 0, 'offset': 0.0}),
        version: json['version'] ?? 0,
        sequence: json['sequence'] == null
            ? null
            : BookSequence.fromJson(json['sequence']),
        dateAdded: (json['dateAdded'] == null
                ? null
                : DateTime.tryParse(json['dateAdded'])) ??
            DateTime.fromMillisecondsSinceEpoch(0));
  }

  Future<void> saveJsonToFile(
      Map<String, dynamic> jsonData, String fileName) async {
    try {
      // print('Saving inside book class file...');
      final appDir = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();
      // print(appDir?.path);
      final filePath = '${appDir?.path}/books/$fileName.json';

      final file = File(filePath);
      await file.writeAsString(jsonEncode(jsonData));

      // print('Файл успешно сохранен по пути: $filePath');
    } catch (e) {
      // print('Ошибка при сохранении файла: $e');
    }
  }

  Future<void> delete() async {
    try {
      final appDir = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();
      final dataFilePath = '${appDir?.path}/books/$title.json';

      final file = File(dataFilePath);

      if (await file.exists()) {
        await file.delete();
        // print('Файл $title успешно удален');
      } else {
        // print('Файл $title не найден');
      }

      final originalFile = File(filePath);
      if (await originalFile.exists()) {
        await originalFile.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Unable to delete original file: $e');
      }
    }
  }

  Future<void> updateTextInFile(String newText) async {
    try {
      final appDir = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();
      final filePath = '${appDir?.path}/books/$title.json';

      final file = File(filePath);
      String content = await file.readAsString();
      Map<String, dynamic> jsonMap = jsonDecode(content);

      jsonMap['text'] = newText;

      await file.writeAsString(jsonEncode(jsonMap));
    } catch (e) {
      // print('Ошибка при обновлении текста в файле: $e');
    }
  }

  Future<void> updateTitleInFile(String newTitle) async {
    try {
      final appDir = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();
      final filePath = '${appDir?.path}/books/$title.json';

      final file = File(filePath);
      String content = await file.readAsString();
      Map<String, dynamic> jsonMap = jsonDecode(content);

      jsonMap['customTitle'] = newTitle;

      await file.writeAsString(jsonEncode(jsonMap));
    } catch (e) {
      // print('Ошибка при обновлении заголовка в файле: $e');
    }
  }

  Future<void> updateAuthorInFile(String newAuthor) async {
    try {
      final appDir = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();
      final filePath = '${appDir?.path}/books/$title.json';

      final file = File(filePath);
      String content = await file.readAsString();
      Map<String, dynamic> jsonMap = jsonDecode(content);

      jsonMap['author'] = newAuthor;

      await file.writeAsString(jsonEncode(jsonMap));
    } catch (e) {
      // print('Ошибка при обновлении автора в файле: $e');
    }
  }

  Future<void> updateLastPositionInFile(double newLastPosition) async {
    try {
      final appDir = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();
      final filePath = '${appDir?.path}/books/$title.json';

      final file = File(filePath);
      String content = await file.readAsString();
      Map<String, dynamic> jsonMap = jsonDecode(content);

      jsonMap['lastPosition'] = newLastPosition;

      await file.writeAsString(jsonEncode(jsonMap));
    } catch (e) {
      // print('Ошибка при обновлении последней позиции в файле: $e');
    }
  }

  Future<void> updateProgressInFile(double newProgress) async {
    try {
      // print('Updating PROGRESS inside book class file...');

      final appDir = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();
      final filePath = '${appDir?.path}/books/$title.json';
      // print(filePath);

      final file = File(filePath);
      String content = await file.readAsString();
      Map<String, dynamic> jsonMap = jsonDecode(content);

      jsonMap['progress'] = newProgress;

      await file.writeAsString(jsonEncode(jsonMap));
    } catch (e) {
      // print('Ошибка при обновлении прогресса в файле: $e');
    }
  }

  Future<void> updateStageInFile(
      double newProgress, double newLastPosition, int pg) async {
    try {
      // print('Updating STAGE inside book class file...');

      final appDir = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();
      final filePath = '${appDir?.path}/books/$title.json';
      // print(filePath);

      final file = File(filePath);
      String content = await file.readAsString();
      Map<String, dynamic> jsonMap = jsonDecode(content);

      jsonMap['progress'] = newProgress;
      jsonMap['lastPosition'] = newLastPosition;
      jsonMap['lp'] = <String, dynamic>{};
      jsonMap['lp']['offset'] = newLastPosition;
      jsonMap['lp']['paragraph'] = pg;
      jsonMap['version'] = 2;

      await file.writeAsString(jsonEncode(jsonMap));
    } catch (e) {
      // print('Ошибка при обновлении прогресса и позиции в файле: $e');
    }
  }
}

extension BookExtensions on Book {
  bool filterByMetadata(String? query) =>
      query == null ||
      query.isEmpty ||
      title.toLowerCase().contains(query) ||
      customTitle.toLowerCase().contains(query) ||
      author.toLowerCase().contains(query) ||
      (sequence != null && sequence!.filterByMetadata(query));
}

extension BookSequenseExtensions on BookSequence {
  bool filterByMetadata(String? query) =>
      query == null ||
      query.isEmpty ||
      name.toLowerCase().contains(query) ||
      (number != null && number!.toLowerCase().contains(query));
}

enum BooksSort {
  unknown,
  dateAddedDesc,
  dateAddedAsc;

  factory BooksSort.fromString(String str) {
    for (final value in values) {
      if (value.name == str) {
        return value;
      }
    }
    return BooksSort.unknown;
  }

  int sort(Book a, Book b) => switch (this) {
        BooksSort.unknown => 0,
        BooksSort.dateAddedDesc => b.dateAdded.compareTo(a.dateAdded),
        BooksSort.dateAddedAsc => a.dateAdded.compareTo(b.dateAdded)
      };

  String? toLocalizedString() => switch (this) {
        BooksSort.unknown => null,
        BooksSort.dateAddedDesc => "по дате добавления (новые)",
        BooksSort.dateAddedAsc => "по дате добавления (старые)",
      };
}
