import 'package:sembast/sembast_memory.dart';
import 'package:sembast_sqflite/sembast_sqflite.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

class SembastProvider {
  static final _factory = getDatabaseFactorySqflite(sqflite.databaseFactory);
  static late final Database _db;

  SembastProvider._();

  static Database get instance => _db;

  static Future<void> init() async {
    _db = await _factory.openDatabase('fb2reader.db');
  }
}
