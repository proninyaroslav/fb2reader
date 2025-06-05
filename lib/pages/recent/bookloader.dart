// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';

// import 'package:merlin/pages/reader/reader.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:merlin/domain/books_repository.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookLoader {
  final booksRepo = BooksRepository();

  Future<void> loadImage() async {
    final prefs = await SharedPreferences.getInstance();

    var check = await requestStoragePermission();
    if (check == true) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: "Выберите книгу fb2",
        allowMultiple: false,
      );

      if (result?.count == null) {
        Fluttertoast.showToast(
          msg: 'Никакой файл не выбран',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        await prefs.setBool('success', false);
        return;
      }

      if (!BooksRepository.supportedExtensions
          .contains('.${result?.files.first.extension}')) {
        Fluttertoast.showToast(
          msg: 'Формат книги должен быть fb2 или zip',
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
        await prefs.setBool('success', false);
        return;
      }

      final saveResult = await booksRepo.save(result!.files.single.path!);
      switch (saveResult) {
        case SaveBookResultSuccess(:final title, :final hasCover):
          if (!hasCover) {
            Fluttertoast.showToast(
              msg: 'Книга не содержит обложку',
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
            );
          }
          await prefs.setString('fileTitle', title);
          await prefs.setBool('success', true);
        case SaveBookResultAlreadyExists(:final title):
          Fluttertoast.showToast(
            msg: 'Данная книга уже есть в приложении',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
          await prefs.setString('fileTitle', title);
          await prefs.setBool('success', true);
        case SaveBookResultInvalidFormat():
          return;
      }
    } else {
      Fluttertoast.showToast(
        msg: 'Вы не дали доступ к хранилищу',
        toastLength: Toast.LENGTH_SHORT, // Длительность отображения
        gravity: ToastGravity.BOTTOM, // Расположение уведомления
      );
      await prefs.setBool('success', false);
      return;
    }
  }

  requestStoragePermission() async {
    PermissionStatus status;
    if (Platform.isAndroid) {
      final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
      final AndroidDeviceInfo info = await deviceInfoPlugin.androidInfo;
      if ((info.version.sdkInt) >= 33) {
        status = await Permission.manageExternalStorage.request();
      } else {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.storage.request();
    }

    switch (status) {
      case PermissionStatus.denied:
        return false;
      case PermissionStatus.granted:
        return true;
      case PermissionStatus.restricted:
        return false;
      case PermissionStatus.limited:
        return true;
      case PermissionStatus.permanentlyDenied:
        return false;
      case PermissionStatus.provisional:
        return true;
    }
  }
}
