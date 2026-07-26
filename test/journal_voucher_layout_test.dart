import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:accounting_app/ui/contra_voucher.dart';
import 'package:accounting_app/ui/inventory_voucher.dart';
import 'package:accounting_app/ui/invoice_voucher.dart';
import 'package:accounting_app/ui/journal_voucher.dart';
import 'package:accounting_app/ui/payment_voucher.dart';
import 'package:accounting_app/ui/receipt_voucher.dart';

/// Layout regression tests: the voucher screens must not overflow at real
/// phone widths, including with long ledger names.
void main() {
  late Directory tempDir;

  Widget wrap(Widget child) => ChangeNotifierProvider<PeriodService>.value(
        value: PeriodService()..initializeDefaultPeriod(),
        child: MaterialApp(home: child),
      );

  /// A small phone in logical pixels (e.g. Galaxy S8 / Pixel 4a class).
  void usePhone(WidgetTester tester, {double width = 360, double height = 780}) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump();
    }
  }

  void expectNoOverflow(WidgetTester tester, String where) {
    final error = tester.takeException();
    expect(
      error,
      isNull,
      reason: 'Layout overflow in $where: $error',
    );
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('jv_layout_test');
    await databaseFactory.setDatabasesPath(tempDir.path);

    final companyId = await StorageService.saveCompany({
      'name': 'Layout Test Co',
      'financial_year_from': '01/04/2026',
      'books_from': '01/04/2026',
    });
    await StorageService.selectCompany(companyId);
    // Deliberately long, realistic ledger names.
    for (final name in [
      'Cash',
      'Sundry Creditors - Ravi Enterprises Private Limited',
      'Bank of Baroda Current Account 0123456789',
    ]) {
      await StorageService.saveLedger({
        'company_id': companyId,
        'name': name,
        'classification': 'Cash-in-hand',
        'balance': 0.0,
      });
    }
  });

  tearDownAll(() async {
    await StorageService.closeDatabase();
    await tempDir.delete(recursive: true);
  });

  testWidgets('journal voucher lays out on a 360px phone', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(wrap(const JournalVoucher()));
    await settle(tester);
    expectNoOverflow(tester, 'journal voucher (initial)');
  });

  testWidgets('journal voucher lays out with a long ledger selected',
      (tester) async {
    usePhone(tester);
    await tester.pumpWidget(wrap(const JournalVoucher()));
    await settle(tester);

    final dropdowns = find.byType(DropdownButtonFormField<String>);
    expect(dropdowns, findsNWidgets(2));

    await tester.tap(dropdowns.first);
    await tester.pumpAndSettle();
    expectNoOverflow(tester, 'ledger dropdown menu');

    await tester
        .tap(find.text('Sundry Creditors - Ravi Enterprises Private Limited').last);
    await tester.pumpAndSettle();
    expectNoOverflow(tester, 'journal voucher with long ledger selected');

    // Large amounts should not push the row out either.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount').first, '12345678.90');
    await tester.pump();
    expectNoOverflow(tester, 'journal voucher with large amount');
  });

  testWidgets('journal voucher lays out on a very narrow 320px phone',
      (tester) async {
    usePhone(tester, width: 320, height: 720);
    await tester.pumpWidget(wrap(const JournalVoucher()));
    await settle(tester);
    expectNoOverflow(tester, 'journal voucher at 320px');
  });

  // The other voucher entry screens share the same row/dropdown patterns.
  final otherScreens = <String, Widget Function()>{
    'payment voucher': () => const PaymentVoucher(),
    'receipt voucher': () => const ReceiptVoucher(),
    'contra voucher': () => const ContraVoucher(),
    'sales invoice': () => const InvoiceVoucher(type: 'Sales'),
    'inventory voucher': () => const InventoryVoucherForm(),
  };

  for (final entry in otherScreens.entries) {
    testWidgets('${entry.key} lays out on a 360px phone', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(wrap(entry.value()));
      await settle(tester);
      expectNoOverflow(tester, entry.key);
    });
  }
}
