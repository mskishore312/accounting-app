import 'package:intl/intl.dart';

import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/financial_statement_service.dart';

/// Splits a company's books at a given date, Tally-style.
///
/// A new company is created whose books begin on the split date:
/// - Balance-sheet ledgers open with their closing balance as on the day
///   before the split date.
/// - Profit & Loss ledgers open at zero; their net effect up to the split
///   date is carried into a "Profit & Loss A/c" capital ledger so the new
///   company starts balanced.
/// - Vouchers dated on or after the split date are copied into the new
///   company (including GST invoice details and inventory lines).
/// The original company is left untouched.
class SplitCompanyService {
  static const List<String> _plGroups = [
    ...FinancialStatementService.purchaseGroups,
    ...FinancialStatementService.directExpenseGroups,
    ...FinancialStatementService.salesGroups,
    ...FinancialStatementService.directIncomeGroups,
    ...FinancialStatementService.indirectExpenseGroups,
    ...FinancialStatementService.indirectIncomeGroups,
  ];

  /// Returns the id of the newly created company.
  static Future<int> splitCompany({
    required int companyId,
    required DateTime splitDate,
  }) async {
    final db = await StorageService().database;
    final splitDateStr = DateFormat('yyyy-MM-dd').format(splitDate);
    final splitDateDisplay = DateFormat('dd/MM/yyyy').format(splitDate);

    final companies = await db
        .query('Companies', where: 'id = ?', whereArgs: [companyId], limit: 1);
    if (companies.isEmpty) {
      throw Exception('Company not found');
    }
    final company = companies.first;

    return await db.transaction<int>((txn) async {
      // 1. New company, books beginning on the split date
      final newCompany = Map<String, dynamic>.from(company)
        ..remove('id')
        ..['name'] = '${company['name']} (from $splitDateDisplay)'
        ..['books_from'] = splitDateDisplay
        ..['financial_year_from'] = splitDateDisplay;
      final newCompanyId = await txn.insert('Companies', newCompany);

      // 2. Account masters
      final masters = await txn.query('AccountMasters',
          where: 'company_id = ?', whereArgs: [companyId]);
      final masterIdMap = <int, int>{};
      for (final master in masters) {
        final newMaster = Map<String, dynamic>.from(master)
          ..remove('id')
          ..['company_id'] = newCompanyId;
        masterIdMap[master['id'] as int] =
            await txn.insert('AccountMasters', newMaster);
      }

      // 3. Ledgers with opening balances as on the split date
      final ledgers = await txn.query('Ledgers',
          where: 'company_id = ?', whereArgs: [companyId]);
      final ledgerIdMap = <int, int>{};
      double plNet = 0.0; // debit-signed net of P&L ledgers before split
      int? newPlLedgerId;

      for (final ledger in ledgers) {
        final ledgerId = ledger['id'] as int;
        final classification = ledger['classification'] as String? ?? '';
        final naturalOpening = (ledger['balance'] as num?)?.toDouble() ?? 0.0;
        final isDebit = FinancialStatementService.isDebitNature(classification);

        // Debit-signed running balance before the split date
        final sums = await txn.rawQuery('''
          SELECT COALESCE(SUM(ve.debit), 0) AS d, COALESCE(SUM(ve.credit), 0) AS c
          FROM VoucherEntries ve
          JOIN Vouchers v ON ve.voucher_id = v.id
          WHERE ve.ledger_id = ? AND v.voucher_date < ?
        ''', [ledgerId, splitDateStr]);
        final preSplit = ((sums.first['d'] as num).toDouble()) -
            ((sums.first['c'] as num).toDouble());
        final closing =
            (isDebit ? naturalOpening : -naturalOpening) + preSplit;

        double newOpening;
        if (_plGroups.contains(classification)) {
          plNet += closing;
          newOpening = 0.0;
        } else {
          // Store in the ledger's natural sign, as entered by users
          newOpening = isDebit ? closing : -closing;
        }

        final newLedger = Map<String, dynamic>.from(ledger)
          ..remove('id')
          ..['company_id'] = newCompanyId
          ..['balance'] = newOpening
          ..['account_master_id'] =
              masterIdMap[ledger['account_master_id'] as int?];
        final newId = await txn.insert('Ledgers', newLedger);
        ledgerIdMap[ledgerId] = newId;
        if (ledger['name'] == 'Profit & Loss A/c') {
          newPlLedgerId = newId;
        }
      }

      // 4. Carry accumulated profit/loss so the new company balances.
      // plNet is debit-signed: profit is negative (credit), loss positive.
      if (plNet.abs() > 0.005) {
        final plNatural = -plNet; // credit-nature capital ledger sign
        if (newPlLedgerId != null) {
          final existing = await txn.query('Ledgers',
              where: 'id = ?', whereArgs: [newPlLedgerId], limit: 1);
          final current =
              (existing.first['balance'] as num?)?.toDouble() ?? 0.0;
          await txn.update('Ledgers', {'balance': current + plNatural},
              where: 'id = ?', whereArgs: [newPlLedgerId]);
        } else {
          await txn.insert('Ledgers', {
            'company_id': newCompanyId,
            'name': 'Profit & Loss A/c',
            'classification': 'Capital Account',
            'balance': plNatural,
            'is_default': 1,
          });
        }
      }

      // 4b. Company settings and stock valuations carry over unchanged
      final settings = await txn.query('CompanySettings',
          where: 'company_id = ?', whereArgs: [companyId]);
      for (final setting in settings) {
        final newSetting = Map<String, dynamic>.from(setting)
          ..remove('id')
          ..['company_id'] = newCompanyId;
        await txn.insert('CompanySettings', newSetting);
      }
      for (final entry in ledgerIdMap.entries) {
        final valuations = await txn.query('StockValuations',
            where: 'ledger_id = ?', whereArgs: [entry.key]);
        for (final valuation in valuations) {
          final newValuation = Map<String, dynamic>.from(valuation)
            ..remove('id')
            ..['ledger_id'] = entry.value;
          await txn.insert('StockValuations', newValuation);
        }
      }

      // 5. Inventory items
      final items = await txn.query('InventoryItems',
          where: 'company_id = ?', whereArgs: [companyId]);
      final itemIdMap = <int, int>{};
      for (final item in items) {
        final newItem = Map<String, dynamic>.from(item)
          ..remove('id')
          ..['company_id'] = newCompanyId;
        itemIdMap[item['id'] as int] =
            await txn.insert('InventoryItems', newItem);
      }

      // 6. Vouchers on/after the split date, with entries and invoice data
      final vouchers = await txn.query('Vouchers',
          where: 'company_id = ? AND voucher_date >= ?',
          whereArgs: [companyId, splitDateStr]);
      for (final voucher in vouchers) {
        final oldVoucherId = voucher['id'] as int;
        final newVoucher = Map<String, dynamic>.from(voucher)
          ..remove('id')
          ..['company_id'] = newCompanyId;
        // voucher_number is globally unique; keep it recognizable
        final number = voucher['voucher_number'] as String?;
        if (number != null) {
          newVoucher['voucher_number'] = '$number/S';
        }
        final newVoucherId = await txn.insert('Vouchers', newVoucher);

        final entries = await txn.query('VoucherEntries',
            where: 'voucher_id = ?', whereArgs: [oldVoucherId]);
        for (final entry in entries) {
          final newEntry = Map<String, dynamic>.from(entry)
            ..remove('id')
            ..['voucher_id'] = newVoucherId
            ..['ledger_id'] = ledgerIdMap[entry['ledger_id'] as int];
          await txn.insert('VoucherEntries', newEntry);
        }

        final details = await txn.query('InvoiceDetails',
            where: 'voucher_id = ?', whereArgs: [oldVoucherId]);
        for (final detail in details) {
          final newDetail = Map<String, dynamic>.from(detail)
            ..['voucher_id'] = newVoucherId
            ..['party_ledger_id'] = ledgerIdMap[detail['party_ledger_id'] as int]
            ..['account_ledger_id'] =
                ledgerIdMap[detail['account_ledger_id'] as int];
          await txn.insert('InvoiceDetails', newDetail);
        }

        final lines = await txn.query('InvoiceLines',
            where: 'voucher_id = ?', whereArgs: [oldVoucherId]);
        for (final line in lines) {
          final newLine = Map<String, dynamic>.from(line)
            ..remove('id')
            ..['voucher_id'] = newVoucherId
            ..['inventory_item_id'] = line['inventory_item_id'] == null
                ? null
                : itemIdMap[line['inventory_item_id'] as int];
          await txn.insert('InvoiceLines', newLine);
        }
      }

      return newCompanyId;
    });
  }
}
