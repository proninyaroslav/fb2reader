import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:merlin/functions/book.dart';
import 'package:merlin/pages/books/book_item.dart';
import 'package:merlin/pages/books/books_state.dart';
import 'package:path_provider/path_provider.dart';

class BooksCubit extends Cubit<BooksState> {
  final List<BookItem> _books = [];
  BooksSort _sort = BooksSort.dateAddedDesc;
  String? _searchQuery;

  BooksCubit() : super(BooksState.initial());

  void setSearchQuery(String? value) {
    _searchQuery = value;
  }

  void setSort(BooksSort value) {
    _sort = value;
  }

  Future<void> load({bool force = false}) async {
    if (!force && (state is BooksStateLoading || state is BooksStateLoaded)) {
      return;
    }

    emit(BooksState.loading());

    try {
      final Directory? externalDir = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();
      final String path = '${externalDir?.path}/books';
      final Directory booksDir = Directory(path);

      // Проверяем, существует ли уже директория, если нет - создаем
      if (!await booksDir.exists()) {
        await booksDir.create(recursive: true);
      }

      final newBooks = await compute(_readBooks, path);
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
    if (state is! BooksStateLoaded || state is BooksStateLoading) {
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
    if (state is! BooksStateLoaded || state is BooksStateLoading) {
      return;
    }
    final index = _books.indexOf(item);
    if (index == -1) {
      return;
    }
    try {
      _books[index].delete();
      _books.removeAt(index);
    } catch (e) {
      if (kDebugMode) {
        print('Error delete book: $e');
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

    emit(BooksState.loaded(booksFiltered));
  }

  // Future<void> refresh() async {
  //   if (state is! BooksStateLoaded || state is BooksStateLoading) {
  //     return;
  //   }

  //   try {
  //     await Future.delayed(const Duration(milliseconds: 200));

  //     final Directory? externalDir = Platform.isAndroid
  //         ? await getExternalStorageDirectory()
  //         : await getApplicationDocumentsDirectory();
  //     final String path = '${externalDir?.path}/books';
  //     int length = _books.length;
  //     int index = 0;
  //     List<BookItem> newItems = [];
  //     await for (FileSystemEntity file in Directory(path).list()) {
  //       if (file is File) {
  //         if (index > length) {
  //           final newItem = await compute(_readBookFromFile, file.path);
  //           newItems.add(newItem);
  //         } else {
  //           Map<String, dynamic> jsonMap =
  //               await compute(_decodeBook, file.path);

  //           final book = _books[index];
  //           final newItem = BookItem(
  //               fileSize: book.fileSize,
  //               filePath: book.filePath,
  //               text: book.text,
  //               title: book.title,
  //               customTitle: jsonMap['customTitle'] != book.customTitle
  //                   ? jsonMap['customTitle']
  //                   : book.customTitle,
  //               author: jsonMap['author'] != book.author
  //                   ? jsonMap['author']
  //                   : book.author,
  //               lastPosition: book.lastPosition,
  //               sequence: book.sequence,
  //               imageBytes: book.imageBytes,
  //               progress: jsonMap['progress'] != book.progress
  //                   ? jsonMap['progress']
  //                   : book.progress,
  //               lp: book.lp,
  //               version: book.version,
  //               dateAdded: book.dateAdded);

  //           newItems.add(newItem);
  //         }
  //         index = index + 1;
  //       }
  //     }
  //     _books.clear();
  //     _books.addAll(newItems);
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('Error reading books: $e');
  //     }
  //   } finally {
  //     _filterAndSortBooks();
  //   }
  // }
}

Future<List<BookItem>> _readBooks(String dirPath) async {
  List<Future<BookItem>> futures = [];
  await for (FileSystemEntity file in Directory(dirPath).list()) {
    if (file is File) {
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
