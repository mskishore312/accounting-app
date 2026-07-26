import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:accounting_app/data/storage_service.dart';

/// Handles backup, restore and emergency (local) backups of the app database.
class BackupService {
  static const String _emergencyDirName = 'emergency_backups';
  static const int _maxEmergencyBackups = 10;

  static String _timestamp() =>
      DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

  static String backupFileName() => 'tompa_backup_${_timestamp()}.db';

  /// Read the current database file, flushing pending writes first.
  static Future<Uint8List> _readDatabaseBytes() async {
    final path = await StorageService.getDatabaseFilePath();
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('No database found to back up');
    }
    // Close so the file on disk is consistent, then reopen lazily on next use.
    await StorageService.closeDatabase();
    return await file.readAsBytes();
  }

  static bool _isSqliteDatabase(Uint8List bytes) {
    const header = 'SQLite format 3';
    if (bytes.length < header.length) return false;
    for (var i = 0; i < header.length; i++) {
      if (bytes[i] != header.codeUnitAt(i)) return false;
    }
    return true;
  }

  /// Save a backup to a user-chosen location. Returns the saved path, or
  /// null if the user cancelled.
  static Future<String?> backupToFile() async {
    final bytes = await _readDatabaseBytes();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Backup',
      fileName: backupFileName(),
      bytes: bytes,
    );
    return path;
  }

  /// Share the backup via the system share sheet (mail, drive, etc.).
  static Future<void> backupAndShare({String? subject}) async {
    final bytes = await _readDatabaseBytes();
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, backupFileName()));
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/octet-stream')],
      subject: subject ?? 'TOM-PA Backup ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
      text: 'TOM-PA accounting data backup. Keep this file safe.',
    );
  }

  /// Restore the database from a user-picked backup file.
  /// A safety copy of the current database is written first.
  static Future<void> restoreFromPickedFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) {
      throw const RestoreCancelled();
    }
    final picked = result.files.single;
    Uint8List? bytes = picked.bytes;
    if (bytes == null && picked.path != null) {
      bytes = await File(picked.path!).readAsBytes();
    }
    if (bytes == null) {
      throw Exception('Could not read the selected file');
    }
    if (!_isSqliteDatabase(bytes)) {
      throw Exception('The selected file is not a valid TOM-PA backup');
    }
    await _replaceDatabase(bytes);
  }

  static Future<void> _replaceDatabase(Uint8List bytes) async {
    final dbPath = await StorageService.getDatabaseFilePath();
    await StorageService.closeDatabase();
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      // Keep a safety copy of what we are overwriting.
      await dbFile.copy('$dbPath.pre_restore');
      // Remove stale WAL/journal files so SQLite doesn't mix old pages in.
      for (final suffix in ['-wal', '-shm', '-journal']) {
        final side = File('$dbPath$suffix');
        if (await side.exists()) await side.delete();
      }
    } else {
      await dbFile.parent.create(recursive: true);
    }
    await dbFile.writeAsBytes(bytes, flush: true);
  }

  static Future<Directory> _emergencyDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _emergencyDirName));
    await dir.create(recursive: true);
    return dir;
  }

  /// One-tap local backup into the app's documents folder.
  /// Keeps at most [_maxEmergencyBackups] copies. Returns the saved path.
  static Future<String> emergencyBackup() async {
    final bytes = await _readDatabaseBytes();
    final dir = await _emergencyDir();
    final file = File(p.join(dir.path, backupFileName()));
    await file.writeAsBytes(bytes, flush: true);

    final backups = await listEmergencyBackups();
    for (var i = _maxEmergencyBackups; i < backups.length; i++) {
      try {
        await backups[i].delete();
      } catch (_) {}
    }
    return file.path;
  }

  /// Emergency backups, newest first.
  static Future<List<File>> listEmergencyBackups() async {
    final dir = await _emergencyDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // timestamped names
    return files;
  }

  static Future<void> restoreFromEmergencyBackup(File backup) async {
    final bytes = await backup.readAsBytes();
    if (!_isSqliteDatabase(bytes)) {
      throw Exception('The backup file is corrupted');
    }
    await _replaceDatabase(bytes);
  }
}

/// Thrown when the user cancels a restore file selection.
class RestoreCancelled implements Exception {
  const RestoreCancelled();
}
