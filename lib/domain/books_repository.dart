import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_charset_detector/flutter_charset_detector.dart';
import 'package:merlin/domain/data_providers/sembast_provider.dart';
import 'package:merlin/functions/book.dart';
import 'package:merlin/functions/image.dart';
import 'package:merlin/functions/recent_book.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:xml/xml.dart';

sealed class SaveBookResult {}

class SaveBookResultSuccess extends SaveBookResult {
  final String title;
  final bool hasCover;

  SaveBookResultSuccess({required this.title, required this.hasCover});
}

class SaveBookResultAlreadyExists extends SaveBookResult {
  final String title;

  SaveBookResultAlreadyExists({required this.title});
}

class SaveBookResultInvalidFormat extends SaveBookResult {}

class BooksRepository {
  static const supportedExtensions = {'.fb2', '.zip'};

  final _store = stringMapStoreFactory.store('RecentBook');

  Future<void> saveRecent(RecentBook book) async {
    await _store
        .record(book.title)
        .put(SembastProvider.instance, book.toJson());
  }

  Future<String?> deleteRecent(RecentBook book) async {
    return _store.record(book.title).delete(SembastProvider.instance);
  }

  Future<RecentBook?> getRecentByTitle(String bookTitle) async {
    final record = await _store.record(bookTitle).get(SembastProvider.instance);
    return record == null ? null : RecentBook.fromJson(record);
  }

  /// Returns a list of recent books titles
  Future<List<RecentBook>> getAllRecent() => _store
      .stream(SembastProvider.instance)
      .map((snapshot) => RecentBook.fromJson(snapshot.value))
      .toList();

  Future<SaveBookResult> save(String bookPath) async {
    late Uint8List decodedBytes;
    String title = "Название не найдено";
    String name = "Автор не найден";
    BookSequence? sequence;
    List text = [];
    String fileContent = '';

    final bookFile = File(bookPath);
    if (p.extension(bookPath) == '.zip') {
      final tempDir = await getTemporaryDirectory();
      String tempPath = tempDir.path;

      String unzipPath = '$tempPath/unzipped/';
      final unzipDir = Directory(unzipPath);
      await unzipDir.create();

      final extractPath = await _extractFB2FromZip(bookFile, unzipPath);
      if (extractPath.isNotEmpty) {
        try {
          fileContent = await _readFile(File(extractPath));
        } finally {
          await unzipDir.delete(recursive: true);
        }
      } else {
        return SaveBookResultInvalidFormat();
      }
    } else {
      fileContent = await _readFile(bookFile);
    }

    final document = XmlDocument.parse(fileContent);
    try {
      final XmlElement binaryInfo = document.findAllElements('binary').first;
      final String binary = binaryInfo.innerText;
      final String cleanedBinary = binary.replaceAll(RegExp(r"\s+"), "");
      decodedBytes = base64.decode(cleanedBinary);
    } catch (e) {
      decodedBytes = Uint8List.fromList([0]);
    }

    try {
      final XmlElement titleInfo = document.findAllElements('title-info').first;
      final XmlElement titleInfoTag =
          titleInfo.findElements('book-title').first;
      final String titleFromInfo = titleInfoTag.innerText;
      title = titleFromInfo;
    } catch (e) {
      title = "Название не найдено";
    }

    try {
      final XmlElement authorInfo = document.findAllElements('author').first;
      final XmlElement firstNameInfo =
          authorInfo.findElements('first-name').first;
      final String firstNameFromInfo = firstNameInfo.innerText;

      final XmlElement lastNameInfo =
          authorInfo.findElements('last-name').first;
      final String lastNameFromInfo = lastNameInfo.innerText;
      name = '$firstNameFromInfo $lastNameFromInfo';
    } catch (e) {
      name = "Автор не найден";
    }

    try {
      final XmlElement titleInfo = document.findAllElements('title-info').first;
      final sequenceInfo = titleInfo.findElements('sequence').firstOrNull;
      final name = sequenceInfo?.getAttribute('name');
      final number = sequenceInfo?.getAttribute('number');
      if (name != null) {
        sequence = BookSequence(name: name, number: number);
      }
    } catch (e) {
      sequence = null;
    }

    final Iterable<XmlElement> textInfo = document.findAllElements('body');
    for (var element in textInfo) {
      text.add(element.innerText.replaceAll(RegExp(r'\[.*?\]'), ''));
    }

    ImageInfo imageData = ImageInfo(
        imageBytes: decodedBytes,
        title: title,
        author: name,
        fileName: bookPath,
        progress: 0.0);

    BookInfo bookData = BookInfo(
        filePath: bookPath,
        fileText: text.toString(),
        title: title,
        author: name,
        lastPosition: 0,
        sequence: sequence,
        dateAdded: await bookFile.lastModified());
    Book book = Book.combine(bookData, imageData);
    Map<String, dynamic> jsonData = book.toJson();
    final Directory? externalDir = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    final String pathWithJsons = '${externalDir?.path}/books';
    String targetFileName = '$title.json';
    final Directory directory = Directory(pathWithJsons);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final File targetFile = File('${directory.path}/$targetFileName');

    var tempExists = await targetFile.exists();

    if (!await targetFile.exists()) {
      await targetFile.create();
    }

    if (tempExists) {
      return SaveBookResultAlreadyExists(title: title);
    } else {
      await book.saveJsonToFile(jsonData, title);
      return SaveBookResultSuccess(
          title: title, hasCover: decodedBytes.length > 1);
    }
  }

  Future<String> _extractFB2FromZip(File zipFile, String unzipPath) async {
    try {
      List<int> bytes = await zipFile.readAsBytes();

      Archive archive = ZipDecoder().decodeBytes(bytes);

      for (ArchiveFile file in archive) {
        String fileName = file.name;
        if (fileName.toLowerCase().endsWith('.fb2')) {
          String filePath = '$unzipPath$fileName';
          File fb2File = File(filePath);
          fb2File = await fb2File.create(recursive: true);
          await fb2File.writeAsBytes(file.content);
          return filePath;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error extracting FB2 from zip: $e');
      }
    }

    return '';
  }
}

Future<String> _readFile(File bookFile) async =>
    (await CharsetDetector.autoDecode(await (bookFile.readAsBytes()))).string;
