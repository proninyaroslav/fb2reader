import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:json_annotation/json_annotation.dart';
import 'package:merlin/pages/wordmode/models/word_entry.dart';
import 'package:merlin/style/colors.dart';
import 'package:merlin/style/text.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'wordmode.g.dart';

@JsonSerializable(explicitToJson: true)
class WordCount {
  final String filePath;
  final String fileText;
  List<WordEntry> wordEntries;

  WordCount({
    this.filePath = '',
    this.fileText = '',
    this.wordEntries = const [],
  });

  factory WordCount.fromJson(Map<String, dynamic> json) =>
      _$WordCountFromJson(json);

  Map<String, dynamic> toJson() => _$WordCountToJson(this);

  int _callCount = 0;
  DateTime? _lastCallTimestamp;
  List<String> allNouns = [];

  Future<void> updateCallInfo() async {
    final prefs = await SharedPreferences.getInstance();

    _callCount++;
    _lastCallTimestamp = DateTime.now();

    await prefs.setInt('callCount', _callCount);
    await prefs.setString(
        'lastCallTimestamp', _lastCallTimestamp!.toIso8601String());
  }

  Future<void> loadCallInfo() async {
    final prefs = await SharedPreferences.getInstance();

    _callCount = prefs.getInt('callCount') ?? 0;
    final lastCallTimestampStr = prefs.getString('lastCallTimestamp');
    _lastCallTimestamp = lastCallTimestampStr != null
        ? DateTime.parse(lastCallTimestampStr)
        : null;
  }

