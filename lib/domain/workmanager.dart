import 'dart:isolate';
import 'dart:ui';

import 'package:merlin/domain/scan_books_task.dart';
import 'package:workmanager/workmanager.dart';

// Mandatory if the App is obfuscated or using Flutter 3.1+
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    return switch (task) {
      ScanBooksTask.name => ScanBooksTask.run(),
      _ => Future.value(false)
    };
  });
}

void initWmPorts() {
  _wmScanBooksReceivePort = ReceivePort();
  wmScanBooksStream = _wmScanBooksReceivePort!.asBroadcastStream();
  IsolateNameServer.registerPortWithName(
      _wmScanBooksReceivePort!.sendPort, ScanBooksTask.name);
}

ReceivePort? _wmScanBooksReceivePort;
Stream? wmScanBooksStream;
