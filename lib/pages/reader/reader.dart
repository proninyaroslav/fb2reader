// ignore_for_file: use_build_context_synchronously, sized_box_for_whitespace

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screen_wake/flutter_screen_wake.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:merlin/UI/icon/custom_icon.dart';
import 'package:merlin/UI/router.dart';
import 'package:merlin/UI/theme/theme.dart';
import 'package:merlin/domain/data_providers/color_provider.dart';
import 'package:merlin/functions/book.dart';
import 'package:merlin/functions/post_statistic.dart';
import 'package:merlin/main.dart';
import 'package:merlin/pages/reader/custom_showcase.dart';
import 'package:merlin/pages/wordmode/models/word_entry.dart';
import 'package:merlin/pages/wordmode/wordmode.dart';
import 'package:merlin/style/colors.dart';
import 'package:merlin/style/text.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

GlobalKey _showcaseKey = GlobalKey<CustomShowcaseState>();

class LastPosition {
  double offset;
  int paragraph;

  LastPosition({required this.offset, required this.paragraph});

  Map<String, dynamic> toJson() {
    return {
      'offset': offset,
      'paragraph': paragraph,
    };
  }

  factory LastPosition.fromJson(Map<String, dynamic> json) {
    return LastPosition(
      offset: json['offset'],
      paragraph: json['paragraph'],
    );
  }
}

class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, String? fileTitle});

  @override
  Reader createState() => Reader();
}

class Reader extends State with WidgetsBindingObserver {
  late Timer timer;
  Book book = Book(
      filePath: "filePath",
      text: "text",
      title: "title",
      customTitle: "customTitle",
      author: "author",
      progress: 0,
      lastPosition: 0,
      sequence: null,
      dateAdded: DateTime.fromMillisecondsSinceEpoch(0));
  bool loading = true;
  double fontSize = 18;
  bool isDarkTheme = false;
  bool visible = false;
  int _batteryLevel = 0;

