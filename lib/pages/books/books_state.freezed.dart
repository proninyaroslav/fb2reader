// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'books_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BooksState {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is BooksState);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'BooksState()';
  }
}

/// @nodoc
class $BooksStateCopyWith<$Res> {
  $BooksStateCopyWith(BooksState _, $Res Function(BooksState) __);
}

/// @nodoc

class BooksStateInitial implements BooksState {
  BooksStateInitial();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is BooksStateInitial);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'BooksState.initial()';
  }
}

/// @nodoc

class BooksStateLoading implements BooksState {
  BooksStateLoading();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is BooksStateLoading);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'BooksState.loading()';
  }
}

/// @nodoc

class BooksStateLoaded implements BooksState {
  BooksStateLoaded(final List<BookItem> books) : _books = books;

  final List<BookItem> _books;
  List<BookItem> get books {
    if (_books is EqualUnmodifiableListView) return _books;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_books);
  }

  /// Create a copy of BooksState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BooksStateLoadedCopyWith<BooksStateLoaded> get copyWith =>
      _$BooksStateLoadedCopyWithImpl<BooksStateLoaded>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BooksStateLoaded &&
            const DeepCollectionEquality().equals(other._books, _books));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_books));

  @override
  String toString() {
    return 'BooksState.loaded(books: $books)';
  }
}

/// @nodoc
abstract mixin class $BooksStateLoadedCopyWith<$Res>
    implements $BooksStateCopyWith<$Res> {
  factory $BooksStateLoadedCopyWith(
          BooksStateLoaded value, $Res Function(BooksStateLoaded) _then) =
      _$BooksStateLoadedCopyWithImpl;
  @useResult
  $Res call({List<BookItem> books});
}

/// @nodoc
class _$BooksStateLoadedCopyWithImpl<$Res>
    implements $BooksStateLoadedCopyWith<$Res> {
  _$BooksStateLoadedCopyWithImpl(this._self, this._then);

  final BooksStateLoaded _self;
  final $Res Function(BooksStateLoaded) _then;

  /// Create a copy of BooksState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? books = null,
  }) {
    return _then(BooksStateLoaded(
      null == books
          ? _self._books
          : books // ignore: cast_nullable_to_non_nullable
              as List<BookItem>,
    ));
  }
}

// dart format on
