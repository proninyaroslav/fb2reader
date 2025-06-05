import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:merlin/pages/books/book_item.dart';

part 'books_state.freezed.dart';

@freezed
sealed class BooksState with _$BooksState {
  factory BooksState.initial() = BooksStateInitial;

  factory BooksState.loading() = BooksStateLoading;

  factory BooksState.loaded(List<BookItem> books) = BooksStateLoaded;
}
