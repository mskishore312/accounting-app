import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/financial_statement_service.dart';

/// Full financial-statement check with a realistic company.
///
/// Sharma Trading Co, FY 2026-27 (books from 01/04/2026).
///
/// Opening balances: Cash 50,000 Dr; HDFC Bank 200,000 Dr;
/// Capital 250,000 Cr.
///
/// Transactions:
///  02/04 Furniture bought by bank             40,000
///  05/04 Purchase invoice (Ravi Suppliers)   100,000 + 9,000 CGST + 9,000 SGST
///  10/04 Sales invoice (Mehta Stores)         80,000 + 7,200 CGST + 7,200 SGST
///  15/04 Rent paid by bank                    15,000
///  20/04 Salaries paid by bank                25,000
///  25/04 Receipt from Mehta Stores by bank    50,000
///  01/05 Paid Ravi Suppliers by bank          60,000
///  05/05 Sales invoice (Mehta Stores)         70,000 + 6,300 CGST + 6,300 SGST
///  10/05 Wages paid in cash                   10,000
///  31/05 Journal: depreciation on furniture    2,000
///  Closing stock valued at 30,000 on 31/03/2027.
///
/// Expected statements (hand-computed):
///  Trading: GP = 150,000 sales + 30,000 closing stock
///               - 100,000 purchases - 10,000 wages          =  70,000
///  P&L: NP = 70,000 - (15,000 rent + 25,000 salaries
///               + 2,000 depreciation)                       =  28,000
///  Balance Sheet (31/03/2027):
///   Assets: furniture 38,000 + stock 30,000 + debtors 127,000
///          + cash 40,000 + bank 110,000                     = 345,000
///   Liabilities: capital 250,000 + creditors 58,000
///          + net GST payable 9,000 (27,000 output
///          - 18,000 input) + net profit 28,000              = 345,000
void main() {
  late Directory tempDir;
  late int companyId;
  final ids = <String, int>{};

  final start = DateTime(2026, 4, 1);
  final end = DateTime(2027, 3, 31);
  // Exactly what the app stores and the screens pass through: the
  // company's books_from field, in the app's display format.
  const booksFrom = '01/04/2026';

  Future<void> voucher(String type, String date, double total,
      List<(String, double, double)> entries) async {
    final number = await StorageService.getNextVoucherNumber(type);
    final db = await StorageService().database;
    await db.transaction((txn) async {
      final id = await StorageService.saveVoucher({
        'company_id': companyId,
        'voucher_number': number,
        'voucher_date': date,
        'type': type,
        'total': total,
      }, txn);
      for (final (ledger, debit, credit) in entries) {
        await StorageService.insertVoucherEntry({
          'voucher_id': id,
          'ledger_id': ids[ledger],
          'description': '',
          'debit': debit,
          'credit': credit,
        }, txn);
      }
    });
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('fin_stmt_test');
    await databaseFactory.setDatabasesPath(tempDir.path);

    companyId = await StorageService.saveCompany({
      'name': 'Sharma Trading Co',
      'country': 'India',
      'state': 'Karnataka',
      'financial_year_from': '01/04/2026',
      'books_from': '01/04/2026',
    });
    await StorageService.selectCompany(companyId);

    const ledgers = {
      'Cash': ('Cash-in-hand', 50000.0),
      'HDFC Bank': ('Bank Accounts', 200000.0),
      'Capital': ('Capital Account', 250000.0),
      'Purchases': ('Purchase Accounts', 0.0),
      'Sales': ('Sales Accounts', 0.0),
      'Wages': ('Direct Expenses', 0.0),
      'Rent': ('Indirect Expenses', 0.0),
      'Salaries': ('Indirect Expenses', 0.0),
      'Depreciation': ('Indirect Expenses', 0.0),
      'Furniture': ('Fixed Assets', 0.0),
      'Mehta Stores': ('Sundry Debtors', 0.0),
      'Ravi Suppliers': ('Sundry Creditors', 0.0),
      'Stock-in-Hand': ('Stock-in-hand', 0.0),
    };
    for (final entry in ledgers.entries) {
      ids[entry.key] = await StorageService.saveLedger({
        'company_id': companyId,
        'name': entry.key,
        'classification': entry.value.$1,
        'balance': entry.value.$2,
      });
    }

    // 02/04 Furniture bought by bank
    await voucher('Payment', '2026-04-02', 40000, [
      ('Furniture', 40000, 0),
      ('HDFC Bank', 0, 40000),
    ]);
    // 05/04 GST purchase from Ravi Suppliers
    await StorageService.saveInvoiceVoucher(
      type: 'Purchase',
      voucherNumber: await StorageService.getNextVoucherNumber('Purchase'),
      voucherDate: '2026-04-05',
      invoiceMode: 'Accounting',
      partyLedgerId: ids['Ravi Suppliers']!,
      accountLedgerId: ids['Purchases']!,
      placeOfSupply: 'Karnataka',
      narration: 'Goods purchased',
      lines: [
        {
          'description': 'Goods',
          'quantity': 1.0,
          'rate': 100000.0,
          'taxable_value': 100000.0,
          'gst_rate': 18.0,
          'cgst': 9000.0,
          'sgst': 9000.0,
          'igst': 0.0,
        },
      ],
    );
    // 10/04 GST sale to Mehta Stores
    await StorageService.saveInvoiceVoucher(
      type: 'Sales',
      voucherNumber: await StorageService.getNextVoucherNumber('Sales'),
      voucherDate: '2026-04-10',
      invoiceMode: 'Accounting',
      partyLedgerId: ids['Mehta Stores']!,
      accountLedgerId: ids['Sales']!,
      placeOfSupply: 'Karnataka',
      narration: 'Goods sold',
      lines: [
        {
          'description': 'Goods',
          'quantity': 1.0,
          'rate': 80000.0,
          'taxable_value': 80000.0,
          'gst_rate': 18.0,
          'cgst': 7200.0,
          'sgst': 7200.0,
          'igst': 0.0,
        },
      ],
    );
    // 15/04 Rent, 20/04 Salaries by bank
    await voucher('Payment', '2026-04-15', 15000, [
      ('Rent', 15000, 0),
      ('HDFC Bank', 0, 15000),
    ]);
    await voucher('Payment', '2026-04-20', 25000, [
      ('Salaries', 25000, 0),
      ('HDFC Bank', 0, 25000),
    ]);
    // 25/04 Receipt from debtor
    await voucher('Receipt', '2026-04-25', 50000, [
      ('HDFC Bank', 50000, 0),
      ('Mehta Stores', 0, 50000),
    ]);
    // 01/05 Payment to creditor
    await voucher('Payment', '2026-05-01', 60000, [
      ('Ravi Suppliers', 60000, 0),
      ('HDFC Bank', 0, 60000),
    ]);
    // 05/05 Second GST sale
    await StorageService.saveInvoiceVoucher(
      type: 'Sales',
      voucherNumber: await StorageService.getNextVoucherNumber('Sales'),
      voucherDate: '2026-05-05',
      invoiceMode: 'Accounting',
      partyLedgerId: ids['Mehta Stores']!,
      accountLedgerId: ids['Sales']!,
      placeOfSupply: 'Karnataka',
      narration: 'Goods sold',
      lines: [
        {
          'description': 'Goods',
          'quantity': 1.0,
          'rate': 70000.0,
          'taxable_value': 70000.0,
          'gst_rate': 18.0,
          'cgst': 6300.0,
          'sgst': 6300.0,
          'igst': 0.0,
        },
      ],
    );
    // 10/05 Wages in cash
    await voucher('Payment', '2026-05-10', 10000, [
      ('Wages', 10000, 0),
      ('Cash', 0, 10000),
    ]);
    // 31/05 Depreciation journal
    await voucher('Journal', '2026-05-31', 2000, [
      ('Depreciation', 2000, 0),
      ('Furniture', 0, 2000),
    ]);
    // Closing stock valuation
    await StorageService.saveStockValuation({
      'ledger_id': ids['Stock-in-Hand'],
      'valuation_date': '2027-03-31',
      'amount': 30000.0,
    });

    // GST ledgers were auto-created by the invoices
    final all = await StorageService.getLedgers(companyId);
    for (final name in [
      'Input CGST',
      'Input SGST',
      'Output CGST',
      'Output SGST'
    ]) {
      ids[name] = all.firstWhere((l) => l['name'] == name)['id'] as int;
    }
  });

  tearDownAll(() async {
    await StorageService.closeDatabase();
    await tempDir.delete(recursive: true);
  });

  test('individual ledger closing balances match hand computation', () async {
    final ledgers = await StorageService.getLedgers(companyId);
    Future<double> balance(String name) async {
      final ledger = ledgers.firstWhere((l) => l['name'] == name);
      return FinancialStatementService.calculateLedgerBalance(
        ledgerId: ledger['id'] as int,
        ledger: ledger,
        startDate: start,
        endDate: end,
        booksBeginningDate: booksFrom,
      );
    }

    expect(await balance('Cash'), 40000.0); // 50,000 - 10,000 wages
    expect(await balance('HDFC Bank'),
        110000.0); // 200,000 - 40,000 - 15,000 - 25,000 + 50,000 - 60,000
    expect(await balance('Capital'), -250000.0);
    expect(await balance('Purchases'), 100000.0);
    expect(await balance('Sales'), -150000.0);
    expect(await balance('Mehta Stores'),
        127000.0); // 94,400 + 82,600 - 50,000
    expect(await balance('Ravi Suppliers'), -58000.0); // -118,000 + 60,000
    expect(await balance('Furniture'), 38000.0); // 40,000 - 2,000 dep
    expect(await balance('Input CGST'), 9000.0);
    expect(await balance('Output CGST'), -13500.0); // 7,200 + 6,300
    expect(await balance('Stock-in-Hand'), 30000.0); // closing valuation
  });

  test('trading account: gross profit 70,000 with closing stock', () async {
    final trading = await FinancialStatementService.calculateTradingAccount(
      startDate: start,
      endDate: end,
      booksBeginningDate: booksFrom,
    );
    expect(trading['totalSales'], 150000.0);
    expect(trading['totalPurchases'], 100000.0);
    expect(trading['totalDirectExpenses'], 10000.0); // wages
    expect(trading['openingStock'], 0.0);
    expect(trading['closingStock'], 30000.0);
    expect(trading['grossProfit'], 70000.0);
  });

  test('profit & loss: net profit 28,000', () async {
    final trading = await FinancialStatementService.calculateTradingAccount(
      startDate: start,
      endDate: end,
      booksBeginningDate: booksFrom,
    );
    final pl = await FinancialStatementService.calculateProfitAndLoss(
      startDate: start,
      endDate: end,
      booksBeginningDate: booksFrom,
      grossProfit: trading['grossProfit'] as double,
    );
    expect(pl['totalIndirectExpenses'],
        42000.0); // rent 15,000 + salaries 25,000 + dep 2,000
    expect(pl['totalIndirectIncome'], 0.0);
    expect(pl['netProfit'], 28000.0);
  });

  test('balance sheet balances at 345,000 both sides', () async {
    final assets = await FinancialStatementService.getAssets(
      startDate: start,
      endDate: end,
      booksBeginningDate: booksFrom,
    );
    final liabilities = await FinancialStatementService.getLiabilities(
      startDate: start,
      endDate: end,
      booksBeginningDate: booksFrom,
    );

    double sideTotal(Map<String, List<Map<String, dynamic>>> side) =>
        side.values
            .expand((items) => items)
            .fold(0.0, (sum, item) => sum + (item['balance'] as double));

    double groupTotal(
            Map<String, List<Map<String, dynamic>>> side, String key) =>
        side[key]!
            .fold(0.0, (sum, item) => sum + (item['balance'] as double));

    // Assets side
    expect(groupTotal(assets, 'Fixed Assets'), 38000.0);
    expect(groupTotal(assets, 'Current Assets'),
        307000.0); // stock 30,000 + debtors 127,000 + cash 40,000 + bank 110,000
    final totalAssets = sideTotal(assets);
    expect(totalAssets, 345000.0);

    // Liabilities side: capital 250,000 + creditors 58,000
    //  + Duties & Taxes net 9,000 (output 27,000 - input 18,000)
    expect(groupTotal(liabilities, 'Capital & Reserves'), 250000.0);
    expect(groupTotal(liabilities, 'Current Liabilities'),
        67000.0); // creditors 58,000 + net GST 9,000
    final totalLiabilities = sideTotal(liabilities);
    expect(totalLiabilities, 317000.0);

    // Assets = Liabilities + Net Profit
    expect(totalAssets, totalLiabilities + 28000.0);
  });

  test('opening balances survive any books_from format the app stores',
      () async {
    final ledgers = await StorageService.getLedgers(companyId);
    final cash = ledgers.firstWhere((l) => l['name'] == 'Cash');
    // DD/MM/YYYY (edit form), ISO date, ISO datetime (new company form)
    // and a missing value must all yield the same closing balance.
    for (final format in <String?>[
      '01/04/2026',
      '2026-04-01',
      '2026-04-01T00:00:00.000',
      null,
    ]) {
      final balance = await FinancialStatementService.calculateLedgerBalance(
        ledgerId: cash['id'] as int,
        ledger: cash,
        startDate: start,
        endDate: end,
        booksBeginningDate: format,
      );
      expect(balance, 40000.0, reason: 'books_from format: $format');
    }
  });

  test('mid-year period: assets carry forward, P&L shows period only',
      () async {
    // May 2026 only. Cash/bank keep their running position; expenses
    // show just that month's movement.
    final mayStart = DateTime(2026, 5, 1);
    final mayEnd = DateTime(2026, 5, 31);
    final ledgers = await StorageService.getLedgers(companyId);

    Future<double> balance(String name) async {
      final ledger = ledgers.firstWhere((l) => l['name'] == name);
      return FinancialStatementService.calculateLedgerBalance(
        ledgerId: ledger['id'] as int,
        ledger: ledger,
        startDate: mayStart,
        endDate: mayEnd,
        booksBeginningDate: booksFrom,
      );
    }

    // Balance-sheet items are cumulative to 31/05
    expect(await balance('Cash'), 40000.0);
    expect(await balance('HDFC Bank'), 110000.0);
    expect(await balance('Capital'), -250000.0);
    // P&L items only reflect May: wages 10,000 and depreciation 2,000;
    // April's rent and salaries are excluded
    expect(await balance('Wages'), 10000.0);
    expect(await balance('Depreciation'), 2000.0);
    expect(await balance('Rent'), 0.0);
    expect(await balance('Salaries'), 0.0);
    // Only the 05/05 sale falls in May
    expect(await balance('Sales'), -70000.0);
  });

  test('trial balance still nets to zero over voucher entries', () async {
    final ledgers = await StorageService.getLedgers(companyId);
    double sum = 0;
    for (final ledger in ledgers) {
      final classification = ledger['classification'] as String? ?? '';
      if (classification == 'Stock-in-hand') continue; // valuation, not entries
      final opening = (ledger['balance'] as num?)?.toDouble() ?? 0.0;
      final signedOpening =
          FinancialStatementService.isDebitNature(classification)
              ? opening
              : -opening;
      sum += signedOpening +
          await StorageService.getLedgerBalance(ledger['id'] as int);
    }
    expect(sum, closeTo(0.0, 0.001));
  });
}
