import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:accounting_app/data/storage_service.dart';

/// Schema v11 moves voucher numbering from globally unique to unique per
/// company and voucher type.
///
/// The rebuild drops and recreates Vouchers, and VoucherEntries hangs off it
/// with ON DELETE CASCADE — so the thing actually worth testing is that a
/// migration does not quietly take every line item with it.
void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_v11');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// A v10 database: the shape shipped before this change, including the
  /// global UNIQUE on voucher_number.
  Future<Database> openV10(String path) async {
    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 10,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE Settings (
              key TEXT PRIMARY KEY, value TEXT NOT NULL)
          ''');
          await db.execute('''
            CREATE TABLE Companies (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT, financial_year_from TEXT, books_from TEXT)
          ''');
          await db.execute('''
            CREATE TABLE Ledgers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              company_id INTEGER NOT NULL,
              name TEXT, classification TEXT, balance REAL DEFAULT 0,
              FOREIGN KEY (company_id) REFERENCES Companies(id) ON DELETE CASCADE)
          ''');
          await db.execute('''
            CREATE TABLE Vouchers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              company_id INTEGER NOT NULL,
              voucher_number TEXT UNIQUE,
              voucher_date TEXT, type TEXT, total REAL,
              FOREIGN KEY (company_id) REFERENCES Companies(id) ON DELETE CASCADE)
          ''');
          await db.execute('''
            CREATE TABLE VoucherEntries (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              voucher_id INTEGER NOT NULL,
              ledger_id INTEGER NOT NULL,
              description TEXT, debit REAL DEFAULT 0, credit REAL DEFAULT 0,
              FOREIGN KEY (voucher_id) REFERENCES Vouchers(id) ON DELETE CASCADE,
              FOREIGN KEY (ledger_id) REFERENCES Ledgers(id) ON DELETE CASCADE)
          ''');
        },
      ),
    );
  }

  test('the v11 rebuild keeps every voucher and every line item', () async {
    final path = '${tempDir.path}/books.db';

    final old = await openV10(path);
    final companyA = await old.insert('Companies', {'name': 'A'});
    final companyB = await old.insert('Companies', {'name': 'B'});
    final cash = await old.insert('Ledgers',
        {'company_id': companyA, 'name': 'Cash', 'classification': 'Cash-in-hand'});

    // Two vouchers with lines, and — because the old constraint was global —
    // company B could not reuse R1, so it had to take R2.
    final v1 = await old.insert('Vouchers', {
      'company_id': companyA,
      'voucher_number': 'R1',
      'voucher_date': '2026-05-01',
      'type': 'Receipt',
      'total': 100.0,
    });
    final v2 = await old.insert('Vouchers', {
      'company_id': companyB,
      'voucher_number': 'R2',
      'voucher_date': '2026-05-02',
      'type': 'Receipt',
      'total': 250.0,
    });
    for (final v in [v1, v2]) {
      await old.insert('VoucherEntries',
          {'voucher_id': v, 'ledger_id': cash, 'debit': 10.0, 'credit': 0.0});
      await old.insert('VoucherEntries',
          {'voucher_id': v, 'ledger_id': cash, 'debit': 0.0, 'credit': 10.0});
    }
    await old.close();

    // Reopen through the real app schema, which migrates and then finishes
    // the rebuild on open.
    final migrated = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 11,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onUpgrade: (db, from, to) async {
          await db.insert('Settings',
              {'key': 'pending_voucher_rebuild', 'value': '1'},
              conflictAlgorithm: ConflictAlgorithm.replace);
        },
        onOpen: StorageService.applyPendingRebuild,
      ),
    );

    // The whole point: cascade did not eat the line items.
    final vouchers = await migrated.query('Vouchers', orderBy: 'id');
    final entries = await migrated.query('VoucherEntries');
    expect(vouchers, hasLength(2), reason: 'both vouchers survived');
    expect(entries, hasLength(4), reason: 'no line item was cascaded away');
    expect(vouchers.first['voucher_number'], 'R1');
    expect((vouchers.last['total'] as num).toDouble(), 250.0);

    // The flag is cleared, so a later open does not rebuild again.
    final flag = await migrated.query('Settings',
        where: 'key = ?', whereArgs: ['pending_voucher_rebuild']);
    expect(flag, isEmpty);

    // Foreign keys are back on and still enforced.
    final fk = await migrated.rawQuery('PRAGMA foreign_keys');
    expect(fk.first.values.first, 1);

    await migrated.close();
  });

  test('after migrating, two companies can both hold R1', () async {
    final path = '${tempDir.path}/two.db';
    final old = await openV10(path);
    final companyA = await old.insert('Companies', {'name': 'A'});
    final companyB = await old.insert('Companies', {'name': 'B'});
    await old.insert('Vouchers', {
      'company_id': companyA,
      'voucher_number': 'R1',
      'voucher_date': '2026-05-01',
      'type': 'Receipt',
      'total': 100.0,
    });
    await old.close();

    final migrated = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 11,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onUpgrade: (db, from, to) async {
          await db.insert('Settings',
              {'key': 'pending_voucher_rebuild', 'value': '1'},
              conflictAlgorithm: ConflictAlgorithm.replace);
        },
        onOpen: StorageService.applyPendingRebuild,
      ),
    );

    // The old schema refused this outright. Each company numbers its own books.
    final id = await migrated.insert('Vouchers', {
      'company_id': companyB,
      'voucher_number': 'R1',
      'voucher_date': '2026-05-01',
      'type': 'Receipt',
      'total': 999.0,
    });
    expect(id, isPositive);

    // But one company still cannot reuse a number within a type.
    await expectLater(
      migrated.insert('Vouchers', {
        'company_id': companyB,
        'voucher_number': 'R1',
        'voucher_date': '2026-05-03',
        'type': 'Receipt',
        'total': 1.0,
      }),
      throwsA(isA<DatabaseException>()),
    );

    await migrated.close();
  });
}
