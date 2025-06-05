import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:merlin/domain/books_repository.dart';
import 'package:merlin/functions/book.dart';
import 'package:merlin/functions/recent_book.dart';
import 'package:merlin/pages/books/book_item.dart';
import 'package:merlin/pages/recent/books_recent_state.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LoadBooksMessage {
  final List<RecentBook> recentBooks;
  final String path;

  _LoadBooksMessage({required this.recentBooks, required this.path});
}

class BooksRecentCubit extends Cubit<BooksRecentState> {
  final BooksRepository _booksRepo = BooksRepository();
  final List<BookItem> _books = [];
  BooksSort _sort = BooksSort.dateAddedDesc;
  String? _searchQuery;

  BooksRecentCubit() : super(BooksRecentState.initial());

  void setSearchQuery(String? value) {
    _searchQuery = value;
  }

  void setSort(BooksSort value) {
    _sort = value;
  }

  Future<void> load() async {
    if (state is BooksRecentStateLoading || state is BooksRecentStateLoaded) {
      return;
    }

    emit(BooksRecentState.loading());

    try {
      final recentBooks = await _booksRepo.getAllRecent();

      final Directory? externalDir = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();
      final String path = '${externalDir?.path}/books';
      final Directory booksDir = Directory(path);

      // Проверяем, существует ли уже директория, если нет - создаем
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }

      final newBooks = await compute(
          _readBooks, _LoadBooksMessage(recentBooks: recentBooks, path: path));
      _books.clear();
      _books.addAll(newBooks);
    } catch (e) {
      if (kDebugMode) {
        print('Error reading books: $e');
      }
    } finally {
      filterAndSort();
    }
  }

  Future<void> refreshBook(BookItem item,
      {String? customTitle, String? author, double? progress}) async {
    if (state is! BooksRecentStateLoaded || state is BooksRecentStateLoading) {
      return;
    }

    final index = _books.indexOf(item);
    if (index == -1) {
      return;
    }

    try {
      final book = _books[index];
      final newItem = BookItem(
          fileSize: book.fileSize,
          filePath: book.filePath,
          text: book.text,
          title: book.title,
          customTitle: customTitle ?? book.customTitle,
          author: author ?? book.author,
          lastPosition: book.lastPosition,
          sequence: book.sequence,
          imageBytes: book.imageBytes,
          progress: progress ?? book.progress,
          lp: book.lp,
          version: book.version,
          dateAdded: book.dateAdded);

      _books.removeAt(index);
      _books.add(newItem);
    } catch (e) {
      if (kDebugMode) {
        print('Error update book: $e');
      }
    } finally {
      filterAndSort();
    }
  }

  Future<void> deleteBook(BookItem item) async {
    if (state is! BooksRecentStateLoaded || state is BooksRecentStateLoading) {
      return;
    }
    final index = _books.indexOf(item);
    if (index == -1) {
      return;
    }
    try {
      final title = _books[index].title;
      _books.removeAt(index);
      try {
        final book = await _booksRepo.getRecentByTitle(title);
        if (book != null) {
          await _booksRepo.deleteRecent(book);
        }
      } catch (e) {
        if (kDebugMode) {
          print('Unable to delete recent book: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error delete book: $e');
      }
    } finally {
      filterAndSort();
    }
  }

  Future<void> saveToRecent(BookItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool success = await prefs.setString('fileTitle', item.title);
      if (success == true) {
        await _booksRepo.saveRecent(RecentBook(title: item.title));
      }
      _books.add(item);
    } catch (e) {
      if (kDebugMode) {
        print('Error save book: $e');
      }
    } finally {
      filterAndSort();
    }
  }

  void filterAndSort() {
    final query = _searchQuery?.toLowerCase();
    final booksFiltered =
        _books.where((book) => book.filterByMetadata(query)).toList();
    booksFiltered.sort((a, b) => _sort.sort(a, b));

    emit(BooksRecentState.loaded(booksFiltered));
  }
}

Future<List<BookItem>> _readBooks(_LoadBooksMessage message) async {
  List<Future<BookItem>> futures = [];

  final files = await Directory(message.path).list().toList();

  for (final recent in message.recentBooks) {
    final title = recent.title;
    String fileName = '$title.json';
    FileSystemEntity? file;
    try {
      file = files.firstWhere(
        (file) => file is File && file.uri.pathSegments.last == fileName,
      );
    } catch (e) {
      continue;
    }
    if (file is File && await file.exists()) {
      final futureBook = _readBookFromFile(file.path);
      futures.add(futureBook);
    }
  }

  return Future.wait(futures);
}

Future<BookItem> _readBookFromFile(String path) async {
  try {
    final file = File(path);
    String content = await file.readAsString();
    Map<String, dynamic> jsonMap = jsonDecode(content);
    final book = Book.fromJson(jsonMap);
    return BookItem(
        fileSize: await file.length(),
        filePath: book.filePath,
        text: book.text,
        title: book.title,
        customTitle: book.customTitle,
        author: book.author,
        lastPosition: book.lastPosition,
        sequence: book.sequence,
        imageBytes: book.imageBytes,
        progress: book.progress,
        lp: book.lp,
        version: book.version,
        dateAdded: book.dateAdded);
  } catch (e) {
    if (kDebugMode) {
      print('Error reading file: $e');
    }
    return BookItem(
        fileSize: 0,
        filePath: '',
        text: '',
        title: '',
        author: '',
        lastPosition: 0,
        imageBytes: null,
        progress: 0,
        customTitle: '',
        sequence: null,
        dateAdded: DateTime.fromMillisecondsSinceEpoch(0));
  }
}
