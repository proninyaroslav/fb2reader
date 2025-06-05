// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wordmode.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WordCount _$WordCountFromJson(Map<String, dynamic> json) => WordCount(
      filePath: json['filePath'] as String? ?? '',
      fileText: json['fileText'] as String? ?? '',
      wordEntries: (json['wordEntries'] as List<dynamic>?)
              ?.map((e) => WordEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    )..allNouns =
        (json['allNouns'] as List<dynamic>).map((e) => e as String).toList();

Map<String, dynamic> _$WordCountToJson(WordCount instance) => <String, dynamic>{
      'filePath': instance.filePath,
      'fileText': instance.fileText,
      'wordEntries': instance.wordEntries.map((e) => e.toJson()).toList(),
      'allNouns': instance.allNouns,
    };
