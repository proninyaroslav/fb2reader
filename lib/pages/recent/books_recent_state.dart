import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:merlin/pages/books/book_item.dart';

part 'books_recent_state.freezed.dart';

@freezed
sealed class BooksRecentState with _$BooksRecentState {
  factory BooksRecentState.initial() = BooksRecentStateInitial;

  factory BooksRecentState.loading() = BooksRecentStateLoading;

  factory BooksRecentState.loaded(List<BookItem> books) =
      BooksRecentStateLoaded;
}
