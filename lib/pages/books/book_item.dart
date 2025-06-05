import 'package:equatable/equatable.dart';
import 'package:merlin/functions/book.dart';

class BookItem extends Book with EquatableMixin {
  final int fileSize;

  // TODO: change if support for other formats is planned
  String get bookTypeName => "FB2";

  BookItem(
      {required this.fileSize,
      required super.filePath,
      required super.text,
      required super.title,
      required super.customTitle,
      required super.author,
      required super.lastPosition,
      required super.sequence,
      required super.dateAdded,
      super.imageBytes,
      super.progress,
      super.lp,
      super.version = 0});

  @override
  List<Object?> get props => [
        fileSize,
        filePath,
        title,
        customTitle,
        author,
        lastPosition,
        sequence,
        dateAdded,
        progress,
        lp
      ];
}
