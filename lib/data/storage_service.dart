import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  static Database? _database;
  static const String selectedCompanyKey = 'selected_company_id';

  StorageService._internal();

  factory StorageService() {
    return _instance;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String dbPath = await getDatabasesPath();
    String path = join(dbPath, 'accounting_app.db');
    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade
    );
  }

  // Database schema creation
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE Settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE Companies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        country TEXT,
        state TEXT,
        address TEXT,
        contact TEXT,
        tin TEXT,
        bank_name TEXT,
        bank_account TEXT,
        bank_ifsc TEXT,
        financial_year_from TEXT,
        books_from TEXT,
        security INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE AccountMasters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        classification TEXT,
        FOREIGN KEY (company_id) REFERENCES Companies(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Ledgers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_master_id INTEGER,
        company_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        classification TEXT,
        balance REAL DEFAULT 0,
        is_default INTEGER DEFAULT 0,
        FOREIGN KEY (company_id) REFERENCES Companies(id) ON DELETE CASCADE,
        FOREIGN KEY (account_master_id) REFERENCES AccountMasters(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE Vouchers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        voucher_number TEXT UNIQUE,
        voucher_date TEXT,
        type TEXT,
        total REAL,
        FOREIGN KEY (company_id) REFERENCES Companies(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE VoucherEntries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        voucher_id INTEGER NOT NULL,
        ledger_id INTEGER NOT NULL,
        description TEXT,
        debit REAL DEFAULT 0,
        credit REAL DEFAULT 0,
        FOREIGN KEY (voucher_id) REFERENCES Vouchers(id) ON DELETE CASCADE,
        FOREIGN KEY (ledger_id) REFERENCES Ledgers(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE CompanySettings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        key TEXT NOT NULL,
        value TEXT,
        FOREIGN KEY (company_id) REFERENCES Companies(id) ON DELETE CASCADE,
        UNIQUE(company_id, key)
      )
    ''');

    await db.execute('''
      CREATE TABLE StockValuations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ledger_id INTEGER NOT NULL,
        valuation_date TEXT NOT NULL,
        amount REAL NOT NULL,
        notes TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (ledger_id) REFERENCES Ledgers(id) ON DELETE CASCADE,
        UNIQUE(ledger_id, valuation_date)
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_company_name ON Companies(name)');
    await db.execute('CREATE INDEX idx_voucher_date ON Vouchers(voucher_date)');
    await db.execute('CREATE INDEX idx_company_settings ON CompanySettings(company_id, key)');
    await db.execute('CREATE INDEX idx_stock_valuations_date ON StockValuations(ledger_id, valuation_date)');
  }

  // Database schema upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE Companies ADD COLUMN security INTEGER DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE Ledgers ADD COLUMN is_default INTEGER DEFAULT 0');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE Ledgers ADD COLUMN classification TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS CompanySettings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          company_id INTEGER NOT NULL,
          key TEXT NOT NULL,
          value TEXT,
          FOREIGN KEY (company_id) REFERENCES Companies(id) ON DELETE CASCADE,
          UNIQUE(company_id, key)
        )
      ''');
    }
    if (oldVersion < 6) {
      // Create StockValuations table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS StockValuations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ledger_id INTEGER NOT NULL,
          valuation_date TEXT NOT NULL,
          amount REAL NOT NULL,
          notes TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (ledger_id) REFERENCES Ledgers(id) ON DELETE CASCADE,
          UNIQUE(ledger_id, valuation_date)
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_valuations_date ON StockValuations(ledger_id, valuation_date)');

      // Migrate existing stock ledgers with balances
      final stockLedgers = await db.query(
        'Ledgers',
        where: "classification = 'Stock-in-hand' AND balance > 0"
      );

      for (final ledger in stockLedgers) {
        // Get company's books_from date
        final companies = await db.query(
          'Companies',
          where: 'id = ?',
          whereArgs: [ledger['company_id']],
        );

        if (companies.isNotEmpty) {
          String booksFrom = companies.first['books_from'] as String? ?? DateTime.now().toIso8601String().split('T')[0];
          double balance = (ledger['balance'] as num?)?.toDouble() ?? 0.0;

          // Create initial valuation from existing balance
          await db.insert('StockValuations', {
            'ledger_id': ledger['id'],
            'valuation_date': booksFrom.split('T')[0], // Ensure YYYY-MM-DD format
            'amount': balance,
            'notes': 'Migrated from opening balance',
          });
        }
      }
    }
  }

  // Company operations
  static Future<int> saveCompany(Map<String, dynamic> company) async {
    final db = await _instance.database;
    if (company.containsKey('id')) {
      return await db.update(
        'Companies',
        company,
        where: 'id = ?',
        whereArgs: [company['id']]
      );
    }
    return await db.insert('Companies', company);
  }

  static Future<int> updateCompany(Map<String, dynamic> company) async {
    if (!company.containsKey('id')) {
      throw ArgumentError('Company must have an id for update');
    }
    return await saveCompany(company);
  }

  static Future<int> deleteCompany(int companyId) async {
    final db = await _instance.database;
    return await db.delete(
      'Companies',
      where: 'id = ?',
      whereArgs: [companyId]
    );
  }

  // Modified to accept optional transaction object
  static Future<Map<String, dynamic>?> getSelectedCompany([DatabaseExecutor? txn]) async {
    final db = txn ?? await _instance.database; // Use txn if provided
    final settings = await db.query(
      'Settings',
      where: 'key = ?',
      whereArgs: [selectedCompanyKey]
    );
    if (settings.isEmpty) return null;

    final companyId = int.tryParse(settings.first['value'] as String);
    if (companyId == null) return null;

    final companies = await db.query(
      'Companies',
      where: 'id = ?',
      whereArgs: [companyId]
    );
    return companies.isNotEmpty ? companies.first : null;
  }


  static Future<List<Map<String, dynamic>>> loadCompanies() async {
    final db = await _instance.database;
    return await db.query('Companies');
  }

  static Future<int> selectCompany(int companyId) async {
    final db = await _instance.database;
    await db.delete('Settings', where: 'key = ?', whereArgs: [selectedCompanyKey]);
    await db.insert('Settings', {
      'key': selectedCompanyKey,
      'value': companyId.toString()
    });
    return companyId;
  }

  static Future<void> clearSelectedCompany() async {
    final db = await _instance.database;
    await db.delete('Settings', where: 'key = ?', whereArgs: [selectedCompanyKey]);
  }

  // Company settings operations
  static Future<Map<String, dynamic>> getCompanySettings(int companyId) async {
    final db = await _instance.database;
    final settings = await db.query(
      'CompanySettings',
      where: 'company_id = ?',
      whereArgs: [companyId]
    );

    final settingsMap = <String, dynamic>{};
    for (final setting in settings) {
      settingsMap[setting['key'] as String] = setting['value'];
    }
    return settingsMap;
  }

  static Future<bool> saveCompanySettings(int companyId, Map<String, dynamic> settings) async {
    final db = await _instance.database;
    try {
      await db.transaction((txn) async {
        for (final entry in settings.entries) {
          await txn.insert(
            'CompanySettings',
            {
              'company_id': companyId,
              'key': entry.key,
              'value': entry.value.toString()
            },
            conflictAlgorithm: ConflictAlgorithm.replace
          );
        }
      });
      return true;
    } catch (e) {
      print('Error saving company settings: $e');
      return false;
    }
  }

  // Period management operations
  static Future<Map<String, dynamic>> getDefaultPeriodSettings(int companyId) async {
    final settings = await getCompanySettings(companyId);
    return {
      'period_type': settings['default_period_type'] ?? 'current_fy',
      'period_start': settings['default_period_start'],
      'period_end': settings['default_period_end'],
    };
  }

  static Future<bool> saveDefaultPeriodSettings(
    int companyId,
    String periodType,
    String? periodStart,
    String? periodEnd,
  ) async {
    final settings = <String, dynamic>{
      'default_period_type': periodType,
    };

    if (periodStart != null) {
      settings['default_period_start'] = periodStart;
    }
    if (periodEnd != null) {
      settings['default_period_end'] = periodEnd;
    }

    return await saveCompanySettings(companyId, settings);
  }

  // Ledger operations
  static Future<List<Map<String, dynamic>>> getLedgers([int? companyId]) async {
    if (companyId == null) {
      final comp = await getSelectedCompany();
      companyId = comp?['id'] as int? ?? 0;
    }
    final db = await _instance.database;
    return await db.query('Ledgers', where: 'company_id = ?', whereArgs: [companyId]);
  }

  static Future<int> saveLedger(Map<String, dynamic> ledger) async {
    final db = await _instance.database;
    if (ledger.containsKey('id')) {
      return await db.update(
        'Ledgers',
        ledger,
        where: 'id = ?',
        whereArgs: [ledger['id']]
      );
    }
    return await db.insert('Ledgers', ledger);
  }

  static Future<Map<String, dynamic>> deleteLedger(int ledgerId) async {
    final db = await _instance.database;
    final count = await db.rawQuery('''
      SELECT COUNT(*) as count FROM VoucherEntries
      WHERE ledger_id = ?
    ''', [ledgerId]);

    if ((count.first['count'] as int) > 0) {
      return {
        'success': false,
        'message': 'Cannot delete ledger with existing transactions'
      };
    }

    final deleted = await db.delete(
      'Ledgers',
      where: 'id = ?',
      whereArgs: [ledgerId]
    );

    return {
      'success': deleted > 0,
      'count': deleted
    };
  }

  // Account master operations
  static Future<int> insertAccountMaster(Map<String, dynamic> master) async {
    final db = await _instance.database;
    return await db.insert('AccountMasters', master);
  }

  static Future<int> insertLedger(Map<String, dynamic> ledger) async {
    final db = await _instance.database;
    return await db.insert('Ledgers', ledger);
  }

  // Voucher operations
  static Future<List<Map<String, dynamic>>> getVouchers([int? companyId, String? type]) async {
    if (companyId == null) {
      final comp = await getSelectedCompany();
      companyId = comp?['id'] as int? ?? 0;
    }
    final db = await _instance.database;

    if (type != null) {
      return await db.query(
        'Vouchers',
        where: 'company_id = ? AND type = ?',
        whereArgs: [companyId, type]
      );
    }
    return await db.query(
      'Vouchers',
      where: 'company_id = ?',
      whereArgs: [companyId]
    );
  }

  static Future<List<Map<String, dynamic>>> getVoucherEntries(int voucherId) async {
    final db = await _instance.database;
    return await db.query(
      'VoucherEntries',
      where: 'voucher_id = ?',
      whereArgs: [voucherId]
    );
  }

  // Get voucher by ID with all details and entries
  static Future<Map<String, dynamic>?> getVoucherById(int voucherId) async {
    final db = await _instance.database;
    
    // Get voucher details
    final voucherResult = await db.query(
      'Vouchers',
      where: 'id = ?',
      whereArgs: [voucherId]
    );
    
    if (voucherResult.isEmpty) return null;
    
    final voucher = Map<String, dynamic>.from(voucherResult.first);
    
    // Get voucher entries with ledger details
    final entriesResult = await db.rawQuery('''
      SELECT ve.*, l.name as ledger_name
      FROM VoucherEntries ve
      JOIN Ledgers l ON ve.ledger_id = l.id
      WHERE ve.voucher_id = ?
      ORDER BY ve.id
    ''', [voucherId]);
    
    voucher['entries'] = entriesResult;
    return voucher;
  }

  static Future<int> deleteVouchers(dynamic voucherIds) async {
    final db = await _instance.database;
    int deletedCount = 0;

    if (voucherIds is int) {
      deletedCount = await db.delete(
        'Vouchers',
        where: 'id = ?',
        whereArgs: [voucherIds]
      );
    } else if (voucherIds is List<int>) {
      for (final id in voucherIds) {
        deletedCount += await db.delete(
          'Vouchers',
          where: 'id = ?',
          whereArgs: [id]
        );
      }
    }

    return deletedCount;
  }

  // Voucher number operations
  static Future<String> getNextVoucherNumber(String voucherType) async {
    final db = await _instance.database;
    final company = await getSelectedCompany();
    final companyId = company?['id'] as int? ?? 0;

    String prefix = '';
    switch (voucherType.toLowerCase()) {
      case 'receipt': prefix = 'R'; break;
      case 'payment': prefix = 'P'; break;
      case 'journal': prefix = 'J'; break;
      default: prefix = 'V';
    }

    final result = await db.rawQuery('''
      SELECT voucher_number FROM Vouchers
      WHERE company_id = ? AND type = ? AND voucher_number LIKE '$prefix%'
      ORDER BY CAST(SUBSTR(voucher_number, 2) AS INTEGER) DESC
      LIMIT 1
    ''', [companyId, voucherType]);

    int nextNumber = 1;
    if (result.isNotEmpty) {
      final lastNumber = result.first['voucher_number'] as String;
      final numStr = lastNumber.substring(1);
      nextNumber = (int.tryParse(numStr) ?? 0) + 1;
    }

    return '$prefix$nextNumber';
  }

  static Future<bool> isVoucherNumberUnique(String voucherNumber) async {
    final db = await _instance.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM Vouchers
      WHERE voucher_number = ?
    ''', [voucherNumber]);

    return (result.first['count'] as int) == 0;
  }

  // Updated saveVoucher to accept optional transaction
  static Future<int> saveVoucher(Map<String, dynamic> voucher, [DatabaseExecutor? txn]) async {
    final db = txn ?? await _instance.database; // Use transaction or default db
    int resultId = -1;

    if (voucher.containsKey('id') && voucher['id'] != null) {
      // Update existing voucher
      final id = voucher['id'] as int;
      final Map<String, dynamic> updateData = Map.from(voucher);
      updateData.remove('id'); // Don't try to update the id column itself

      int updatedRows = await db.update(
        'Vouchers',
        updateData,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (updatedRows > 0) {
        resultId = id; // Return the existing ID on successful update
      } else {
        // Handle update failure (optional: throw exception or log error)
        print('Error: Failed to update voucher with ID $id');
        throw Exception('Failed to update voucher');
      }
    } else {
      // Insert new voucher
      // Ensure required fields are present for insert
      final Map<String, dynamic> insertData = {
        'company_id': voucher['company_id'],
        'voucher_number': voucher['voucher_number'],
        'voucher_date': voucher['voucher_date'],
        'type': voucher['type'],
        'total': voucher['total']
      };
      try {
        resultId = await db.insert(
          'Vouchers',
          insertData,
          conflictAlgorithm: ConflictAlgorithm.fail, // Ensure unique constraint is checked
        );
      } catch (e) {
         print('Error inserting voucher: $e');
         // Re-throw the exception to be caught by the UI
         throw Exception('Failed to insert voucher: $e');
      }
    }

    return resultId; // Return the ID (new or existing)
  }

  // New function to get receipt vouchers with credit ledger name as particulars
  // This function reads data, so it doesn't need transaction support typically.
  static Future<List<Map<String, dynamic>>> getReceiptVouchersWithParticulars([int? companyId]) async {
    if (companyId == null) {
      final comp = await getSelectedCompany();
      companyId = comp?['id'] as int? ?? 0;
    }
    final db = await _instance.database;
    // Join Vouchers with VoucherEntries and Ledgers, get the name of the first credit ledger as particulars
    return await db.rawQuery('''
      SELECT
        v.id,
        v.voucher_number,
        v.voucher_date,
        v.type,
        v.total,
        (SELECT l.name
         FROM VoucherEntries ve_sub
         JOIN Ledgers l ON ve_sub.ledger_id = l.id
         WHERE ve_sub.voucher_id = v.id AND ve_sub.credit > 0
         ORDER BY ve_sub.id -- Get the first credit entry based on its ID
         LIMIT 1) as particulars
      FROM Vouchers v
      WHERE v.company_id = ?
        AND v.type = 'Receipt'
      -- No need to join VoucherEntries/Ledgers here directly, handled by subquery
      -- No need to filter ve.credit > 0 here, handled by subquery
      GROUP BY v.id -- Group by voucher ID to get one row per voucher
      ORDER BY v.voucher_date ASC, v.id ASC -- Order chronologically (oldest first)
    ''', [companyId]);
  }

  // New function to get payment vouchers with debit ledger name as particulars
  static Future<List<Map<String, dynamic>>> getPaymentVouchersWithParticulars([int? companyId]) async {
    if (companyId == null) {
      final comp = await getSelectedCompany();
      companyId = comp?['id'] as int? ?? 0;
    }
    final db = await _instance.database;
    // Join Vouchers with VoucherEntries and Ledgers, get the name of the first debit ledger as particulars
    return await db.rawQuery('''
      SELECT
        v.id,
        v.voucher_number,
        v.voucher_date,
        v.type,
        v.total,
        (SELECT l.name
         FROM VoucherEntries ve_sub
         JOIN Ledgers l ON ve_sub.ledger_id = l.id
         WHERE ve_sub.voucher_id = v.id AND ve_sub.debit > 0 -- Filter for DEBIT entries
         ORDER BY ve_sub.id -- Get the first debit entry based on its ID
         LIMIT 1) as particulars
      FROM Vouchers v
      WHERE v.company_id = ?
        AND v.type = 'Payment' -- Filter for Payment type
      GROUP BY v.id -- Group by voucher ID to get one row per voucher
      ORDER BY v.voucher_date ASC, v.id ASC -- Order chronologically (oldest first)
    ''', [companyId]);
  }


  // Updated deleteVoucherEntries to accept optional transaction
  static Future<int> deleteVoucherEntries(int voucherId, [DatabaseExecutor? txn]) async {
    final db = txn ?? await _instance.database; // Use transaction or default db
    return await db.delete(
      'VoucherEntries',
      where: 'voucher_id = ?',
      whereArgs: [voucherId]
    );
  }

  // Updated insertVoucherEntry to accept optional transaction
  static Future<int> insertVoucherEntry(Map<String, dynamic> entry, [DatabaseExecutor? txn]) async {
    final db = txn ?? await _instance.database; // Use transaction or default db
    return await db.insert('VoucherEntries', entry);
  }


  // Report operations
  static Future<List<Map<String, dynamic>>> getLedgerReport(int ledgerId) async {
    final db = await _instance.database;
    // Fetch entries for the target ledger. Determine particulars based on contra entry.
    return await db.rawQuery('''
      SELECT
        ve.id as entry_id, -- Include entry id for potential detailed linking
        v.id AS voucher_id,
        v.voucher_date,
        v.voucher_number,
        v.type AS voucher_type,
        ve.debit,  -- This is the debit amount FOR THIS LEDGER's entry
        ve.credit, -- This is the credit amount FOR THIS LEDGER's entry
        ve.description,
        -- Final Particulars Logic V7: Explicitly find first contra based on debit/credit
        ( SELECT contr_l.name
          FROM VoucherEntries contr_ve
          JOIN Ledgers contr_l ON contr_ve.ledger_id = contr_l.id
          WHERE contr_ve.voucher_id = v.id -- Same voucher
            AND contr_ve.ledger_id != ve.ledger_id -- Different ledger
            -- Match contra type: If ve is debit, find first credit contra. If ve is credit, find first debit contra.
            AND ( (ve.debit > 0 AND contr_ve.credit > 0) OR (ve.credit > 0 AND contr_ve.debit > 0) )
          ORDER BY contr_ve.id ASC -- Get the first one consistently
          LIMIT 1
        ) AS particulars
      FROM VoucherEntries ve
      JOIN Vouchers v ON ve.voucher_id = v.id
      WHERE ve.ledger_id = ? -- Filter for the specific ledger being viewed
      ORDER BY v.voucher_date ASC, v.id ASC -- Order chronologically
    ''', [ledgerId]);
  }

  // Function to calculate the current balance of a specific ledger
  static Future<double> getLedgerBalance(int ledgerId) async {
    final db = await _instance.database;
    // Sum all debits and credits for the given ledger
    final result = await db.rawQuery('''
      SELECT SUM(debit) as totalDebit, SUM(credit) as totalCredit
      FROM VoucherEntries
      WHERE ledger_id = ?
    ''', [ledgerId]);

    if (result.isNotEmpty) {
      final totalDebit = (result.first['totalDebit'] as num?)?.toDouble() ?? 0.0;
      final totalCredit = (result.first['totalCredit'] as num?)?.toDouble() ?? 0.0;
      // Assuming Debit balance is positive, Credit balance is negative
      return totalDebit - totalCredit;
    }
    return 0.0; // Return 0 if no entries found
  }


  static Future<List<Map<String, dynamic>>> getDaybook([int? companyId]) async {
    if (companyId == null) {
      final comp = await getSelectedCompany();
      companyId = comp?['id'] as int? ?? 0;
    }
    final db = await _instance.database;
    return await db.rawQuery('''
      SELECT v.*,
        (SELECT GROUP_CONCAT(l.name, ', ')
         FROM VoucherEntries ve
         JOIN Ledgers l ON ve.ledger_id = l.id
         WHERE ve.voucher_id = v.id) as ledgers
      FROM Vouchers v
      WHERE v.company_id = ?
      ORDER BY v.voucher_date, v.id
    ''', [companyId]);
  }

  // Get ledger balance after a hypothetical transaction (for negative balance warning)
  static Future<double> getLedgerBalanceAfterTransaction(int ledgerId, double additionalCredit) async {
    final currentBalance = await getLedgerBalance(ledgerId);
    return currentBalance - additionalCredit; // Subtract credit amount from current balance
  }

  static Future<void> checkAndFixDatabaseSchema() async {
    final db = await _instance.database;
    try {
      await db.execute('PRAGMA foreign_keys = ON');
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'"
      );
      if (!tables.any((t) => t['name'] == 'VoucherEntries')) {
        await _instance._onCreate(db, 6);
      }
    } catch (e) {
      print('Error checking database schema: $e');
    }
  }

  // Stock Valuation operations
  static Future<int> saveStockValuation(Map<String, dynamic> valuation) async {
    final db = await _instance.database;

    if (valuation.containsKey('id') && valuation['id'] != null) {
      // Update existing valuation
      return await db.update(
        'StockValuations',
        valuation,
        where: 'id = ?',
        whereArgs: [valuation['id']]
      );
    }

    // Insert new valuation
    return await db.insert(
      'StockValuations',
      valuation,
      conflictAlgorithm: ConflictAlgorithm.replace
    );
  }

  static Future<List<Map<String, dynamic>>> getStockValuations(int ledgerId) async {
    final db = await _instance.database;
    return await db.query(
      'StockValuations',
      where: 'ledger_id = ?',
      whereArgs: [ledgerId],
      orderBy: 'valuation_date ASC'
    );
  }

  static Future<Map<String, dynamic>?> getStockValuationForDate(
    int ledgerId,
    String targetDate  // Format: YYYY-MM-DD
  ) async {
    final db = await _instance.database;
    // Get the latest valuation on or before the target date
    final result = await db.rawQuery('''
      SELECT * FROM StockValuations
      WHERE ledger_id = ? AND valuation_date <= ?
      ORDER BY valuation_date DESC
      LIMIT 1
    ''', [ledgerId, targetDate]);

    return result.isNotEmpty ? result.first : null;
  }

  static Future<int> deleteStockValuation(int valuationId) async {
    final db = await _instance.database;
    return await db.delete(
      'StockValuations',
      where: 'id = ?',
      whereArgs: [valuationId]
    );
  }
}