  Future<String> translateToEnglish(String word) async {
    final response = await http.get(Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=ru&tl=en&dt=t&q=$word'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.length >= 1 && data[0].length >= 1 && data[0][0].length >= 3) {
        return data[0][0][0]
            .toString()
            .replaceAll(RegExp(r'[\[\].,;!?():]'), '')
            .toLowerCase();
      } else {
        return 'Translation not available';
      }
    } else {
      return 'N/A';
    }
  }

  Future<String> getPartOfSpeech(String word) async {
    final apiUrl = 'https://www.merriam-webster.com/dictionary/$word';
    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final document = parse(response.body);
      final partOfSpeechElement = document.querySelector('.parts-of-speech a');
      if (partOfSpeechElement != null) {
        final partOfSpeech = partOfSpeechElement.text;
        return partOfSpeech;
      }
    }
    // debugPrint('Не удалось определить часть речи $word');
    return 'N/A';
  }

  Future<String> getIPA(String word) async {
    final apiUrl = 'https://www.merriam-webster.com/dictionary/$word';
    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final document = parse(response.body);
      final ipaElement = document.querySelector('.play-pron-v2');
      if (ipaElement != null) {
        final ipaText = ipaElement.text.replaceAll('\n', '').trim();
        return ipaText;
      }
    }
    // debugPrint('Не удалось получить IPA произношения $word');
    return 'N/A';
  }

  Future<void> checkCallInfo(bool confirm) async {
    await loadCallInfo();

    if (_lastCallTimestamp != null) {
      final now = DateTime.now();
      final timeElapsed = now.difference(_lastCallTimestamp!);

      await countWordsWithOffset();
      await updateCallInfo();
      // TODO: пока убрано
      // Проверяем, прошло ли более 24 часов с момента последнего вызова
      // if (timeElapsed.inHours >= 24) { // TODO
      //   // if (timeElapsed.inMicroseconds >= 1) {
      //   await countWordsWithOffset();

      //   await updateCallInfo();
      // } else {
      //   Fluttertoast.showToast(
      //     msg: 'Можно только раз в 24 часа!',
      //     toastLength: Toast.LENGTH_SHORT, // Длительность отображения
      //     gravity: ToastGravity.BOTTOM, // Расположение уведомления
      //   );
      //   return;
      // }
    } else {
      await countWordsWithOffset();
      await updateCallInfo();
    }
  }

  Future<Map<String, int>> getAllWordCounts() async {
    final textWithoutPunctuation =
        fileText.replaceAll(RegExp(r'[.,;!?():]'), '');
    final words = textWithoutPunctuation.split(RegExp(r'\s+'));

    final wordCounts = <String, int>{};

    for (final word in words) {
      final normalizedWord = word.toLowerCase();
      if (normalizedWord.length > 1 &&
          !RegExp(r'[0-9]').hasMatch(normalizedWord) &&
          normalizedWord != '-') {
        if (wordCounts.containsKey(normalizedWord)) {
          wordCounts[normalizedWord] = (wordCounts[normalizedWord] ?? 0) + 1;
        } else {
          wordCounts[normalizedWord] = 1;
        }
      }
    }

    return wordCounts;
  }

  Future<List<String>> getAllWords() async {
    final textWithoutPunctuation =
        fileText.replaceAll(RegExp(r'[.,;!?():"\\"]'), '');
    final words = textWithoutPunctuation.split(RegExp(r'\s+'));

    List<String> wordCounts = [];

    for (final word in words) {
      final normalizedWord = word.toLowerCase();
      if (normalizedWord.length > 1 &&
          !RegExp(r'[0-9]').hasMatch(normalizedWord) &&
          normalizedWord != '-') {
        wordCounts.add(normalizedWord);
      }
    }
    return wordCounts;
  }

  int getWordCount(String wordToCount) {
    final textWithoutPunctuation =
        fileText.replaceAll(RegExp(r'[.,;!?():]'), '');
    final words = textWithoutPunctuation.split(RegExp(r'\s+'));

    final wordCounts = <String, int>{};

    for (final word in words) {
      final normalizedWord = word.toLowerCase();
      if (normalizedWord.length > 1 &&
          !RegExp(r'[0-9]').hasMatch(normalizedWord) &&
          normalizedWord != '-') {
        if (wordCounts.containsKey(normalizedWord)) {
          wordCounts[normalizedWord] = (wordCounts[normalizedWord] ?? 0) + 1;
        } else {
          wordCounts[normalizedWord] = 1;
        }
      }
    }

    // Возвращаем количество повторений слова, если оно существует, иначе 0
    return wordCounts[wordToCount.toLowerCase()] ?? 0;
  }

  // Future<void> countWordsWithOffset(int offset) async {
  //   final textWithoutPunctuation =
  //       fileText.replaceAll(RegExp(r'[.,;!?():]'), '');
  //   final words = textWithoutPunctuation.split(RegExp(r'\s+'));

  //   final wordCounts = <String, int>{};

  //   for (final word in words) {
  //     final normalizedWord = word.toLowerCase();
  //     if (normalizedWord.length > 3 &&
  //         !RegExp(r'[0-9]').hasMatch(normalizedWord) &&
  //         normalizedWord != '-') {
  //       if (wordCounts.containsKey(normalizedWord)) {
  //         wordCounts[normalizedWord] = (wordCounts[normalizedWord] ?? 0) + 1;
  //       } else {
  //         wordCounts[normalizedWord] = 1;
  //       }
  //     }
  //   }

  //   final sortedWordCounts = wordCounts.entries.toList()
  //     ..sort((a, b) => b.value.compareTo(a.value));

  //   final start = offset * 10;
  //   var end = (offset + 1) * 10;

  //   // Убедимся, что конец в пределах допустимого
  //   if (end > sortedWordCounts.length) {
  //     end = sortedWordCounts.length;
  //   }

  //   // Создаем список WordEntry с переводом и транскрипцией
  //   final wordEntries = <WordEntry>[];
  //   for (var i = start; i < end; i++) {
  //     final entry = sortedWordCounts[i];
  //     final word = entry.key;
  //     final count = entry.value;
  //     final translation = await translateToEnglish(word);
  //     final ipaWord = await getIPA(translation);
  //     // final partOfSpeechWord = await getPartOfSpeech(translation);
  //     debugPrint('"$word" - "$translation" - [$ipaWord]');

  //     wordEntries.add(WordEntry(
  //       word: word,
  //       count: count,
  //       translation: translation,
  //       ipa: ipaWord,
  //     ));
  //   }

  //   // Присваиваем wordEntries к текущим wordEntries
  //   this.wordEntries = wordEntries;
  // }

  Future<List<String>> getNounsByList(List<String> inputWords) async {
    // debugPrint('getNounsByList inputWords $inputWords');
    String url = 'https://app.merlin.su/account/words/nouns';
    var response = await http.post(
      Uri.parse(url),
      headers: {
        "User-Agent": "Merlin/1.0",
        'accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(
          {'words': inputWords}), // Преобразуйте объект в JSON-строку
    );
    // debugPrint('getNounsByList response ${response.body}');
    if (response.statusCode == 200) {
      Map<String, dynamic> responseData = json.decode(response.body);
      List<String> nouns = List<String>.from(responseData['words']);
      return nouns;
    } else {
      throw Exception('Failed to load nouns');
    }
  }

  Future<List<String>> getAllNouns() async {
    final words = await getAllWords();
    // debugPrint('words = $words');
    // debugPrint('words.length = ${words.length}');
    String url = 'https://app.merlin.su/account/words/nouns';

    var response = await http.post(
      Uri.parse(url),
      headers: {
        "User-Agent": "Merlin/1.0",
        'accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'words': words}), // Преобразуйте объект в JSON-строку
    );
    // debugPrint('------');
    // debugPrint(response.body);

    if (response.statusCode == 200) {
      // Преобразование ответа в Map<String, dynamic>
      Map<String, dynamic> responseData = json.decode(response.body);
      // Получение списка существительных из ключа "words"
      List<String> nouns = List<String>.from(responseData['words']);
      // debugPrint('\tnouns = $nouns');
      return nouns;
    } else {
      // Обработка ошибки, например, вывод сообщения об ошибке
      throw Exception('Failed to load nouns');
    }
  }

  Future<WordCount> loadWordCountFromLocalStorage(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    // String? storedData = prefs.getString('$filePath-words');
    String key = 'WMWORDS';

    String? storedData = prefs.getString(key);
    if (storedData != null) {
      List<dynamic> decodedData = jsonDecode(storedData);
      WordCount wordCount = WordCount.fromJson(decodedData[0]);
      return wordCount;
    } else {
      return WordCount();
    }
  }

  Future<void> countWordsWithOffset() async {
    final wordCounts = await getAllWordCounts();
    final sortedWordCounts = wordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final prefs = await SharedPreferences.getInstance();
    int getWords = prefs.getInt('words') ?? 10;
    // print('countWordsWithOffset $getWords');
    int start = prefs.getInt('$filePath-end') ?? 0;
    int end = start + getWords;
    end = min(end, sortedWordCounts.length);

    // debugPrint('getWords = $getWords');
    // debugPrint('start = $start');
    // debugPrint('end = $end');
    // debugPrint('end - start = ${end - start}');
    /// debugPrint('sortedWordCounts.length = ${sortedWordCounts.length}');

    // Загрузка исторических слов
    String historyKey = 'WMWORDS_HISTORY';
    String? historyData = prefs.getString(historyKey);
    List<String> historyWords =
        historyData != null ? List<String>.from(jsonDecode(historyData)) : [];

    List<String> checkWords = [];
    int currentIndex = start;

    while (checkWords.length < end - start &&
        currentIndex < sortedWordCounts.length) {
      List<String> newWords = [];

      for (;
          currentIndex < sortedWordCounts.length &&
              newWords.length < (end - start - checkWords.length);
          currentIndex++) {
        var currentWord = sortedWordCounts[currentIndex].key;
        if (!historyWords.contains(currentWord)) {
          newWords.add(currentWord);
        }
      }

      List<String> newNouns = await getNounsByList(newWords);
      checkWords.addAll(newNouns);

      // Если новых существительных нет, и все слова были проверены, прерываем цикл
      if (newNouns.isEmpty && currentIndex >= sortedWordCounts.length) {
        break;
      }
    }

    checkWords = checkWords.sublist(0,
        min(checkWords.length, end - start)); // Обрезаем список до нужной длины

    final wordEntriesFutures = <Future<WordEntry>>[];
    for (var word in checkWords) {
      var correspondingEntry = sortedWordCounts.firstWhere(
        (entry) => entry.key == word,
        orElse: () => const MapEntry<String, int>("NotFound", -1),
      );

      if (correspondingEntry.key != "NotFound") {
        wordEntriesFutures.add(createWordEntry(word, correspondingEntry.value));
        historyWords.add(word); // Добавление слова в историю
      } else {
        // debugPrint("No matching entry for word: $word");
      }
    }

    final wordEntries = await Future.wait(wordEntriesFutures);

    prefs.setInt('$filePath-end', min(end, sortedWordCounts.length));
    prefs.setInt('words', 10);
    this.wordEntries =
        wordEntries; // Присваиваем wordEntries к текущим wordEntries

    // Сохранение обновленной истории слов
    prefs.setString(historyKey, jsonEncode(historyWords));
  }

  Future<void> countWordsWithOffsetNoTrans() async {
    final textWithoutPunctuation =
        fileText.replaceAll(RegExp(r'[.,;!?():]'), '');
    final words = textWithoutPunctuation.split(RegExp(r'\s+'));

    final wordCounts = <String, int>{};

    for (final word in words) {
      final normalizedWord = word.toLowerCase();
      if (normalizedWord.length > 3 &&
          !RegExp(r'[0-9]').hasMatch(normalizedWord) &&
          normalizedWord != '-') {
        if (wordCounts.containsKey(normalizedWord)) {
          wordCounts[normalizedWord] = (wordCounts[normalizedWord] ?? 0) + 1;
        } else {
          wordCounts[normalizedWord] = 1;
        }
      }
    }

    final sortedWordCounts = wordCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final prefs = await SharedPreferences.getInstance();
    int getWords = prefs.getInt('words') ?? 10;
    int start = prefs.getInt('$filePath-end') ?? 0;
    int end = prefs.getInt('$filePath-end') ?? getWords;

    // debugPrint('getWords = $getWords');

    // Убедимся, что конец в пределах допустимого
    end = end + getWords;
    end = min(end, sortedWordCounts.length);

    // debugPrint('start = $start');
    // debugPrint('end = $end');
    // debugPrint('end - start = ${end - start}');

    // debugPrint('sortedWordCounts.length = ${sortedWordCounts.length}');
    List<WordEntry> wordEntries = [];
    for (var i = start; i < end; i++) {
      final entry = sortedWordCounts[i];

      wordEntries.add(WordEntry(word: entry.key, count: entry.value));
    }
    // prefs.setInt('$filePath-start', start);
    prefs.setInt('$filePath-end', end);
    // prefs.setInt('words', 10);
    // Присваиваем wordEntries к текущим wordEntries
    this.wordEntries = wordEntries;
  }

  Future<WordEntry> createWordEntry(String word, int count) async {
    final translation = await translateToEnglish(word);
    final ipaWord = await getIPA(translation);
    // final partOfSpeechWord = await getPartOfSpeech(translation);
    // debugPrint('"$word" - "$translation" - [$ipaWord]');

    return WordEntry(
      word: word,
      count: count,
      translation: translation,
      ipa: ipaWord,
      // partOfSpeech: partOfSpeechWord, // Uncomment if needed
    );
  }

  Future<List<WordEntry>> processSingleWord(
      String newWord, List<WordEntry> wordEntries) async {
    final normalizedWord = newWord.toLowerCase();

    // Check conditions for the word
    final count = getWordCount(normalizedWord);

    // Placeholder functions - replace with your actual implementations
    final translation = await translateToEnglish(normalizedWord);
    final ipaWord = await getIPA(translation);

    // Create a new WordEntry based on processed information
    final newWordEntry = WordEntry(
      word: normalizedWord,
      count: count,
      translation: translation,
      ipa: ipaWord,
    );

    // Make sure the list is modifiable
    List<WordEntry> modifiableWordEntries =
        List<WordEntry>.of(wordEntries, growable: true);

    // Add the new WordEntry to the list
    modifiableWordEntries.add(newWordEntry);

    return modifiableWordEntries;
  }

  // Метод чтобы сбросить счётчик 24 часов
  Future<void> resetCallCount() async {
    _callCount = 0;
    _lastCallTimestamp = null;
    final prefs = await SharedPreferences.getInstance();

    prefs.setInt('callCount', _callCount);

    prefs.setInt('$filePath-end', 0);
    prefs.setInt('words', 10);
    prefs.remove('lastCallTimestamp');
  }
}

class AgreementDialog extends StatelessWidget {
  final int getWords;

  const AgreementDialog({super.key, required this.getWords});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          Navigator.of(context).pop();
        },
        behavior: HitTestBehavior.opaque,
        child: AlertDialog(
          contentPadding: EdgeInsets.zero,
          buttonPadding: EdgeInsets.zero,
          content: Container(
            height: 70,
            alignment: Alignment.center,
            child: Text(
              'Хотите выбрать $getWords слов?',
              style: const TextStyle(fontFamily: 'Tektur', fontSize: 18),
            ),
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Container(
                  decoration: BoxDecoration(
                    border: !Platform.isIOS
                        ? Border.all(
                            color: Colors.black,
                            width: 0.2,
                          )
                        : null,
                  ),
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    child: const Text18(
                      text: 'Да',
                      textColor: MyColors.black,
                    ),
                  ),
                )),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: !Platform.isIOS
                          ? Border.all(
                              color: Colors.black,
                              width: 0.2,
                            )
                          : null,
                    ),
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                      child: const Text(
                        'Нет',
                        style: TextStyle(
                            fontSize: 18,
                            color: Colors.red,
                            fontFamily: 'Tektur'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ));
  }
}
