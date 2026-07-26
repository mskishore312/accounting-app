import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:accounting_app/ui/accounting_vouchers.dart';
import 'package:accounting_app/ui/gateway.dart';
import 'package:accounting_app/ui/group_summary.dart';
import 'package:accounting_app/ui/journal_voucher.dart';
import 'package:accounting_app/ui/reports.dart';
import 'package:accounting_app/ui/select_company.dart';

/// Widget-level UI tests: pump the real screens against the real (FFI)
/// database and drive them with taps and text entry.
///
/// The database runs on real async (an FFI isolate) while widget tests use
/// fake async, so after any action that touches storage we drain real
/// microtasks with [pumpUntilFound]/[drainDb] before asserting.
void main() {
  late Directory tempDir;
  late int companyId;
  late int cashLedgerId;
  late int capitalLedgerId;

  // PeriodService is an app-lifetime singleton; use .value so provider
  // teardown between tests doesn't dispose it.
  Widget wrap(Widget child) => ChangeNotifierProvider<PeriodService>.value(
        value: PeriodService()..initializeDefaultPeriod(),
        child: MaterialApp(home: child),
      );

  // Generously wide surface: the test environment renders text with the
  // Ahem font, whose glyphs are far wider than real device fonts, so a
  // real phone width would report spurious overflows.
  void useTestSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // Dispose the tree and let any pending timers (tooltips, cursor blinks,
  // scroll simulations) expire so the strict end-of-test check passes.
  Future<void> flushTimers(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  }

  // Let real-async database work complete, then pump a frame.
  Future<void> drainDb(WidgetTester tester,
      [int rounds = 5, int millis = 40]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(Duration(milliseconds: millis)));
      await tester.pump();
    }
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder,
      {int maxRounds = 50}) async {
    for (var i = 0; i < maxRounds; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump();
    }
    expect(finder, findsWidgets); // fail with a useful message
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('ui_test');
    await databaseFactory.setDatabasesPath(tempDir.path);

    companyId = await StorageService.saveCompany({
      'name': 'UI Test Co',
      'financial_year_from': '01/04/2025',
      'books_from': '01/04/2025',
    });
    await StorageService.selectCompany(companyId);
    cashLedgerId = await StorageService.saveLedger({
      'company_id': companyId,
      'name': 'Cash',
      'classification': 'Cash-in-hand',
      'balance': 0.0,
    });
    capitalLedgerId = await StorageService.saveLedger({
      'company_id': companyId,
      'name': 'Capital',
      'classification': 'Capital Account',
      'balance': 0.0,
    });
  });

  tearDownAll(() async {
    await StorageService.closeDatabase();
    await tempDir.delete(recursive: true);
  });

  testWidgets('Gateway shows all menu buttons and opens dialogs',
      (tester) async {
    useTestSurface(tester);
    await tester.pumpWidget(wrap(const Gateway()));

    for (final label in [
      'Select Company',
      'Create Company',
      'Utility',
      'License Info',
      'Help & Support',
      'Quit',
      'Buy Now',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'missing $label');
    }

    await tester.tap(find.text('License Info'));
    await tester.pumpAndSettle();
    expect(find.text('TOM-PA (Tally On Mobile)'), findsWidgets);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quit'));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure you want to quit the app?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('Select Company lists the seeded company', (tester) async {
    useTestSurface(tester);
    await tester.pumpWidget(wrap(const SelectCompany()));
    await pumpUntilFound(tester, find.text('UI Test Co'));
  });

  testWidgets('Reports menu renders every report entry', (tester) async {
    useTestSurface(tester);
    await tester.pumpWidget(wrap(const Reports()));
    await pumpUntilFound(tester, find.text('Day Book'));

    for (final label in [
      'Day Book',
      'Ledger',
      'Cash/Bank Book',
      'Group Summary',
      'Registers',
      'List Of Accounts',
      'Address Book',
      'Trial Balance',
      'Final Reports',
    ]) {
      await tester.scrollUntilVisible(find.text(label), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(label), findsOneWidget, reason: 'missing $label');
    }
    await flushTimers(tester);
  });

  testWidgets('Group Summary drills down to a ledger group', (tester) async {
    useTestSurface(tester);
    await tester.pumpWidget(wrap(const GroupSummary()));
    await pumpUntilFound(tester, find.text('Cash-in-hand'));
    expect(find.text('Capital Account'), findsOneWidget);

    await tester.tap(find.text('Cash-in-hand'));
    await drainDb(tester);
    await pumpUntilFound(tester, find.text('Cash'));
  });

  testWidgets(
      'Journal voucher: pick ledgers, enter balanced amounts, save to DB',
      (tester) async {
    useTestSurface(tester);
    // Push the voucher screen on a navigator so its save-and-pop works.
    await tester.pumpWidget(wrap(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JournalVoucher()),
            ),
            child: const Text('OPEN VOUCHER'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('OPEN VOUCHER'));
    await drainDb(tester); // let ledgers + voucher number load

    final dropdowns = find.byType(DropdownButtonFormField<String>);
    await pumpUntilFound(tester, dropdowns);
    expect(dropdowns, findsNWidgets(2));

    // Debit side: Cash 2500
    await tester.tap(dropdowns.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash').last);
    await tester.pumpAndSettle();

    final amountFields = find.widgetWithText(TextFormField, 'Amount');
    expect(amountFields, findsNWidgets(2));
    await tester.enterText(amountFields.first, '2500');
    await tester.pump();

    // Credit side: Capital 2500
    await tester.scrollUntilVisible(dropdowns.last, 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(dropdowns.last, warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Capital').last);
    await tester.pumpAndSettle();
    await tester.enterText(amountFields.last, '2500');
    await tester.pump();

    expect(find.text('Total Debits: 2500.00'), findsOneWidget);
    expect(find.text('Total Credits: 2500.00'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Save'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save'), warnIfMissed: false);
    await drainDb(tester, 10);

    // Saving pops back to the launcher screen
    expect(find.text('OPEN VOUCHER'), findsOneWidget);

    // The voucher must be in the database with balanced entries
    final result = await tester.runAsync(() async {
      final vouchers = await StorageService.getVouchers(companyId, 'Journal');
      expect(vouchers, hasLength(1));
      return StorageService.getVoucherEntries(vouchers.first['id'] as int);
    });
    final entries = result!;
    expect(entries, hasLength(2));
    final debit = entries
        .firstWhere((e) => ((e['debit'] as num?)?.toDouble() ?? 0) > 0);
    final credit = entries
        .firstWhere((e) => ((e['credit'] as num?)?.toDouble() ?? 0) > 0);
    expect(debit['ledger_id'], cashLedgerId);
    expect((debit['debit'] as num).toDouble(), 2500.0);
    expect(credit['ledger_id'], capitalLedgerId);
    expect((credit['credit'] as num).toDouble(), 2500.0);
  });

  testWidgets('Accounting Vouchers screen shows the journal count',
      (tester) async {
    useTestSurface(tester);
    await tester.pumpWidget(wrap(const AccountingVouchers()));
    await pumpUntilFound(tester, find.text('Total Vouchers: 1'));
    expect(find.textContaining('Journal'), findsWidgets);
    await flushTimers(tester);
  });
}
