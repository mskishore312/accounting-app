import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:accounting_app/ui/ledger_view.dart';
import 'package:accounting_app/ui/widgets/ledger_drilldown.dart';

/// Voucher image attachments (storage) and report -> ledger drill-down.
void main() {
  late Directory tempDir;
  late int companyId;
  late int cashId;
  late int voucherId;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('attach_test');
    await databaseFactory.setDatabasesPath(tempDir.path);

    companyId = await StorageService.saveCompany({
      'name': 'Attach Co',
      'financial_year_from': '01/04/2026',
      'books_from': '01/04/2026',
    });
    await StorageService.selectCompany(companyId);
    cashId = await StorageService.saveLedger({
      'company_id': companyId,
      'name': 'Cash',
      'classification': 'Cash-in-hand',
      'balance': 0.0,
    });
    final capitalId = await StorageService.saveLedger({
      'company_id': companyId,
      'name': 'Capital',
      'classification': 'Capital Account',
      'balance': 0.0,
    });

    voucherId = await StorageService.saveVoucher({
      'company_id': companyId,
      'voucher_number': 'JV001',
      'voucher_date': '2026-05-10',
      'type': 'Journal',
      'total': 5000.0,
    });
    await StorageService.insertVoucherEntry({
      'voucher_id': voucherId,
      'ledger_id': cashId,
      'description': 'seed',
      'debit': 5000.0,
      'credit': 0.0,
    });
    await StorageService.insertVoucherEntry({
      'voucher_id': voucherId,
      'ledger_id': capitalId,
      'description': 'seed',
      'debit': 0.0,
      'credit': 5000.0,
    });
  });

  tearDownAll(() async {
    await StorageService.closeDatabase();
    await tempDir.delete(recursive: true);
  });

  group('voucher attachments', () {
    test('save, list and delete images for a voucher', () async {
      expect(await StorageService.getVoucherImages(voucherId), isEmpty);

      await StorageService.saveVoucherImage(voucherId, '/tmp/bill1.jpg');
      await StorageService.saveVoucherImage(voucherId, '/tmp/bill2.jpg');
      final images = await StorageService.getVoucherImages(voucherId);
      expect(images, ['/tmp/bill1.jpg', '/tmp/bill2.jpg']);

      final counts = await StorageService.getVoucherImageCounts(companyId);
      expect(counts[voucherId], 2);

      await StorageService.deleteVoucherImage(voucherId, '/tmp/bill1.jpg');
      expect(await StorageService.getVoucherImages(voucherId),
          ['/tmp/bill2.jpg']);
    });

    test('attachments are removed with their voucher', () async {
      final tempVoucher = await StorageService.saveVoucher({
        'company_id': companyId,
        'voucher_number': 'JV002',
        'voucher_date': '2026-05-11',
        'type': 'Journal',
        'total': 100.0,
      });
      await StorageService.saveVoucherImage(tempVoucher, '/tmp/x.jpg');
      expect(await StorageService.getVoucherImages(tempVoucher), hasLength(1));

      await StorageService.deleteVouchers(tempVoucher);
      expect(await StorageService.getVoucherImages(tempVoucher), isEmpty);
    });
  });

  group('report drill-down', () {
    testWidgets('opens the ledger for the report period', (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final periodService = PeriodService()..initializeDefaultPeriod();
      // A period deliberately different from the app-wide default.
      final reportStart = DateTime(2026, 5, 1);
      final reportEnd = DateTime(2026, 5, 31);
      final globalStartBefore = periodService.startDate;
      final globalEndBefore = periodService.endDate;

      await tester.pumpWidget(
        ChangeNotifierProvider<PeriodService>.value(
          value: periodService,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => openLedgerDrilldown(
                      context,
                      ledgerName: 'Cash',
                      startDate: reportStart,
                      endDate: reportEnd,
                    ),
                    child: const Text('DRILL'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('DRILL'));
      for (var i = 0; i < 25; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump();
        if (find.byType(LedgerView).evaluate().isNotEmpty) break;
      }

      expect(find.byType(LedgerView), findsOneWidget);
      final view = tester.widget<LedgerView>(find.byType(LedgerView));
      expect(view.ledger['id'], cashId);
      expect(view.initialStartDate, reportStart);
      expect(view.initialEndDate, reportEnd);
      // The drill-down must not change the app-wide period.
      expect(periodService.startDate, globalStartBefore);
      expect(periodService.endDate, globalEndBefore);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 2));
    });

    testWidgets('unknown ledger reports instead of crashing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => openLedgerDrilldown(
                    context,
                    ledgerName: 'No Such Ledger',
                  ),
                  child: const Text('DRILL'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('DRILL'));
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump();
      }
      expect(find.textContaining('not found'), findsOneWidget);
      expect(find.byType(LedgerView), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 2));
    });
  });
}
