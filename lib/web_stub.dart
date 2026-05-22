import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

// Stubs so main.dart's desktop FFI calls compile on web (dead code, never reached)
void sqfliteFfiInit() {}
final databaseFactoryFfi = databaseFactoryFfiWeb; // harmless alias

Future<void> initDatabase() async {
  databaseFactory = databaseFactoryFfiWeb;
}