  List<DeviceOrientation> orientations = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeRight,
  ];
  int currentOrientationIndex = 0;
  Timer? _actionTimer;
  bool isBorder = false;
  bool? isTrans = false;
  final Battery _battery = Battery();

  double pageSize = 0;
  double pageCount = 0;

  double lastPageCount = 0;

  double percentage = 0;

  List<String> translatedText = List.empty();

  BuildContext? myContext;
  double vFontSize = 18.0;
  double lineHeight = 25;

  double brigtness = 1;

  List<String> text = List.empty();
  List<int> pref = List.empty();

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final ScrollOffsetController _scrollOffsetController =
      ScrollOffsetController();
  final ScrollOffsetListener _scrollOffsetListener =
      ScrollOffsetListener.create();

  double height = 100;
  int? textPosOld;
  int? textPosOldIndex;
  double curr = 0;
  double width = 100;
  Timer? textTimer;

  double baseline = 20.092498779296875;

  late Timer perTimer;

  double oldFs = 18;

  double position(double height) {
    return (_itemPositionsListener
                .itemPositions.value.firstOrNull?.itemLeadingEdge
                .abs() ??
            0) *
        height;
  }

  double positionDown(double height) {
    return (_itemPositionsListener
                .itemPositions.value.firstOrNull?.itemTrailingEdge
                .abs() ??
            0) *
        height;
  }

  int? paragraph() {
    return _itemPositionsListener.itemPositions.value.firstOrNull?.index;
  }

  @override
  void initState() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _getBatteryLevel();
    WidgetsBinding.instance.addObserver(this);

    _scrollOffsetListener.changes.listen((event) {
      curr = event;
    });

    super.initState();
    loadStylePreferences();
    _initPage();

    perTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        percentage =
            ((_itemPositionsListener.itemPositions.value.firstOrNull?.index ??
                            0) /
                        text.length) *
                    100 +
                position(height) / 5000;
      });
    });

    FlutterScreenWake.brightness.then((value) {
      brigtness = value;
      timer = Timer.periodic(const Duration(milliseconds: 100), (Timer t) {
        FlutterScreenWake.setBrightness(brigtness);
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Future.delayed(const Duration(milliseconds: 300), () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool("hi", false);

        //await firstRunReset();
        while (!loading) {
          lastPageCount = prefs.getDouble('pageCount-${book.filePath}') ?? 0;
          // print('READER lastpagecount $lastPageCount');
          prefs.setDouble('lastPageCount-${book.filePath}', lastPageCount);
          pageSize = MediaQuery.of(context).size.height;
          await saveDateTime(pageSize);

          Future.delayed(const Duration(milliseconds: 100), () {
            if (book.version == 2) {
              _itemScrollController.jumpTo(index: book.lp!.paragraph);
              WidgetsBinding.instance.addPostFrameCallback((timeStamp) =>
                  _scrollOffsetController.animateScroll(
                      offset: book.lp!.offset,
                      duration: const Duration(microseconds: 1)));
            }
          });

          _loadPageCountFromLocalStorage();
          if (book.text.isNotEmpty) {
            break;
          }
        }
        if (prefs.getBool('readerShowcase') != true) {
          (_showcaseKey.currentState as CustomShowcaseState?)
              ?.showSlides([const FirstSlide(), const SecondSlide()]);
          prefs.setBool('readerShowcase', true);
        }
      });
    });

    sub = _battery.onBatteryStateChanged.listen((event) {
      _getBatteryLevel();
    });
  }

  @override
  Future<void> dispose() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([orientations[0]]);
    timer.cancel();
    perTimer.cancel();
    sub.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      await _savePageCountToLocalStorage();
      getPageCount(book.title, isBorder);
      update();
      final prefs = await SharedPreferences.getInstance();
      lastPageCount = prefs.getDouble('pageCount-${book.filePath}') ?? 0;
      prefs.setDouble('lastPageCount-${book.filePath}', lastPageCount);
    }
  }

  Future<void> update() async {
    await book.updateStageInFile((paragraph()?.toDouble() ?? 0) / text.length,
        position(height), paragraph() ?? 0);
  }

  Future<void> disposeBook() async {
    await update();
  }

  Future<void> _initPage() async {
    await initBook();
  }

  Future<void> initBook() async {
    final prefs = await SharedPreferences.getInstance();
    String? fileTitle = prefs.getString('fileTitle');
    final Directory? externalDir = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    final String path = '${externalDir?.path}/books/';
    if (fileTitle != null) {
      List<FileSystemEntity> files = Directory(path).listSync();
      // print(path);
      String targetFileName = '$fileTitle.json';
      FileSystemEntity? targetFile;

      try {
        targetFile = files.firstWhere(
          (file) =>
              file is File && file.uri.pathSegments.last == targetFileName,
        );
      } catch (e) {
        Navigator.pop(context);
        Fluttertoast.showToast(
          msg: 'Файл не найден',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        Navigator.of(context).pop();
        return;
      }

      try {
        String content = await (targetFile as File).readAsString();
        Map<String, dynamic> jsonMap = jsonDecode(content);
        book = Book.fromJson(jsonMap);
        text = book.text
            .replaceAll(RegExp(r'\['), '')
            .replaceAll(RegExp(r'\]'), '')
            .split("\n");
        pref = List.filled(text.length + 1, 0);
        for (int i = 1; i < text.length; i++) {
          pref[i] = pref[i - 1] + text[i - 1].length;
        }

        loading = false;
        setState(() {});
        Future.delayed(const Duration(seconds: 1), () {
          if (book.version != 2) {
            _scrollOffsetController.animateScroll(
                offset: book.lastPosition ?? 0,
                duration: const Duration(microseconds: 1));
            // book.version = 2;
          }
        });
      } catch (e) {
        print('Error reading file: $e');
        Navigator.pop(context);
        Fluttertoast.showToast(
          msg: 'Ошибка чтения файла',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        targetFile.delete();
      }
      // print('Длина текста книги = ${book.text.replaceAll(RegExp(r'\['), '').replaceAll(RegExp(r'\]'), '').length}');
    }
  }

  void _getBatteryLevel() async {
    final batteryLevel = await _battery.batteryLevel;
    setState(() {
      _batteryLevel = batteryLevel;
    });
  }

  Future<void> saveDateTime(double pageSize) async {
    final prefs = await SharedPreferences.getInstance();
    DateTime currentTime = DateTime.now();
    prefs.setString('savedDateTime', currentTime.toIso8601String());
    prefs.setDouble('pageSize', pageSize);
  }

  Future<void> _loadPageCountFromLocalStorage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    pageCount = (prefs.getDouble('pageCount-${book.filePath}') ?? 0.0);
  }

  Future<void> _savePageCountToLocalStorage() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // print("Сохраняем pageCount $pageCount");
    Codec<String, String> stringToBase64 = utf8.fuse(base64);
    prefs.setDouble(
        'pageCount-${stringToBase64.encode(book.filePath)}',
        (pref[_itemPositionsListener.itemPositions.value.firstOrNull?.index ??
                0] /
            1860));
    // print("Сохраняем pageCount ${pageResult.round()}");
  }

  Color textColor = MyColors.black;
  Color backgroundColor = MyColors.white;
  final ColorProvider _colorProvider = ColorProvider();

  Future<void> loadStylePreferences() async {
    final backgroundColorFromStorage =
        await _colorProvider.getColor(ColorKeys.readerBackgroundColor);
    final textColorFromStorage =
        await _colorProvider.getColor(ColorKeys.readerTextColor);
    final prefs = await SharedPreferences.getInstance();

    final fontSizeFromStorage = prefs.getDouble('fontSize');
    setState(() {
      if (backgroundColorFromStorage != null) {
        backgroundColor = backgroundColorFromStorage;
      }
      if (textColorFromStorage != null) {
        textColor = textColorFromStorage;
      }
      if (fontSizeFromStorage != null) {
        fontSize = vFontSize = fontSizeFromStorage;
        final tp = TextPainter(
          text: TextSpan(
              text: 'abcde',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: fontSize,
                  height: 1.41,
                  locale: const Locale('ru', 'RU'))),
          textAlign: TextAlign.left,
          textDirection: ui.TextDirection.ltr,
        )..layout(maxWidth: 1000);
        lineHeight = tp.preferredLineHeight;
        baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      }
    });
  }

  bool forTable = false;

  late StreamSubscription<BatteryState> sub;

  Future<void> switchOrientation() async {
    final frst = _itemPositionsListener.itemPositions.value.first.index;
    final tp = TextPainter(
      text: TextSpan(
          text: isBorder ? translatedText[frst] : text[frst],
          style: TextStyle(
              color: Colors.black,
              fontSize: fontSize,
              height: 1.41,
              locale: const Locale('ru', 'RU'))),
      textAlign: TextAlign.left,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: width);
    textPosOld = tp.getPositionForOffset(Offset(0, position(height))).offset;
    textPosOldIndex = frst;

    currentOrientationIndex =
        (currentOrientationIndex + 1) % orientations.length;
    SystemChrome.setPreferredOrientations(
        [orientations[currentOrientationIndex]]);
    if (orientations[currentOrientationIndex] ==
            DeviceOrientation.landscapeLeft ||
        orientations[currentOrientationIndex] ==
            DeviceOrientation.landscapeRight) {
      forTable = true;
    } else {
      forTable = false;
    }

    await Future.delayed(const Duration(milliseconds: 200));

    tp.layout(maxWidth: width);
    lineHeight = tp.preferredLineHeight;
    baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);

    final off = tp
        .getBoxesForSelection(TextSelection(
            baseOffset: textPosOld!, extentOffset: textPosOld! + 1))[0]
        .top;
    _itemScrollController.jumpTo(index: textPosOldIndex!);
    if (off > 0.001) {
      WidgetsBinding.instance.addPostFrameCallback((time) {
        _scrollOffsetController.animateScroll(
            offset: off, duration: const Duration(milliseconds: 1));
      });
    }
    setState(() {});
  }

  Future<void> saveSettings(bool isDarkTheme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', isDarkTheme);
  }

  void replaceWordsWithTranslation(List<WordEntry> wordEntries) async {
    final prefs = await SharedPreferences.getInstance();
    await _savePageCountToLocalStorage();
    getPageCount(book.title, isBorder);
    update();
    lastPageCount = prefs.getDouble('pageCount-${book.filePath}') ?? 0;
    prefs.setDouble('lastPageCount-${book.filePath}', lastPageCount);

    prefs.setBool('${book.filePath}-isTrans', true);
    isBorder = true;
    var tt =
        book.text.replaceAll(RegExp(r'\['), '').replaceAll(RegExp(r'\]'), '');

    for (var entry in wordEntries) {
      var escapedWord = RegExp.escape(entry.word);
      var pattern = '(?<!\\p{L})$escapedWord(?!\\p{L})';
      var wordRegExp = RegExp(pattern, caseSensitive: false, unicode: true);

      tt = tt.replaceAllMapped(wordRegExp, (match) {
        final matchedWord = match.group(0)!;
        return matchCase(matchedWord, entry.translation ?? '');
      });
    }

    translatedText = tt.split("\n");
    pref = List.filled(translatedText.length - 1, 0);
    for (int i = 1; i < translatedText.length - 1; i++) {
      pref[i] = pref[i - 1] + translatedText[i - 1].length;
    }

    await prefs.setString(
        'lastCallTranslate', DateTime.now().toIso8601String());
    isTrans = prefs.getBool('${book.filePath}-isTrans');
    setState(() {
      isTrans;
    });
  }

  String matchCase(String source, String pattern) {
    // print('source $source');
    // print('pattern $pattern');
    // Сохраняем регистр первой буквы исходного слова
    if (source[0] == source[0].toUpperCase()) {
      // print('большая буква');
      return pattern[0].toUpperCase() + pattern.substring(1).toLowerCase();
    }
    // Если весь текст в верхнем регистре - перевод тоже
    if (source.toUpperCase() == source) {
      // print('Если весь текст в верхнем регистре - перевод тоже');
      return pattern.toUpperCase();
    }
    // Иначе возвращаем перевод в нижнем регистре
    // print('Иначе возвращаем перевод в нижнем регистре');
    return pattern.toLowerCase();
  }

  // ИЗМЕНИТЬ НА SECURE STORAGE
  Future<WordCount> loadWordCountFromLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    String key = 'WMWORDS';
    String? storedData = prefs.getString(key);
    if (storedData != null) {
      Map<String, dynamic> decodedData = jsonDecode(storedData);
      WordCount wordCount = WordCount.fromJson(decodedData);
      return wordCount;
    } else {
      return WordCount();
    }
  }

  Future<void> saveWordCountToLocalstorage(WordCount wordCount) async {
    final prefs = await SharedPreferences.getInstance();
    String key = 'WMWORDS';

    // Сериализация WordCount в JSON и сохранение.
    String wordCountString = jsonEncode(wordCount.toJson());
    await prefs.setString(key, wordCountString);
  }

  String detectLanguage({required String string}) {
    String languageCode = '';
    final RegExp english = RegExp(r'^[a-zA-Z]+');
    final RegExp ukrainian = RegExp(r'^[ҐЄІЇґєії]+', caseSensitive: false);
    final RegExp kazakh =
        RegExp(r'^[ҰүҮәӘіІһҺңҢқҚөӨөғҒұҰ]+', caseSensitive: false);
    final RegExp belarusian = RegExp(r'^[ЎўІі]+', caseSensitive: false);
    // final RegExp russian = RegExp(r'^[\u0400-\u04FF]+');
    final RegExp russian = RegExp(r'^[а-яА-Я]+');

    if (english.hasMatch(string)) languageCode = 'en';
    if (ukrainian.hasMatch(string)) languageCode = 'uk';
    if (kazakh.hasMatch(string)) languageCode = 'kz';
    if (belarusian.hasMatch(string)) languageCode = 'br';
    if (russian.hasMatch(string)) languageCode = 'ru';

    return languageCode;
  }

  void wordModeDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    int getWords = prefs.getInt('words') ?? 10;
    // print('wordModeDialog $getWords');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AgreementDialog(
        getWords: getWords,
      ),
    );

    var code = detectLanguage(string: book.title);
    // print(code);

    if (code == 'ru') {
      if (result == true) {
        await _savePageCountToLocalStorage();
        getPageCount(book.title, isBorder);
        update();

        final prefs = await SharedPreferences.getInstance();

        lastPageCount = prefs.getDouble('pageCount-${book.filePath}') ?? 0;
        prefs.setDouble('lastPageCount-${book.filePath}', lastPageCount);
        // Действие, выполняемое после нажатия "Да"
        final wordCount =
            WordCount(filePath: book.filePath, fileText: book.text);
        // await wordCount.resetCallCount();
        // await showEmptyTable(context, wordCount);
        await saveCurrentTime('timeStep');

        await showTableDialog(context, wordCount, true);
      } else if (result == false) {
        await _savePageCountToLocalStorage();
        getPageCount(book.title, isBorder);
        update();
        final prefs = await SharedPreferences.getInstance();
        lastPageCount = prefs.getDouble('pageCount-${book.filePath}') ?? 0;
        prefs.setDouble('lastPageCount-${book.filePath}', lastPageCount);
        // Действие, выполняемое после нажатия "Нет"
        final wordCount =
            WordCount(filePath: book.filePath, fileText: book.text);
        // Если нужно сбросить счётчик времени
        // await wordCount.resetCallCount();
        // await wordCount.checkCallInfo();
        await saveCurrentTime('timeStep');

        await showTableDialog(context, wordCount, false);
      }
    } else {
      Fluttertoast.showToast(msg: 'Книга не на русском языке!');
      return;
    }
  }

  showTableDialog(
      BuildContext context, WordCount wordCount, bool confirm) async {
    var wordsMap = await WordCount(filePath: book.filePath, fileText: book.text)
        .getAllWordCounts();
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final themeProvider =
            Provider.of<ThemeProvider>(context, listen: false);
        return FutureBuilder(
          future: wordCount.checkCallInfo(confirm),
          builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: MyColors.purple,
                ),
              );
            } else if (snapshot.hasError) {
              // print(wordCount.wordEntries);
              return const AlertDialog(
                content: Text('Произошла ошибка: нет доступа к интернету'),
              );
            } else {
              if (wordCount.wordEntries.isEmpty) {
                Navigator.pop(context);
              }
              return WillPopScope(
                  onWillPop: () async {
                    // debugPrint("DONE");
                    await saveWordCountToLocalstorage(wordCount);
                    replaceWordsWithTranslation(wordCount.wordEntries);
                    return true;
                  },
                  child: GestureDetector(
                    onTap: () async {
                      // debugPrint("DONE");
                      await saveWordCountToLocalstorage(wordCount);
                      replaceWordsWithTranslation(wordCount.wordEntries);
                      //Navigator.pop(context);
                    },
                    child: confirm == false
                        ? SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: forTable == false
                                    ? MediaQuery.of(context).size.height * 0.6
                                    : MediaQuery.of(context).size.height * 0.8,
                              ),
                              child: Container(
                                width: MediaQuery.of(context).size.width,
                                height: forTable == false
                                    ? MediaQuery.of(context).size.height * 0.6
                                    : MediaQuery.of(context).size.height * 0.8,
                                color: Colors.transparent,
                                child: Card(
                                  color: themeProvider.isDarkTheme
                                      ? MyColors.black
                                      : MyColors.white,
                                  child: SizedBox(
                                    width: MediaQuery.of(context).size.width,
                                    height: forTable == false
                                        ? MediaQuery.of(context).size.height *
                                            0.5
                                        : MediaQuery.of(context).size.height *
                                            0.7,
                                    child: Column(
                                      // mainAxisAlignment: MainAxisAlignment.start,
                                      // crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              alignment: Alignment.centerRight,
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      0, 0, 20, 0),
                                              icon: const Icon(Icons.close),
                                              onPressed: () async {
                                                saveWordCountToLocalstorage(
                                                    wordCount);
                                                replaceWordsWithTranslation(
                                                    wordCount.wordEntries);
                                                Navigator.pop(context);
                                              },
                                            ),
                                          ],
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 0),
                                          child: Center(
                                            child: forTable == false
                                                ? const Text24(
                                                    text: 'Изучаемые слова',
                                                    textColor: MyColors.black,
                                                  )
                                                : const Text20(
                                                    text: 'Изучаемые слова',
                                                    textColor: MyColors.black),
                                          ),
                                        ),
                                        Container(
                                          width:
                                              MediaQuery.of(context).size.width,
                                          child: DataTable(
                                            columnSpacing:
                                                forTable == false ? 15 : 0,
                                            showBottomBorder: false,
                                            dataTextStyle: const TextStyle(
                                                fontFamily: 'Roboto',
                                                color: MyColors.black),
                                            clipBehavior: Clip.hardEdge,
                                            horizontalMargin: 10,
                                            columns: [
                                              DataColumn(
                                                label: forTable == false
                                                    ? SizedBox(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            0.19,
                                                        child: const Text(
                                                          'Слово',
                                                          style: TextStyle(
                                                            fontFamily:
                                                                'Tektur',
                                                            fontSize: 15,
                                                          ),
                                                          textAlign:
                                                              TextAlign.left,
                                                        ),
                                                      )
                                                    : SizedBox(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            0.285,
                                                        child: const Text(
                                                          'Слово',
                                                          style: TextStyle(
                                                            fontFamily:
                                                                'Tektur',
                                                            fontSize: 15,
                                                          ),
                                                          textAlign:
                                                              TextAlign.left,
                                                        ),
                                                      ),
                                              ),
                                              DataColumn(
                                                label: forTable == false
                                                    ? const Text('Транскрипция',
                                                        style: TextStyle(
                                                          fontFamily: 'Tektur',
                                                          fontSize: 15,
                                                        ),
                                                        textAlign:
                                                            TextAlign.left)
                                                    : SizedBox(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            0.345,
                                                        child: const Text(
                                                            'Транскрипция',
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'Tektur',
                                                              fontSize: 15,
                                                            ),
                                                            textAlign:
                                                                TextAlign.left),
                                                      ),
                                              ),
                                              DataColumn(
                                                label: forTable == false
                                                    ? Text(
                                                        'Перевод',
                                                        style: const TextStyle(
                                                          fontFamily: 'Tektur',
                                                          fontSize: 15,
                                                        ),
                                                        textAlign: forTable ==
                                                                false
                                                            ? TextAlign.right
                                                            : TextAlign.left,
                                                      )
                                                    : SizedBox(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            0.3,
                                                        child: Text(
                                                          'Перевод',
                                                          style:
                                                              const TextStyle(
                                                            fontFamily:
                                                                'Tektur',
                                                            fontSize: 15,
                                                          ),
                                                          textAlign: forTable ==
                                                                  false
                                                              ? TextAlign.right
                                                              : TextAlign.left,
                                                        ),
                                                      ),
                                              ),
                                            ],
                                            rows: const [],
                                          ),
                                        ),
                                        Container(
                                          width: forTable == true
                                              ? MediaQuery.of(context)
                                                  .size
                                                  .width
                                              : null,
                                          height: forTable == false
                                              ? MediaQuery.of(context)
                                                      .size
                                                      .height *
                                                  0.42
                                              : MediaQuery.of(context)
                                                      .size
                                                      .height *
                                                  0.43,
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.vertical,
                                            child: DataTable(
                                              columnSpacing:
                                                  forTable == false ? 33 : 0,
                                              showBottomBorder: false,
                                              dataTextStyle: const TextStyle(
                                                  fontFamily: 'Roboto',
                                                  color: MyColors.black),
                                              clipBehavior: Clip.hardEdge,
                                              headingRowHeight: 0,
                                              horizontalMargin: 10,
                                              columns: const [
                                                DataColumn(
                                                  label: Flexible(
                                                    child: Text15(
                                                      text: '',
                                                      textColor: MyColors.black,
                                                    ),
                                                  ),
                                                ),
                                                DataColumn(
                                                  label: Flexible(
                                                    child: Text15(
                                                      text: '',
                                                      textColor: MyColors.black,
                                                    ),
                                                  ),
                                                ),
                                                DataColumn(
                                                  label: Flexible(
                                                    child: Text15(
                                                      text: '',
                                                      textColor: MyColors.black,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              rows: wordCount.wordEntries
                                                  .map((entry) {
                                                final themeProvider =
                                                    Provider.of<ThemeProvider>(
                                                        context);

                                                return DataRow(
                                                  cells: [
                                                    DataCell(
                                                      forTable == false
                                                          ? SizedBox(
                                                              width: MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .width *
                                                                  0.23,
                                                              child: Text(
                                                                entry.word,
                                                                style: TextStyle(
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    color: themeProvider.isDarkTheme
                                                                        ? MyColors
                                                                            .white
                                                                        : MyColors
                                                                            .black),
                                                              ),
                                                            )
                                                          : Text(
                                                              entry.word,
                                                              style: TextStyle(
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  color: themeProvider.isDarkTheme
                                                                      ? MyColors
                                                                          .white
                                                                      : MyColors
                                                                          .black),
                                                            ),
                                                    ),
                                                    DataCell(
                                                      forTable == false
                                                          ? SizedBox(
                                                              width: MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .width *
                                                                  0.275,
                                                              child: Text(
                                                                '[ ${entry.ipa} ]',
                                                                style: TextStyle(
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    color: themeProvider.isDarkTheme
                                                                        ? MyColors
                                                                            .white
                                                                        : MyColors
                                                                            .black),
                                                              ),
                                                            )
                                                          : SizedBox(
                                                              width: MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .width *
                                                                  0.14,
                                                              child: Text(
                                                                '[ ${entry.ipa} ]',
                                                                style: TextStyle(
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    color: themeProvider.isDarkTheme
                                                                        ? MyColors
                                                                            .white
                                                                        : MyColors
                                                                            .black),
                                                              ),
                                                            ),
                                                    ),
                                                    DataCell(
                                                      forTable == false
                                                          ? Padding(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 10),
                                                              child: SizedBox(
                                                                width: MediaQuery.of(
                                                                            context)
                                                                        .size
                                                                        .width *
                                                                    0.5,
                                                                child: Text(
                                                                  entry.translation!
                                                                          .isNotEmpty
                                                                      ? entry
                                                                          .translation!
                                                                      : 'N/A',
                                                                  style: TextStyle(
                                                                      color: themeProvider.isDarkTheme
                                                                          ? MyColors
                                                                              .white
                                                                          : MyColors
                                                                              .black),
                                                                ),
                                                              ),
                                                            )
                                                          : Text(
                                                              entry.translation!
                                                                      .isNotEmpty
                                                                  ? entry
                                                                      .translation!
                                                                  : 'N/A',
                                                              style: TextStyle(
                                                                  color: themeProvider.isDarkTheme
                                                                      ? MyColors
                                                                          .white
                                                                      : MyColors
                                                                          .black),
                                                            ),
                                                    ),
                                                  ],
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width,
                                height: forTable == false
                                    ? MediaQuery.of(context).size.height * 0.7
                                    : MediaQuery.of(context).size.height * 0.9,
                                child: Card(
                                  color: themeProvider.isDarkTheme
                                      ? MyColors.black
                                      : MyColors.white,
                                  child: SizedBox(
                                    width: MediaQuery.of(context).size.width,
                                    height: forTable == false
                                        ? MediaQuery.of(context).size.height *
                                            0.6
                                        : MediaQuery.of(context).size.height *
                                            0.8,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            IconButton(
                                              alignment: Alignment.centerRight,
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      0, 0, 20, 0),
                                              icon: const Icon(Icons.close),
                                              onPressed: () async {
                                                await saveWordCountToLocalstorage(
                                                    wordCount);
                                                replaceWordsWithTranslation(
                                                    wordCount.wordEntries);
                                                Navigator.pop(context);
                                              },
                                            ),
                                          ],
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 20),
                                          child: Center(
                                            child: forTable == false
                                                ? Text24(
                                                    text: 'Изучаемые слова',
                                                    textColor: themeProvider
                                                            .isDarkTheme
                                                        ? MyColors.white
                                                        : MyColors.black,
                                                  )
                                                : Text20(
                                                    text: 'Изучаемые слова',
                                                    textColor: themeProvider
                                                            .isDarkTheme
                                                        ? MyColors.white
                                                        : MyColors.black),
                                          ),
                                        ),
                                        Container(
                                          width:
                                              MediaQuery.of(context).size.width,
                                          child: DataTable(
                                            columnSpacing:
                                                forTable == false ? 0 : 30,
                                            showBottomBorder: false,
                                            dataTextStyle: const TextStyle(
                                                fontFamily: 'Roboto',
                                                color: MyColors.black),
                                            clipBehavior: Clip.hardEdge,
                                            horizontalMargin: 10,
                                            columns: [
                                              DataColumn(
                                                label: forTable == false
                                                    ? SizedBox(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            0.6,
                                                        child: const Text(
                                                          'Слово',
                                                          style: TextStyle(
                                                            fontFamily:
                                                                'Tektur',
                                                            fontSize: 15,
                                                          ),
                                                          textAlign:
                                                              TextAlign.left,
                                                        ),
                                                      )
                                                    : SizedBox(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            0.3,
                                                        child: const Text(
                                                          'Слово',
                                                          style: TextStyle(
                                                            fontFamily:
                                                                'Tektur',
                                                            fontSize: 15,
                                                          ),
                                                          textAlign:
                                                              TextAlign.left,
                                                        ),
                                                      ),
                                              ),
                                              DataColumn(
                                                label: forTable == false
                                                    ? Text(
                                                        'Количество',
                                                        style: const TextStyle(
                                                          fontFamily: 'Tektur',
                                                          fontSize: 15,
                                                        ),
                                                        textAlign: forTable ==
                                                                false
                                                            ? TextAlign.right
                                                            : TextAlign.left,
                                                      )
                                                    : Text(
                                                        'Количество',
                                                        style: const TextStyle(
                                                          fontFamily: 'Tektur',
                                                          fontSize: 15,
                                                        ),
                                                        textAlign: forTable ==
                                                                false
                                                            ? TextAlign.right
                                                            : TextAlign.left,
                                                      ),
                                              ),
                                            ],
                                            rows: const [],
                                          ),
                                        ),
                                        Container(
                                            width: MediaQuery.of(context)
                                                .size
                                                .width,
                                            height: forTable == false
                                                ? MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.41
                                                : MediaQuery.of(context)
                                                        .size
                                                        .height *
                                                    0.35,
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.vertical,
                                              child: DataTable(
                                                columnSpacing: 0,
                                                showBottomBorder: false,
                                                dataTextStyle: const TextStyle(
                                                    fontFamily: 'Roboto',
                                                    color: MyColors.black),
                                                clipBehavior: Clip.hardEdge,
                                                headingRowHeight: 0,
                                                horizontalMargin: 10,
                                                columns: const [
                                                  DataColumn(
                                                    label: Flexible(
                                                      child: Text15(
                                                        text: '',
                                                        textColor:
                                                            MyColors.black,
                                                      ),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                    label: Flexible(
                                                      child: Text15(
                                                        text: '',
                                                        textColor:
                                                            MyColors.black,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                rows: wordCount.wordEntries
                                                    .map((entry) {
                                                  return DataRow(
                                                    cells: [
                                                      DataCell(
                                                        forTable == false
                                                            ? SizedBox(
                                                                width: MediaQuery.of(
                                                                            context)
                                                                        .size
                                                                        .width *
                                                                    0.6,
                                                                child: InkWell(
                                                                  onTap:
                                                                      () async {
                                                                    await _showWordInputDialog(
                                                                        entry
                                                                            .word,
                                                                        wordCount
                                                                            .wordEntries,
                                                                        wordsMap);
                                                                    setState(
                                                                        () {
                                                                      entry
                                                                          .word;
                                                                      entry
                                                                          .count;
                                                                    });
                                                                  },
                                                                  child:
                                                                      TextForTable(
                                                                    text: entry
                                                                        .word,
                                                                    textColor:
                                                                        MyColors
                                                                            .black,
                                                                  ),
                                                                ),
                                                              )
                                                            : SizedBox(
                                                                width: MediaQuery.of(
                                                                            context)
                                                                        .size
                                                                        .width *
                                                                    0.43,
                                                                child: InkWell(
                                                                  onTap:
                                                                      () async {
                                                                    await _showWordInputDialog(
                                                                        entry
                                                                            .word,
                                                                        wordCount
                                                                            .wordEntries,
                                                                        wordsMap);
                                                                    setState(
                                                                        () {
                                                                      entry
                                                                          .word;
                                                                      entry
                                                                          .count;
                                                                    });
                                                                  },
                                                                  child:
                                                                      TextForTable(
                                                                    text: entry
                                                                        .word,
                                                                    textColor:
                                                                        MyColors
                                                                            .black,
                                                                  ),
                                                                ),
                                                              ),
                                                      ),
                                                      DataCell(
                                                        SizedBox(
                                                          width: MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .width *
                                                              0.2,
                                                          child: TextForTable(
                                                            text:
                                                                '${entry.count}',
                                                            textColor:
                                                                MyColors.black,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }).toList(),
                                              ),
                                            )),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ));
            }
          },
        );
      },
    );
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('wordsShowcase') != true) {
      (_showcaseKey.currentState as CustomShowcaseState?)
          ?.showSlides([const ThirdSlide()]);
      prefs.setBool('wordsShowcase', true);
    }
  }

  static double safemod(double a, double n) {
    final res = a % n;
    if ((res - n).abs() < 0.1) {
      return 0.0;
    }
    return res;
  }

  void animateTo(bool up) {
    if (up) {
      final plh = (position(height) / lineHeight);
      final prev = plh.ceilToDouble() * lineHeight - position(height);
      _scrollOffsetController.animateScroll(
          offset: prev - (height / lineHeight).floorToDouble() * lineHeight,
          duration: const Duration(milliseconds: 250),
          curve: Curves.linear);
    } else {
      final rem = safemod(positionDown(height), lineHeight);
      _scrollOffsetController.animateScroll(
          offset: (rem.abs() > 1 ? rem - lineHeight : 0) +
              (height / lineHeight).floorToDouble() * lineHeight +
              ((safemod(height, lineHeight) > baseline && rem.abs() < 0.1)
                  ? lineHeight
                  : 0),
          duration: const Duration(milliseconds: 250),
          curve: Curves.linear);
    }
  }

  Future<void> _showWordInputDialog(String word, List<WordEntry> wordEntries,
      Map<String, int> wordsMap) async {
    String searchText = '';
    List<String> filteredWords = [];

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "",
      builder: (BuildContext context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  final themeProvider = Provider.of<ThemeProvider>(context);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Card(
                        color: themeProvider.isDarkTheme
                            ? MyColors.black
                            : MyColors.white,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  alignment: Alignment.centerRight,
                                  padding:
                                      const EdgeInsets.fromLTRB(0, 0, 20, 0),
                                  icon: const Icon(Icons.close),
                                  onPressed: () async {
                                    Navigator.pop(context);
                                  },
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 0),
                              child: Center(
                                child: Text24(
                                  text: 'Выберите слова',
                                  textColor: themeProvider.isDarkTheme
                                      ? MyColors.white
                                      : MyColors.black,
                                ),
                              ),
                            ),
                            Flexible(
                              flex: 1,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    child: TextField(
                                      cursorColor: Colors.black,
                                      onChanged: (value) {
                                        setState(() {
                                          searchText = value.toLowerCase();
                                          filteredWords = wordsMap.keys
                                              .where((word) => word
                                                  .toLowerCase()
                                                  .startsWith(searchText))
                                              .toList();
                                          filteredWords
                                              .sort((a, b) => a.compareTo(b));
                                          filteredWords.sort((a, b) =>
                                              wordsMap[b]!
                                                  .compareTo(wordsMap[a]!));
                                        });
                                      },
                                      decoration: InputDecoration(
                                        labelText: 'Введите текст',
                                        border: const OutlineInputBorder(),
                                        disabledBorder:
                                            const OutlineInputBorder(),
                                        focusedBorder:
                                            const OutlineInputBorder(),
                                        focusColor: MyColors.purple,
                                        floatingLabelStyle:
                                            themeProvider.isDarkTheme
                                                ? const TextStyle(
                                                    color: MyColors.black)
                                                : const TextStyle(
                                                    color: MyColors.white),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: MediaQuery.of(context).size.width,
                                    child: DataTable(
                                        columnSpacing: 45.0,
                                        showBottomBorder: false,
                                        horizontalMargin: 20,
                                        dataTextStyle: TextStyle(
                                            fontFamily: 'Roboto',
                                            color: themeProvider.isDarkTheme
                                                ? MyColors.white
                                                : MyColors.black),
                                        columns: [
                                          DataColumn(
                                            label: SizedBox(
                                              child: Text15(
                                                  text: 'Слово',
                                                  textColor:
                                                      themeProvider.isDarkTheme
                                                          ? MyColors.white
                                                          : MyColors.black),
                                            ),
                                          ),
                                          DataColumn(
                                            label: SizedBox(
                                              child: Text15(
                                                text: 'Количество',
                                                textColor:
                                                    themeProvider.isDarkTheme
                                                        ? MyColors.white
                                                        : MyColors.black,
                                              ),
                                            ),
                                          ),
                                        ],
                                        rows: const []),
                                  ),
                                  Container(
                                      width: MediaQuery.of(context).size.width,
                                      height: forTable == false
                                          ? MediaQuery.of(context).size.height *
                                              0.42
                                          : MediaQuery.of(context).size.height *
                                              0.2,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.vertical,
                                        child: DataTable(
                                          columnSpacing: 0.0,
                                          showBottomBorder: false,
                                          dataTextStyle: TextStyle(
                                              fontFamily: 'Roboto',
                                              color: themeProvider.isDarkTheme
                                                  ? MyColors.white
                                                  : MyColors.black),
                                          clipBehavior: Clip.hardEdge,
                                          headingRowHeight: 0,
                                          horizontalMargin: 10,
                                          columns: [
                                            DataColumn(
                                              label: Flexible(
                                                child: Text15(
                                                  text: '',
                                                  textColor:
                                                      themeProvider.isDarkTheme
                                                          ? MyColors.white
                                                          : MyColors.black,
                                                ),
                                              ),
                                            ),
                                            DataColumn(
                                              label: Flexible(
                                                child: Text15(
                                                  text: '',
                                                  textColor:
                                                      themeProvider.isDarkTheme
                                                          ? MyColors.white
                                                          : MyColors.black,
                                                ),
                                              ),
                                            ),
                                          ],
                                          rows: searchText.isEmpty
                                              ? const <DataRow>[]
                                              : List<DataRow>.generate(
                                                  filteredWords.length,
                                                  (index) => DataRow(
                                                    cells: [
                                                      DataCell(
                                                        SizedBox(
                                                          width: MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .width *
                                                              0.3,
                                                          child: TextButton(
                                                            style: const ButtonStyle(
                                                                alignment: Alignment
                                                                    .centerLeft),
                                                            onPressed:
                                                                () async {
                                                              List<String>
                                                                  test = [
                                                                filteredWords[
                                                                    index]
                                                              ];
                                                              // print(test);
                                                              test = await WordCount()
                                                                  .getNounsByList(
                                                                      test);
                                                              // print('after $test');
                                                              if (test.length !=
                                                                  1) {
                                                                Fluttertoast
                                                                    .showToast(
                                                                        msg:
                                                                            'Данное слово не существительное');
                                                                return;
                                                              } else {
                                                                await updateWordInTable(
                                                                    word,
                                                                    filteredWords[
                                                                        index],
                                                                    wordEntries);
                                                                Navigator.of(
                                                                        context)
                                                                    .pop();
                                                              }
                                                            },
                                                            child: Text(
                                                              filteredWords[
                                                                  index],
                                                              style: TextStyle(
                                                                  fontFamily:
                                                                      'Roboto',
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  color: themeProvider.isDarkTheme
                                                                      ? MyColors
                                                                          .white
                                                                      : MyColors
                                                                          .black),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        SizedBox(
                                                          width: MediaQuery.of(
                                                                      context)
                                                                  .size
                                                                  .width *
                                                              0.3,
                                                          child: TextForTable(
                                                            text:
                                                                '${wordsMap[filteredWords[index]] ?? 0}',
                                                            textColor:
                                                                MyColors.black,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                        ),
                                      ))
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> updateWordInTable(
      String oldWord, String newWord, List<WordEntry> wordEntries) async {
    final index = wordEntries.indexWhere((entry) => entry.word == oldWord);
    if (index != -1) {
      final count = WordCount(filePath: book.filePath, fileText: book.text)
          .getWordCount(newWord);
      final translation =
          await WordCount(filePath: book.filePath, fileText: book.text)
              .translateToEnglish(newWord);
      final ipa = await WordCount(filePath: book.filePath, fileText: book.text)
          .getIPA(translation);

      wordEntries[index] = WordEntry(
        word: newWord,
        count: count,
        translation: translation,
        ipa: ipa,
      );

      setState(() {});
    }
  }

  Future<void> showSavedWords(BuildContext context, String filePath) async {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        final themeProvider = Provider.of<ThemeProvider>(context);
        return FutureBuilder<WordCount>(
          future: loadWordCountFromLocalStorage(),
          builder: (BuildContext context, AsyncSnapshot<WordCount> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: MyColors.purple,
                ),
              );
            } else if (snapshot.hasError) {
              return AlertDialog(
                content: Text('Error: ${snapshot.error}'),
              );
            } else if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasData) {
                WordCount? wordCount = snapshot.data;
                // debugPrint('Getted wordCount $wordCount');
                if (wordCount == null || wordCount.wordEntries.isEmpty) {
                  Fluttertoast.showToast(
                    msg: 'Нет сохраненных слов',
                    toastLength: Toast.LENGTH_SHORT,
                    // Длительность отображения
                    gravity: ToastGravity.BOTTOM,
                  );
                  Navigator.pop(context);
                  return const SizedBox.shrink();
                }
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: forTable == false
                            ? MediaQuery.of(context).size.height * 0.6
                            : MediaQuery.of(context).size.height * 0.8,
                      ),
                      child: Container(
                        width: MediaQuery.of(context).size.width,
                        height: forTable == false
                            ? MediaQuery.of(context).size.height * 0.6
                            : MediaQuery.of(context).size.height * 0.8,
                        color: Colors.transparent,
                        child: Card(
                          color: themeProvider.isDarkTheme
                              ? MyColors.black
                              : MyColors.white,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width,
                            height: forTable == false
                                ? MediaQuery.of(context).size.height * 0.5
                                : MediaQuery.of(context).size.height * 0.7,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.fromLTRB(
                                          0, 0, 20, 0),
                                      icon: const Icon(Icons.close),
                                      onPressed: () async {
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 0),
                                  child: Center(
                                    child: forTable == false
                                        ? Text24(
                                            text: 'Изучаемые слова',
                                            textColor: themeProvider.isDarkTheme
                                                ? MyColors.white
                                                : MyColors.black,
                                          )
                                        : Text20(
                                            text: 'Изучаемые слова',
                                            textColor: themeProvider.isDarkTheme
                                                ? MyColors.white
                                                : MyColors.black),
                                  ),
                                ),
                                Container(
                                  width: MediaQuery.of(context).size.width,
                                  child: DataTable(
                                    columnSpacing: forTable == false ? 15 : 0,
                                    showBottomBorder: false,
                                    dataTextStyle: const TextStyle(
                                        fontFamily: 'Roboto',
                                        color: MyColors.black),
                                    clipBehavior: Clip.hardEdge,
                                    horizontalMargin: 10,
                                    columns: [
                                      DataColumn(
                                        label: forTable == false
                                            ? SizedBox(
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.19,
                                                child: const Text(
                                                  'Слово',
                                                  style: TextStyle(
                                                    fontFamily: 'Tektur',
                                                    fontSize: 15,
                                                  ),
                                                  textAlign: TextAlign.left,
                                                ),
                                              )
                                            : SizedBox(
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.285,
                                                child: const Text(
                                                  'Слово',
                                                  style: TextStyle(
                                                    fontFamily: 'Tektur',
                                                    fontSize: 15,
                                                  ),
                                                  textAlign: TextAlign.left,
                                                ),
                                              ),
                                      ),
                                      DataColumn(
                                        label: forTable == false
                                            ? const Text('Транскрипция',
                                                style: TextStyle(
                                                  fontFamily: 'Tektur',
                                                  fontSize: 15,
                                                ),
                                                textAlign: TextAlign.left)
                                            : SizedBox(
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.345,
                                                child: const Text(
                                                    'Транскрипция',
                                                    style: TextStyle(
                                                      fontFamily: 'Tektur',
                                                      fontSize: 15,
                                                    ),
                                                    textAlign: TextAlign.left),
                                              ),
                                      ),
                                      DataColumn(
                                        label: forTable == false
                                            ? Text(
                                                'Перевод',
                                                style: const TextStyle(
                                                  fontFamily: 'Tektur',
                                                  fontSize: 15,
                                                ),
                                                textAlign: forTable == false
                                                    ? TextAlign.right
                                                    : TextAlign.left,
                                              )
                                            : SizedBox(
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.3,
                                                child: Text(
                                                  'Перевод',
                                                  style: const TextStyle(
                                                    fontFamily: 'Tektur',
                                                    fontSize: 15,
                                                  ),
                                                  textAlign: forTable == false
                                                      ? TextAlign.right
                                                      : TextAlign.left,
                                                ),
                                              ),
                                      ),
                                    ],
                                    rows: const [],
                                  ),
                                ),
                                Container(
                                  width: forTable == true
                                      ? MediaQuery.of(context).size.width
                                      : null,
                                  height: forTable == false
                                      ? MediaQuery.of(context).size.height *
                                          0.42
                                      : MediaQuery.of(context).size.height *
                                          0.43,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: DataTable(
                                      columnSpacing: forTable == false ? 33 : 0,
                                      showBottomBorder: false,
                                      dataTextStyle: const TextStyle(
                                          fontFamily: 'Roboto',
                                          color: MyColors.black),
                                      clipBehavior: Clip.hardEdge,
                                      headingRowHeight: 0,
                                      horizontalMargin: 10,
                                      columns: const [
                                        DataColumn(
                                          label: Flexible(
                                            child: Text15(
                                              text: '',
                                              textColor: MyColors.black,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Flexible(
                                            child: Text15(
                                              text: '',
                                              textColor: MyColors.black,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Flexible(
                                            child: Text15(
                                              text: '',
                                              textColor: MyColors.black,
                                            ),
                                          ),
                                        ),
                                      ],
                                      rows: wordCount.wordEntries.map((entry) {
                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              forTable == false
                                                  ? SizedBox(
                                                      width:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .width *
                                                              0.23,
                                                      child: Text(
                                                        entry.word,
                                                        style: TextStyle(
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            color: themeProvider
                                                                    .isDarkTheme
                                                                ? MyColors.white
                                                                : MyColors
                                                                    .black),
                                                      ),
                                                    )
                                                  : Text(
                                                      entry.word,
                                                      style: TextStyle(
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          color: themeProvider
                                                                  .isDarkTheme
                                                              ? MyColors.white
                                                              : MyColors.black),
                                                    ),
                                            ),
                                            DataCell(
                                              forTable == false
                                                  ? SizedBox(
                                                      width:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .width *
                                                              0.275,
                                                      child: Text(
                                                        '[ ${entry.ipa} ]',
                                                        style: TextStyle(
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            color: themeProvider
                                                                    .isDarkTheme
                                                                ? MyColors.white
                                                                : MyColors
                                                                    .black),
                                                      ),
                                                    )
                                                  : SizedBox(
                                                      width:
                                                          MediaQuery.of(context)
                                                                  .size
                                                                  .width *
                                                              0.14,
                                                      child: Text(
                                                        '[ ${entry.ipa} ]',
                                                        style: TextStyle(
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            color: themeProvider
                                                                    .isDarkTheme
                                                                ? MyColors.white
                                                                : MyColors
                                                                    .black),
                                                      ),
                                                    ),
                                            ),
                                            DataCell(
                                              forTable == false
                                                  ? Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              left: 10),
                                                      child: SizedBox(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width *
                                                            0.5,
                                                        child: Text(
                                                          entry.translation!
                                                                  .isNotEmpty
                                                              ? entry
                                                                  .translation!
                                                              : 'N/A',
                                                          style: TextStyle(
                                                              color: themeProvider
                                                                      .isDarkTheme
                                                                  ? MyColors
                                                                      .white
                                                                  : MyColors
                                                                      .black),
                                                        ),
                                                      ),
                                                    )
                                                  : Text(
                                                      entry.translation!
                                                              .isNotEmpty
                                                          ? entry.translation!
                                                          : 'N/A',
                                                      style: TextStyle(
                                                          color: themeProvider
                                                                  .isDarkTheme
                                                              ? MyColors.white
                                                              : MyColors.black),
                                                    ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                return const Center(
                  child: Text('No data available.'),
                );
              }
            } else {
              return const Center(
                child: Text('Unexpected state.'),
              );
            }
          },
        );
      },
    );
  }

  Future<void> saveJsonToFile(
      Map<String, dynamic> jsonData, String filePath) async {
    try {
      final file = File(filePath);
      final directory = Directory(file.parent.path);

      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      await file.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      print('Ошибка при сохранении файла: $e');
    }
  }

  Future<DateTime?> readTimeFromJsonFile(String fileName) async {
    try {
      final appDir = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();
      final filePath = '${appDir?.path}/Timer/$fileName.json';
      final file = File(filePath);
      if (await file.exists()) {
        final fileContent = await file.readAsString();
        final jsonData = jsonDecode(fileContent);
        if (jsonData.containsKey('TimeDialog')) {
          return DateTime.parse(jsonData['TimeDialog']);
        }
      }
    } catch (e) {
      print('Ошибка при чтении файла: $e');
    }
    return null;
  }

  Future<void> saveCurrentTime(String fileName) async {
    final appDir = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();
    final filePath = '${appDir?.path}/Timer/$fileName.json';
    var timeNow = DateTime.now();
    await saveJsonToFile({'TimeDialog': timeNow.toIso8601String()}, filePath);
  }

  void toggleWordMode() async {
    const String fileName = 'timeStep';
    switch (isBorder) {
      case false:
        var timeNow = DateTime.now();
        var timeLast = await readTimeFromJsonFile(fileName);
        if (timeLast != null) {
          var elapsedTime = timeNow.difference(timeLast);
          final prefs = await SharedPreferences.getInstance();
          String key = 'WMWORDS';
          String? storedData = prefs.getString(key);
          if (storedData == null) {
            await prefs.setString('lastCallTimestamp', "19710101T030000+0300");
          }
          wordModeDialog(context);
          // TODO: пока убрано
          // if (elapsedTime.inHours >= 24 || storedData == null) {
          //   wordModeDialog(context);
          // } else {
          //   var tempWE = await loadWordCountFromLocalStorage();
          //   if (tempWE.filePath != '') {
          //     replaceWordsWithTranslation(tempWE.wordEntries);
          //   }
          // }
        } else {
          wordModeDialog(context);
        }
        break;
      default:
        await _savePageCountToLocalStorage();
        await getPageCount(book.title, isBorder);
        final prefs = await SharedPreferences.getInstance();
        await update();
        lastPageCount = prefs.getDouble('pageCount-${book.filePath}') ?? 0;
        prefs.setDouble('lastPageCount-${book.filePath}', lastPageCount);
        isBorder = false;
        setState(() {});
        // TODO: пока убрано
        // var timeLast = await readTimeFromJsonFile(fileName);
        // if (timeLast != null) {
        //   final formattedTime = DateFormat('dd.MM.yy HH:mm')
        //       .format(timeLast.add(const Duration(days: 1)));

        //   Fluttertoast.showToast(
        //     msg: 'Новый перевод будет доступен $formattedTime',
        //     toastLength: Toast.LENGTH_LONG,
        //     gravity: ToastGravity.BOTTOM,
        //   );
        // }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final size = MediaQuery.of(context);

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, result) async {
          await update();

          await _savePageCountToLocalStorage();
          getPageCount(book.title, isBorder);
          if (!didPop) {
            Navigator.pop(context, percentage / 100);
          }
        },
        child: !loading
            ? CustomShowcase(
                key: _showcaseKey,
                builder: (context) {
                  return Scaffold(
                    appBar: visible
                        ? PreferredSize(
                            preferredSize:
                                Size(MediaQuery.of(context).size.width, 50),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              child: AppBar(
                                  leading: GestureDetector(
                                      onTap: () async {
                                        await update();
                                        Navigator.pop(
                                            context, percentage / 100);
                                      },
                                      child: Theme(
                                        data: lightTheme(),
                                        child: Icon(
                                          CustomIcons.chevronLeft,
                                          size: 30,
                                          color:
                                              Theme.of(context).iconTheme.color,
                                        ),
                                      )),
                                  backgroundColor:
                                      Theme.of(context).colorScheme.primary,
                                  shadowColor: Colors.transparent,
                                  title: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          clipBehavior: Clip.antiAlias,
                                          child: Text(
                                            book.author.isNotEmpty &&
                                                    book.customTitle.isNotEmpty
                                                ? '${book.author.toString()}. ${book.customTitle.toString()}'
                                                : 'Нет автора',
                                            softWrap: false,
                                            overflow: TextOverflow.fade,
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontFamily: 'Tektur',
                                                color: themeProvider.isDarkTheme
                                                    ? MyColors.white
                                                    : MyColors.black),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            35, 0, 0, 0),
                                        child: GestureDetector(
                                          onTap: () {
                                            timer.cancel();
                                            Navigator.pushNamed(context,
                                                    RouteNames.readerSettings)
                                                .then((value) {
                                              FlutterScreenWake.brightness
                                                  .then((value) {
                                                brigtness = value;
                                                timer = Timer.periodic(
                                                    const Duration(
                                                        milliseconds: 100),
                                                    (Timer t) {
                                                  FlutterScreenWake
                                                      .setBrightness(brigtness);
                                                });
                                              });
                                              loadStylePreferences();
                                            });
                                          },
                                          child: Icon(
                                            CustomIcons.sliders,
                                            size: 28,
                                            color: Theme.of(context)
                                                .iconTheme
                                                .color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )),
                            ),
                          )
                        : null,
                    body: Container(
                        decoration: BoxDecoration(
                            color: backgroundColor,
                            border: isBorder == true
                                ? Border.all(
                                    color: const Color.fromRGBO(0, 255, 163, 1),
                                    width: 2)
                                : Border.all(
                                    width: 0, color: Colors.transparent)),
                        child: Stack(
                          children: [
                            SafeArea(
                              top: true,
                              bottom: false,
                              minimum: visible
                                  ? const EdgeInsets.only(
                                      top: 0, left: 8, right: 8)
                                  : orientations[currentOrientationIndex] ==
                                              DeviceOrientation.landscapeLeft ||
                                          orientations[
                                                  currentOrientationIndex] ==
                                              DeviceOrientation.landscapeRight
                                      ? const EdgeInsets.only(
                                          top: 0, left: 8, right: 8)
                                      : const EdgeInsets.only(
                                          top: 40, left: 8, right: 8),
                              child: LayoutBuilder(builder: (context, cc) {
                                height = cc.maxHeight;
                                width = cc.maxWidth;
                                return Stack(children: [
                                  GestureDetector(
                                    onTap: () {
                                      // Скролл вниз / следующая страница
                                      animateTo(false);
                                    },
                                    child: ScrollablePositionedList.builder(
                                        itemPositionsListener:
                                            _itemPositionsListener,
                                        itemScrollController:
                                            _itemScrollController,
                                        itemCount: isBorder
                                            ? translatedText.length
                                            : text.length,
                                        scrollOffsetController:
                                            _scrollOffsetController,
                                        scrollOffsetListener:
                                            _scrollOffsetListener,
                                        itemBuilder: (context, index) =>
                                            RichText(
                                                text: TextSpan(
                                              text: isBorder
                                                  ? translatedText[index]
                                                  : text[index],
                                              style: TextStyle(
                                                  fontSize: fontSize,
                                                  color: textColor,
                                                  height: 1.41,
                                                  locale:
                                                      const Locale('ru', 'RU')),
                                            ))),
                                  ),
                                  Positioned(
                                      left: 100,
                                      right: 100,
                                      height: visible
                                          ? 2 * cc.maxHeight / 3
                                          : cc.maxHeight / 2,
                                      child: GestureDetector(
                                          behavior: HitTestBehavior.translucent,
                                          onTap: () {
                                            // Скролл вверх / предыдущая страница
                                            animateTo(true);
                                          })),
                                  Positioned(
                                      right: 0,
                                      top: cc.maxHeight / 6,
                                      bottom: cc.maxHeight / 6,
                                      width: 100,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onVerticalDragStart: (details) async {
                                          brigtness = await FlutterScreenWake
                                              .brightness;
                                        },
                                        onVerticalDragUpdate: (details) {
                                          brigtness -= details.delta.dy / 1000;
                                          brigtness = min(1, max(0, brigtness));
                                        },
                                      )),
                                  Positioned(
                                      left: 0,
                                      top: cc.maxHeight / 6,
                                      bottom: cc.maxHeight / 6,
                                      width: 100,
                                      child: GestureDetector(
                                          behavior: HitTestBehavior.translucent,
                                          onVerticalDragStart: (details) {
                                            oldFs = fontSize;
                                            final frst = _itemPositionsListener
                                                .itemPositions
                                                .value
                                                .first
                                                .index;
                                            final tp = TextPainter(
                                              text: TextSpan(
                                                  text: isBorder
                                                      ? translatedText[frst]
                                                      : text[frst],
                                                  style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: fontSize,
                                                      height: 1.41,
                                                      locale: const Locale(
                                                          'ru', 'RU'))),
                                              textAlign: TextAlign.left,
                                              textDirection:
                                                  ui.TextDirection.ltr,
                                            )..layout(maxWidth: cc.maxWidth);
                                            textPosOld = tp
                                                .getPositionForOffset(Offset(
                                                    0, position(cc.maxHeight)))
                                                .offset;
                                            textPosOldIndex = frst;

                                            textTimer?.cancel();
                                            textTimer = Timer.periodic(
                                                const Duration(
                                                    milliseconds: 60), (timer) {
                                              if ((fontSize * 2)
                                                      .floorToDouble() !=
                                                  (vFontSize * 2)
                                                      .floorToDouble()) {
                                                fontSize = (vFontSize * 2)
                                                        .floorToDouble() /
                                                    2;
                                                _itemScrollController.jumpTo(
                                                    index: textPosOldIndex!);
                                              }
                                            });
                                          },
                                          onVerticalDragUpdate: (details) {
                                            vFontSize -= details.delta.dy / 20;
                                            vFontSize = min(vFontSize, 72);
                                            vFontSize = max(vFontSize, 10);
                                          },
                                          onVerticalDragEnd: (detalis) async {
                                            textTimer?.cancel();
                                            if ((fontSize - oldFs).abs() <
                                                0.1) {
                                              return;
                                            }

                                            if ((fontSize * 2)
                                                    .floorToDouble() !=
                                                (vFontSize * 2)
                                                    .floorToDouble()) {
                                              fontSize = (vFontSize * 2)
                                                      .floorToDouble() /
                                                  2;
                                              _itemScrollController.jumpTo(
                                                  index: textPosOldIndex!);
                                            }

                                            final txt = isBorder
                                                ? translatedText[
                                                    textPosOldIndex!]
                                                : text[textPosOldIndex!];
                                            final tp = TextPainter(
                                              text: TextSpan(
                                                  text: txt,
                                                  style: TextStyle(
                                                      color: Colors.black,
                                                      fontSize: fontSize,
                                                      height: 1.41,
                                                      locale: const Locale(
                                                          'ru', 'RU'))),
                                              textAlign: TextAlign.left,
                                              textDirection:
                                                  ui.TextDirection.ltr,
                                            )..layout(maxWidth: cc.maxWidth);

                                            lineHeight = tp.preferredLineHeight;
                                            baseline = tp
                                                .computeDistanceToActualBaseline(
                                                    TextBaseline.alphabetic);
                                            final off = tp
                                                .getBoxesForSelection(
                                                    TextSelection(
                                                        baseOffset: textPosOld!,
                                                        extentOffset:
                                                            textPosOld! + 1))[0]
                                                .top;
                                            if (off > 5) {
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((time) =>
                                                      _scrollOffsetController
                                                          .animateScroll(
                                                              offset: off,
                                                              duration:
                                                                  const Duration(
                                                                      microseconds:
                                                                          1)));
                                            }
                                            setState(() {});
                                          })),
                                  isBorder
                                      ? Positioned(
                                          top: cc.maxHeight / 6,
                                          bottom: visible
                                              ? cc.maxHeight / 4
                                              : cc.maxHeight / 5,
                                          left: 100,
                                          right: 100,
                                          child: GestureDetector(
                                              behavior:
                                                  HitTestBehavior.translucent,
                                              onVerticalDragEnd:
                                                  (dragEndDetails) async {
                                                if (dragEndDetails
                                                        .primaryVelocity! >
                                                    0) {
                                                  showSavedWords(
                                                      context, book.filePath);
                                                }
                                              },
                                              onTap: () {
                                                setState(() {
                                                  visible = !visible;
                                                });
                                                if (visible) {
                                                  SystemChrome
                                                      .setEnabledSystemUIMode(
                                                    SystemUiMode.manual,
                                                    overlays: [
                                                      SystemUiOverlay.top,
                                                      SystemUiOverlay.bottom,
                                                    ],
                                                  );
                                                } else {
                                                  SystemChrome
                                                      .setEnabledSystemUIMode(
                                                          SystemUiMode
                                                              .immersive);
                                                }
                                              }))
                                      : Positioned(
                                          top: visible
                                              ? cc.maxHeight / 4
                                              : cc.maxHeight / 5,
                                          bottom: visible
                                              ? cc.maxHeight / 4
                                              : cc.maxHeight / 5,
                                          left: 100,
                                          right: 100,
                                          child: GestureDetector(
                                            behavior:
                                                HitTestBehavior.translucent,
                                            onTap: () {
                                              setState(() {
                                                visible = !visible;
                                              });
                                              if (visible) {
                                                SystemChrome
                                                    .setEnabledSystemUIMode(
                                                  SystemUiMode.manual,
                                                  overlays: [
                                                    SystemUiOverlay.top,
                                                    SystemUiOverlay.bottom,
                                                  ],
                                                );
                                              } else {
                                                SystemChrome
                                                    .setEnabledSystemUIMode(
                                                        SystemUiMode.manual,
                                                        overlays: []);
                                              }
                                            },
                                          ),
                                        ),
                                ]);
                              }),
                            ),
                          ],
                        )),
                    bottomNavigationBar: Platform.isIOS
                        ? BottomAppBar(
                            height: !visible ? 42 : 110,
                            color: visible
                                ? Theme.of(context).colorScheme.primary
                                : backgroundColor,
                            child: Stack(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  height: visible ? 42 : 110,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: !visible
                                        ? [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      10, 0, 0, 0),
                                              child: Container(
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width /
                                                    8,
                                                alignment: Alignment.topLeft,
                                                child: Stack(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  children: [
                                                    Transform.rotate(
                                                      angle:
                                                          90 * 3.14159265 / 180,
                                                      child: Icon(
                                                        Icons.battery_full,
                                                        color: themeProvider
                                                                .isDarkTheme
                                                            ? backgroundColor
                                                                        .value ==
                                                                    0xff1d1d21
                                                                ? MyColors.white
                                                                : MyColors.black
                                                            : backgroundColor
                                                                        .value !=
                                                                    0xff1d1d21
                                                                ? MyColors.black
                                                                : MyColors
                                                                    .white,
                                                        size: 28,
                                                      ),
                                                    ),
                                                    Text(
                                                      _batteryLevel.toInt() >=
                                                              100
                                                          ? '${_batteryLevel.toString()}%'
                                                          : ' ${_batteryLevel.toString()}%',
                                                      style: TextStyle(
                                                        color: themeProvider
                                                                .isDarkTheme
                                                            ? backgroundColor
                                                                        .value ==
                                                                    0xff1d1d21
                                                                ? MyColors.black
                                                                : MyColors.white
                                                            : backgroundColor
                                                                        .value !=
                                                                    0xff1d1d21
                                                                ? MyColors.white
                                                                : MyColors
                                                                    .black,
                                                        fontSize: 7,
                                                        fontFamily: 'Tektur',
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        0, 3, 0, 0),
                                                child: Align(
                                                  alignment:
                                                      Alignment.topCenter,
                                                  child: SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    child: Text(
                                                      book.customTitle
                                                                  .isNotEmpty &&
                                                              book.author
                                                                  .isNotEmpty
                                                          ? '${book.author.toString()}. ${book.customTitle.toString()}'
                                                          : 'Нет названия',
                                                      style: TextStyle(
                                                          color: themeProvider
                                                                  .isDarkTheme
                                                              ? backgroundColor
                                                                          .value ==
                                                                      0xff1d1d21
                                                                  ? MyColors
                                                                      .white
                                                                  : MyColors
                                                                      .black
                                                              : backgroundColor
                                                                          .value !=
                                                                      0xff1d1d21
                                                                  ? MyColors
                                                                      .black
                                                                  : MyColors
                                                                      .white,
                                                          fontFamily: 'Tektur',
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      textAlign:
                                                          TextAlign.center,
                                                      overflow:
                                                          TextOverflow.visible,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      0, 3, 10, 0),
                                              child: Container(
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width /
                                                    8,
                                                alignment: Alignment.topRight,
                                                child: Text(
                                                  '${100}%',
                                                  style: TextStyle(
                                                      color: themeProvider
                                                              .isDarkTheme
                                                          ? backgroundColor
                                                                      .value ==
                                                                  0xff1d1d21
                                                              ? MyColors.white
                                                              : MyColors.black
                                                          : backgroundColor
                                                                      .value !=
                                                                  0xff1d1d21
                                                              ? MyColors.black
                                                              : MyColors.white,
                                                      fontFamily: 'Tektur',
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          ]
                                        : [],
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      height: visible ? 85 : 0,
                                      child: SingleChildScrollView(
                                        child: Container(
                                            alignment:
                                                AlignmentDirectional.topEnd,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            child: Column(
                                              children: [
                                                SliderTheme(
                                                  data: const SliderThemeData(
                                                      showValueIndicator:
                                                          ShowValueIndicator
                                                              .always),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    children: [
                                                      Flexible(
                                                          child: SliderTheme(
                                                        data: const SliderThemeData(
                                                            trackHeight: 3,
                                                            thumbShape:
                                                                RoundSliderThumbShape(
                                                                    enabledThumbRadius:
                                                                        9),
                                                            trackShape:
                                                                RectangularSliderTrackShape()),
                                                        child: Container(
                                                          width: orientations[
                                                                          currentOrientationIndex] ==
                                                                      DeviceOrientation
                                                                          .landscapeLeft ||
                                                                  orientations[
                                                                          currentOrientationIndex] ==
                                                                      DeviceOrientation
                                                                          .landscapeRight
                                                              ? MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .width /
                                                                  1.19
                                                              : MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .width /
                                                                  1.12,
                                                          child: Slider(
                                                            value: percentage,
                                                            min: 0,
                                                            max: 100,
                                                            label:
                                                                "$percentage%",
                                                            onChanged: (value) {
                                                              setState(() {
                                                                percentage =
                                                                    value;
                                                              });
                                                              if (_actionTimer
                                                                      ?.isActive ??
                                                                  false) {
                                                                _actionTimer
                                                                    ?.cancel();
                                                              }
                                                              _actionTimer = Timer(
                                                                  const Duration(
                                                                      milliseconds:
                                                                          250),
                                                                  () {
                                                                /*TODO jumpTo(
                                                                              value);*/
                                                              });
                                                            },
                                                            onChangeEnd:
                                                                (value) {
                                                              _actionTimer
                                                                  ?.cancel();
                                                              /*TODO if (value !=
                                                                            _scrollController
                                                                                .position
                                                                                .pixels) {
                                                                          jumpTo(
                                                                              value);
                                                                        }*/
                                                            },
                                                            activeColor: themeProvider
                                                                    .isDarkTheme
                                                                ? MyColors.white
                                                                : const Color
                                                                    .fromRGBO(
                                                                    29,
                                                                    29,
                                                                    33,
                                                                    1),
                                                            inactiveColor: themeProvider
                                                                    .isDarkTheme
                                                                ? const Color
                                                                    .fromRGBO(
                                                                    96,
                                                                    96,
                                                                    96,
                                                                    1)
                                                                : const Color
                                                                    .fromRGBO(
                                                                    96,
                                                                    96,
                                                                    96,
                                                                    1),
                                                            thumbColor: themeProvider
                                                                    .isDarkTheme
                                                                ? MyColors.white
                                                                : const Color
                                                                    .fromRGBO(
                                                                    29,
                                                                    29,
                                                                    33,
                                                                    1),
                                                          ),
                                                        ),
                                                      )),
                                                      Container(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width /
                                                            11,
                                                        alignment:
                                                            Alignment.center,
                                                        child: Text11(
                                                            text:
                                                                "$percentage%",
                                                            textColor: MyColors
                                                                .darkGray),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          0, 0, 0, 8),
                                                  child: SizedBox(
                                                    width:
                                                        MediaQuery.of(context)
                                                            .size
                                                            .width,
                                                    height: 2,
                                                    child: Container(
                                                      color: themeProvider
                                                              .isDarkTheme
                                                          ? MyColors.darkGray
                                                          : MyColors.black,
                                                    ),
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    GestureDetector(
                                                        onTap: () async {
                                                          await switchOrientation();
                                                        },
                                                        child: Icon(
                                                          CustomIcons.turn,
                                                          color:
                                                              Theme.of(context)
                                                                  .iconTheme
                                                                  .color,
                                                          size: 27,
                                                        )),
                                                    const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                                right: 30)),
                                                    InkWell(
                                                        onTap: () async {
                                                          final themeProvider =
                                                              Provider.of<
                                                                      ThemeProvider>(
                                                                  context,
                                                                  listen:
                                                                      false);
                                                          themeProvider
                                                                  .isDarkTheme =
                                                              !themeProvider
                                                                  .isDarkTheme;
                                                          await saveSettings(
                                                              themeProvider
                                                                  .isDarkTheme);
                                                        },
                                                        child: Icon(
                                                          CustomIcons.theme,
                                                          color:
                                                              Theme.of(context)
                                                                  .iconTheme
                                                                  .color,
                                                          size: 27,
                                                        )),
                                                    const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                                right: 30)),
                                                    GestureDetector(
                                                        onTap: () async {
                                                          toggleWordMode();
                                                        },
                                                        child: Column(
                                                          children: [
                                                            Icon(
                                                              CustomIcons.wm,
                                                              color: Theme.of(
                                                                      context)
                                                                  .iconTheme
                                                                  .color,
                                                              size: 27,
                                                            ),
                                                            const Text('Слово')
                                                          ],
                                                        )),
                                                  ],
                                                )
                                              ],
                                            )),
                                      )),
                                )
                              ],
                            ),
                          )
                        : BottomAppBar(
                            color: visible
                                ? Theme.of(context).colorScheme.primary
                                : backgroundColor,
                            height: visible ? 107 : 45,
                            child: Stack(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  height: visible ? 110 : 40,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: !visible
                                        ? [
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      0, 0, 0, 0),
                                              child: Container(
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width /
                                                    8,
                                                alignment: Alignment.topLeft,
                                                child: Stack(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  children: [
                                                    Transform.rotate(
                                                      angle:
                                                          90 * 3.14159265 / 180,
                                                      child: Icon(
                                                        Icons.battery_full,
                                                        color: themeProvider
                                                                .isDarkTheme
                                                            ? backgroundColor
                                                                        .value ==
                                                                    0xff1d1d21
                                                                ? MyColors.white
                                                                : MyColors.black
                                                            : backgroundColor
                                                                        .value !=
                                                                    0xff1d1d21
                                                                ? MyColors.black
                                                                : MyColors
                                                                    .white,
                                                        size: 28,
                                                      ),
                                                    ),
                                                    Text(
                                                      _batteryLevel.toInt() >=
                                                              100
                                                          ? '${_batteryLevel.toString()}%'
                                                          : ' ${_batteryLevel.toString()}%',
                                                      style: TextStyle(
                                                        color: themeProvider
                                                                .isDarkTheme
                                                            ? backgroundColor
                                                                        .value ==
                                                                    0xff1d1d21
                                                                ? MyColors.black
                                                                : MyColors.white
                                                            : backgroundColor
                                                                        .value !=
                                                                    0xff1d1d21
                                                                ? MyColors.white
                                                                : MyColors
                                                                    .black,
                                                        fontSize: 7,
                                                        fontFamily: 'Tektur',
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        0, 3, 0, 0),
                                                child: Align(
                                                  alignment:
                                                      Alignment.topCenter,
                                                  child: SingleChildScrollView(
                                                    scrollDirection:
                                                        Axis.horizontal,
                                                    child: Text(
                                                      book.customTitle
                                                                  .isNotEmpty &&
                                                              book.author
                                                                  .isNotEmpty
                                                          ? '${book.author.toString()}. ${book.customTitle.toString()}'
                                                          : 'Нет названия',
                                                      style: TextStyle(
                                                          color: themeProvider
                                                                  .isDarkTheme
                                                              ? backgroundColor
                                                                          .value ==
                                                                      0xff1d1d21
                                                                  ? MyColors
                                                                      .white
                                                                  : MyColors
                                                                      .black
                                                              : backgroundColor
                                                                          .value !=
                                                                      0xff1d1d21
                                                                  ? MyColors
                                                                      .black
                                                                  : MyColors
                                                                      .white,
                                                          fontFamily: 'Tektur',
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold),
                                                      textAlign:
                                                          TextAlign.center,
                                                      overflow:
                                                          TextOverflow.visible,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      0, 3, 10, 0),
                                              child: Container(
                                                width: MediaQuery.of(context)
                                                        .size
                                                        .width /
                                                    8,
                                                alignment: Alignment.topRight,
                                                child: Text(
                                                  '${percentage.toStringAsFixed(1)}%',
                                                  style: TextStyle(
                                                      color: themeProvider
                                                              .isDarkTheme
                                                          ? backgroundColor
                                                                      .value ==
                                                                  0xff1d1d21
                                                              ? MyColors.white
                                                              : MyColors.black
                                                          : backgroundColor
                                                                      .value !=
                                                                  0xff1d1d21
                                                              ? MyColors.black
                                                              : MyColors.white,
                                                      fontFamily: 'Tektur',
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          ]
                                        : [],
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      height: visible ? 97 : 0,
                                      child: SingleChildScrollView(
                                        child: Container(
                                            alignment:
                                                AlignmentDirectional.topEnd,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            child: Column(
                                              children: [
                                                SliderTheme(
                                                  data: const SliderThemeData(
                                                      showValueIndicator:
                                                          ShowValueIndicator
                                                              .always),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    children: [
                                                      Flexible(
                                                          child: SliderTheme(
                                                        data: const SliderThemeData(
                                                            trackHeight: 3,
                                                            thumbShape:
                                                                RoundSliderThumbShape(
                                                                    enabledThumbRadius:
                                                                        9),
                                                            trackShape:
                                                                RectangularSliderTrackShape()),
                                                        child: Container(
                                                          width: orientations[
                                                                          currentOrientationIndex] ==
                                                                      DeviceOrientation
                                                                          .landscapeLeft ||
                                                                  orientations[
                                                                          currentOrientationIndex] ==
                                                                      DeviceOrientation
                                                                          .landscapeRight
                                                              ? MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .width /
                                                                  1.19
                                                              : MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .width /
                                                                  1.12,
                                                          child: Slider(
                                                            value: percentage,
                                                            min: 0,
                                                            max: 100,
                                                            label:
                                                                "${percentage.toStringAsFixed(1)}%",
                                                            onChanged: (value) {
                                                              jumpToPercent(
                                                                  value);
                                                              setState(() {
                                                                percentage =
                                                                    value;
                                                              });
                                                            },
                                                            activeColor: themeProvider
                                                                    .isDarkTheme
                                                                ? MyColors.white
                                                                : const Color
                                                                    .fromRGBO(
                                                                    29,
                                                                    29,
                                                                    33,
                                                                    1),
                                                            inactiveColor: themeProvider
                                                                    .isDarkTheme
                                                                ? const Color
                                                                    .fromRGBO(
                                                                    96,
                                                                    96,
                                                                    96,
                                                                    1)
                                                                : const Color
                                                                    .fromRGBO(
                                                                    96,
                                                                    96,
                                                                    96,
                                                                    1),
                                                            thumbColor: themeProvider
                                                                    .isDarkTheme
                                                                ? MyColors.white
                                                                : const Color
                                                                    .fromRGBO(
                                                                    29,
                                                                    29,
                                                                    33,
                                                                    1),
                                                          ),
                                                        ),
                                                      )),
                                                      Container(
                                                        width: MediaQuery.of(
                                                                    context)
                                                                .size
                                                                .width /
                                                            11,
                                                        alignment:
                                                            Alignment.center,
                                                        child: Text11(
                                                            text:
                                                                "${percentage.toStringAsFixed(1)}%",
                                                            textColor: MyColors
                                                                .darkGray),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                          0, 0, 0, 8),
                                                  child: SizedBox(
                                                    width:
                                                        MediaQuery.of(context)
                                                            .size
                                                            .width,
                                                    height: 2,
                                                    child: Container(
                                                      color: themeProvider
                                                              .isDarkTheme
                                                          ? MyColors.darkGray
                                                          : MyColors.black,
                                                    ),
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    GestureDetector(
                                                        onTap: () async {
                                                          await switchOrientation();
                                                        },
                                                        child: Column(
                                                          children: [
                                                            Icon(
                                                              CustomIcons.turn,
                                                              color: Theme.of(
                                                                      context)
                                                                  .iconTheme
                                                                  .color,
                                                              size: 27,
                                                            ),
                                                            const Text(
                                                                'Поворот',
                                                                style:
                                                                    TextStyle(
                                                                  fontFamily:
                                                                      'Tektur',
                                                                  fontSize: 10,
                                                                ))
                                                          ],
                                                        )),
                                                    const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                                right: 23)),
                                                    InkWell(
                                                        onTap: () async {
                                                          final themeProvider =
                                                              Provider.of<
                                                                      ThemeProvider>(
                                                                  context,
                                                                  listen:
                                                                      false);
                                                          themeProvider
                                                                  .isDarkTheme =
                                                              !themeProvider
                                                                  .isDarkTheme;
                                                          await saveSettings(
                                                              themeProvider
                                                                  .isDarkTheme);
                                                        },
                                                        child:
                                                            Column(children: [
                                                          Icon(
                                                            CustomIcons.theme,
                                                            color: Theme.of(
                                                                    context)
                                                                .iconTheme
                                                                .color,
                                                            size: 27,
                                                          ),
                                                          const Text(
                                                            'Тема',
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'Tektur',
                                                              fontSize: 10,
                                                            ),
                                                          )
                                                        ])),
                                                    const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                                right: 30)),
                                                    GestureDetector(
                                                      onTap: () {
                                                        toggleWordMode();
                                                      },
                                                      child: Column(
                                                        children: [
                                                          Icon(
                                                            CustomIcons.wm,
                                                            color: Theme.of(
                                                                    context)
                                                                .iconTheme
                                                                .color,
                                                            size: 27,
                                                          ),
                                                          const Text('Слово',
                                                              style: TextStyle(
                                                                fontFamily:
                                                                    'Tektur',
                                                                fontSize: 10,
                                                              ))
                                                        ],
                                                      ),
                                                    ),
                                                    const Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                                right: 10)),
                                                  ],
                                                )
                                              ],
                                            )),
                                      )),
                                )
                              ],
                            )),
                  );
                })
            : Scaffold(
                body: Container(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ));
  }

  void jumpToPercent(double value) {
    final vall = value.floor() * text.length ~/ 100;
    _itemScrollController.jumpTo(
        index: vall, alignment: vall - vall.floorToDouble());
  }
}

class TextPos {
  int paragraph;
  double offset;

  TextPos({required this.paragraph, required this.offset});
}
