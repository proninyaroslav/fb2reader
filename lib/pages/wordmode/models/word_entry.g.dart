// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WordEntry _$WordEntryFromJson(Map<String, dynamic> json) => WordEntry(
      word: json['word'] as String,
      count: (json['count'] as num).toInt(),
      translation: json['translation'] as String?,
      ipa: json['ipa'] as String?,
    );

Map<String, dynamic> _$WordEntryToJson(WordEntry instance) => <String, dynamic>{
      'word': instance.word,
      'count': instance.count,
      'translation': instance.translation,
      'ipa': instance.ipa,
    };
