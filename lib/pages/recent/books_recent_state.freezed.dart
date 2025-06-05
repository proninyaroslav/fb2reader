// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'books_recent_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BooksRecentState {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is BooksRecentState);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'BooksRecentState()';
  }
}

/// @nodoc
class $BooksRecentStateCopyWith<$Res> {
  $BooksRecentStateCopyWith(
      BooksRecentState _, $Res Function(BooksRecentState) __);
}

/// @nodoc

class BooksRecentStateInitial implements BooksRecentState {
  BooksRecentStateInitial();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is BooksRecentStateInitial);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'BooksRecentState.initial()';
  }
}

/// @nodoc

class BooksRecentStateLoading implements BooksRecentState {
  BooksRecentStateLoading();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is BooksRecentStateLoading);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'BooksRecentState.loading()';
  }
}

/// @nodoc

class BooksRecentStateLoaded implements BooksRecentState {
  BooksRecentStateLoaded(final List<BookItem> books) : _books = books;

  final List<BookItem> _books;
  List<BookItem> get books {
    if (_books is EqualUnmodifiableListView) return _books;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_books);
  }

  /// Create a copy of BooksRecentState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BooksRecentStateLoadedCopyWith<BooksRecentStateLoaded> get copyWith =>
      _$BooksRecentStateLoadedCopyWithImpl<BooksRecentStateLoaded>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BooksRecentStateLoaded &&
            const DeepCollectionEquality().equals(other._books, _books));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_books));

  @override
  String toString() {
    return 'BooksRecentState.loaded(books: $books)';
  }
}

/// @nodoc
abstract mixin class $BooksRecentStateLoadedCopyWith<$Res>
    implements $BooksRecentStateCopyWith<$Res> {
  factory $BooksRecentStateLoadedCopyWith(BooksRecentStateLoaded value,
          $Res Function(BooksRecentStateLoaded) _then) =
      _$BooksRecentStateLoadedCopyWithImpl;
  @useResult
  $Res call({List<BookItem> books});
}

/// @nodoc
class _$BooksRecentStateLoadedCopyWithImpl<$Res>
    implements $BooksRecentStateLoadedCopyWith<$Res> {
  _$BooksRecentStateLoadedCopyWithImpl(this._self, this._then);

  final BooksRecentStateLoaded _self;
  final $Res Function(BooksRecentStateLoaded) _then;

  /// Create a copy of BooksRecentState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? books = null,
  }) {
    return _then(BooksRecentStateLoaded(
      null == books
          ? _self._books
          : books // ignore: cast_nullable_to_non_nullable
              as List<BookItem>,
    ));
  }
}

// dart format on
