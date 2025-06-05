import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:merlin/functions/book.dart';
import 'package:merlin/functions/location.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

Future<DateTime?> getSavedDateTime() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? savedDateTimeString = prefs.getString('savedDateTime');
  if (savedDateTimeString != null) {
    return DateTime.parse(savedDateTimeString);
  }
  return null;
}

Future<double?> getPageSize() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  double? savedPageSize = prefs.getDouble('pageSize');
  if (savedPageSize != null) {
    return savedPageSize;
  }
  return null;
}

List<Book> books = [];

Future<List<Book>> processFiles(RootIsolateToken token) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);

  final Directory? externalDir = Platform.isAndroid
      ? await getExternalStorageDirectory()
      : await getApplicationDocumentsDirectory();
  final String path = '${externalDir?.path}/books';
  List<FileSystemEntity> files = await Directory(path).list().toList();
  List<Future<Book>> futures = [];

  for (FileSystemEntity file in files) {
    if (file is File) {
      Future<Book> futureBook = _readBookFromFile(file);
      futures.add(futureBook);
    }
  }

  List<Book> loadedBooks = await Future.wait(futures);

  // print('Длина списка с книжками ${books.length}');

  return loadedBooks;
}

Future<Book> _readBookFromFile(File file) async {
  try {
    String content = await file.readAsString();
    Map<String, dynamic> jsonMap = jsonDecode(content);
    Book book = Book.fromJson(jsonMap);
    return book;
  } catch (e) {
    // print('Error reading file: $e');
    return Book(
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

getPageCount(String inputFilePath, bool isWM) async {
  const FlutterSecureStorage storage = FlutterSecureStorage();
  String? tokenFromStorage;
  try {
    tokenFromStorage = await storage.read(key: 'token');
  } catch (e) {
    tokenFromStorage == null;
  }
  String token = '';
  if (tokenFromStorage != null) {
    token = tokenFromStorage;
  }
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  books.addAll(await compute(processFiles, RootIsolateToken.instance!));

  Map<double, bool> dataToSend = {};

  for (final entry in books) {
    Codec<String, String> stringToBase64 = utf8.fuse(base64);
    if (entry.title == inputFilePath) {
      double countFromStorage = prefs.getDouble(
              'pageCount-${stringToBase64.encode(entry.filePath)}') ??
          0;
      prefs.remove('pageCount-${entry.title}');
      double lastCountFromStorage =
          prefs.getDouble('lastPageCount-${entry.filePath}') ?? 0;
      double diff = countFromStorage - lastCountFromStorage;
      diff = diff < 0 ? 0 : diff;

      if (isWM == true) {
        if (countFromStorage > 0) {
          if (countFromStorage > lastCountFromStorage) {
            final dataToAdd = <double, bool>{diff: true};
            dataToSend.addEntries(dataToAdd.entries);
          } else {
            final dataToAdd = <double, bool>{0: true};
            dataToSend.addEntries(dataToAdd.entries);
          }
        }
      } else {
        if (countFromStorage > lastCountFromStorage) {
          final dataToAdd = <double, bool>{diff: false};
          dataToSend.addEntries(dataToAdd.entries);
        } else {
          final dataToAdd = <double, bool>{0: false};
          dataToSend.addEntries(dataToAdd.entries);
        }
      }
    }
  }
  books.clear();
  DateTime savedDateTime = await getSavedDateTime() ?? DateTime.now();
  DateTime nowDateTime = DateTime.now();
  Duration difference = nowDateTime.difference(savedDateTime);
  int differenceInSeconds = difference.inSeconds;

  int pageCountSimpleMode = 0;
  int pageCountWordMode = 0;
  String nowDataUTC = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ+00:00")
      .format(DateTime.now().toUtc());
  pageCountWordMode = 0;
  pageCountSimpleMode = 0;

  for (final entry in dataToSend.entries) {
    if (entry.value == true) {
      double speed = (entry.key * 1860) / differenceInSeconds;
      if (33.3 > speed) {
        pageCountWordMode = pageCountWordMode + entry.key.toInt();
      }
    }
    if (entry.value == false) {
      double speed = (entry.key * 1860) / differenceInSeconds;
      if (33.3 > speed) {
        pageCountSimpleMode = pageCountSimpleMode + entry.key.toInt();
      }
    }
  }

  // Fluttertoast.showToast(msg: 'pageSM: $pageCountSimpleMode | pageWM: $pageCountWordMode', toastLength: Toast.LENGTH_LONG);
  // print('pageSM: $pageCountSimpleMode | pageWM: $pageCountWordMode');
  String savedDataUTC = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ+00:00")
      .format(savedDateTime.toUtc());
  if (token == '') {
    if (prefs.getString("deviceId") == null) {
      saveDeviceIdToLocalStorage();
    }
    await postAnonymStatisticData(
        pageCountSimpleMode, pageCountWordMode, nowDataUTC, savedDataUTC);
  } else {
    await postUserStatisticData(token, pageCountSimpleMode, pageCountWordMode,
        nowDataUTC, savedDataUTC);
  }
}

void saveDeviceIdToLocalStorage() async {
  final prefs = await SharedPreferences.getInstance();
  var uuid = const Uuid();
  var deviceId = uuid.v4();
  await prefs.setString('deviceId', deviceId);
}

Future<void> postUserStatisticData(String token, int pageCountSimpleMode,
    int pageCountWordMode, String nowDataUTC, String savedDateUTC) async {
  if (pageCountSimpleMode > 0 || pageCountWordMode > 0) {
    final Map<String, dynamic> data = {
      "pageCountSimpleMode": pageCountSimpleMode,
      "pageCountWordMode": pageCountWordMode,
      "date": nowDataUTC,
      "startReading": savedDateUTC
    };
    // print(token);
    // print(data);
    final url = Uri.parse('https://app.merlin.su/statistic/user');
    // ignore: unused_local_variable
    final response = await http.post(
      url,
      headers: <String, String>{
        "User-Agent": "Merlin/1.0",
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    // print(response.body);
    if (response.statusCode == 200) {
      // print('Данные статистики ЮЗЕРА отправлены успешно! 200');
      // print("$pageCountSimpleMode, $pageCountWordMode");
    }
    if (response.statusCode == 201) {
      // print('Данные статистики ЮЗЕРА отправлены успешно! 201');
    } else {
      // print('Ошибка при отправке данных статистики ЮЗЕРА: ${response.reasonPhrase} (${response.statusCode})');
    }
  }
}

Future<void> postAnonymStatisticData(int pageCountSimpleMode,
    int pageCountWordMode, String nowDataUTC, String savedDateUTC) async {
  // print('Anonym func pagesSM $pageCountSimpleMode pagesWM $pageCountWordMode');
  if (pageCountSimpleMode > 0 || pageCountWordMode > 0) {
    final prefs = await SharedPreferences.getInstance();
    getLocation();
    String? location = prefs.getString('location');
    String? country, area, city;

    if (location != null) {
      List<String> locationParts = location.split(',');
      if (locationParts.length >= 3) {
        country = locationParts[0].trim();
        area = locationParts[1].trim();
        city = locationParts[2].trim();
      }
    }

    final Map<String, dynamic> data = {
      "deviceId": prefs.getString("deviceId"),
      "country": country,
      "area": area,
      "city": city,
      "pageCountSimpleMode": pageCountSimpleMode,
      "pageCountWordMode": pageCountWordMode,
      "date": nowDataUTC,
      "startReading": savedDateUTC
    };
    // print(data);
    final url = Uri.parse('https://app.merlin.su/statistic/anonym');
    // ignore: unused_local_variable
    final response = await http.post(
      url,
      headers: <String, String>{
        "User-Agent": "Merlin/1.0",
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );
    // print(response.body);
    if (response.statusCode == 200) {
      // print('Данные статистики и местоположения МЕРЛИНА отправлены успешно! 200');
      // print("принт $pageCountSimpleMode, $pageCountWordMode");
    }
    if (response.statusCode == 201) {
      // print('Данные статистики и местоположения МЕРЛИНА отправлены успешно! 201');
      // print("принт201 $pageCountSimpleMode, $pageCountWordMode");
    } else {
      // print('Ошибка при отправке данных статистики и местоположения МЕРЛИНА: ${response.reasonPhrase} (${response.statusCode})');
    }
  }
}
