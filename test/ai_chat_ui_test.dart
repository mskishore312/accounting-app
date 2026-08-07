import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/main.dart';
import 'package:accounting_app/services/ai_accounting_service.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:accounting_app/ui/bank_rows_review.dart';
import 'package:accounting_app/ui/gateway.dart';
import 'package:accounting_app/ui/options.dart';
import 'package:accounting_app/ui/widgets/ai_chat_launcher.dart';
import 'package:accounting_app/ui/widgets/ai_chat_sheet.dart';

/// UI tests for the assistant: does the launcher actually appear on top of
/// every screen, does tapping it open the panel, does the overlay leave the
/// screens underneath laid out correctly, and does the statement review table
/// render and guard the Post button.
///
/// These exist because the rest of the AI coverage is service-level; without
/// them "the feature shipped" only ever meant "the code compiled".
void main() {
  late Directory tempDir;
  late int companyId;
  late int rentLedgerId;

  void useTestSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // Let real-async (FFI) database work complete, then pump a frame.
  Future<void> drainDb(WidgetTester tester,
      [int rounds = 5, int millis = 40]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(Duration(milliseconds: millis)));
      await tester.pump();
    }
  }

  // Open the assistant without pumpAndSettle: the panel shows a spinner while
  // it loads chat history, and an indeterminate CircularProgressIndicator
  // never settles, so pumpAndSettle would always time out.
  Future<void> openPanel(WidgetTester tester) async {
    await tester.tap(find.byType(AiChatLauncher));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await drainDb(tester);
    await tester.pump();
  }

  // Mirrors the MaterialApp in main.dart, but with a .value provider so
  // teardown does not dispose the app-lifetime PeriodService singleton and
  // break every following test. The final test pumps the real MyApp to prove
  // this mirror still matches it.
  Widget appWith(Widget home) => ChangeNotifierProvider<PeriodService>.value(
        value: PeriodService()..initializeDefaultPeriod(),
        child: MaterialApp(
          navigatorKey: appNavigatorKey,
          builder: (context, child) => Stack(
            children: [
              if (child != null) Positioned.fill(child: child),
              const AiChatLauncher(),
            ],
          ),
          home: home,
        ),
      );

  Widget bare(Widget child) => ChangeNotifierProvider<PeriodService>.value(
        value: PeriodService()..initializeDefaultPeriod(),
        child: MaterialApp(home: child),
      );

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('ai_ui_test');
    await databaseFactory.setDatabasesPath(tempDir.path);

    companyId = await StorageService.saveCompany({
      'name': 'AI UI Co',
      'financial_year_from': '01/04/2026',
      'books_from': '01/04/2026',
    });
    await StorageService.selectCompany(companyId);
    await StorageService.saveLedger({
      'company_id': companyId,
      'name': 'HDFC Bank',
      'classification': 'Bank Accounts',
      'balance': 0.0,
    });
    rentLedgerId = await StorageService.saveLedger({
      'company_id': companyId,
      'name': 'Rent',
      'classification': 'Indirect Expenses',
      'balance': 0.0,
    });
  });

  tearDownAll(() async {
    await StorageService.closeDatabase();
    await tempDir.delete(recursive: true);
  });

  group('the floating launcher', () {
    testWidgets('is painted over the app with its sparkle icon',
        (tester) async {
      useTestSurface(tester);
      await tester.pumpWidget(appWith(const Gateway()));
      await drainDb(tester);

      expect(find.byType(AiChatLauncher), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AiChatLauncher),
          matching: find.byIcon(Icons.auto_awesome),
        ),
        findsOneWidget,
      );
    });

    testWidgets('rests in the bottom-right corner, on screen', (tester) async {
      useTestSurface(tester);
      await tester.pumpWidget(appWith(const Gateway()));
      await drainDb(tester);

      final launcher = tester.getRect(find.byType(AiChatLauncher));
      final screen = tester.getRect(find.byType(MaterialApp));
      expect(launcher.width, greaterThan(0));
      expect(launcher.height, greaterThan(0));
      expect(launcher.right, lessThanOrEqualTo(screen.right));
      expect(launcher.bottom, lessThanOrEqualTo(screen.bottom));
      expect(launcher.left, greaterThan(screen.width / 2));
      expect(launcher.top, greaterThan(screen.height / 2));
    });

    testWidgets('tapping it opens the chat panel', (tester) async {
      useTestSurface(tester);
      await tester.pumpWidget(appWith(const Gateway()));
      await drainDb(tester);

      await openPanel(tester);

      expect(find.byType(AiChatSheet), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AiChatSheet),
          matching: find.text('AI Assistant'),
        ),
        findsOneWidget,
      );
      expect(find.text('Ask, or describe an entry…'), findsOneWidget);
      expect(find.byIcon(Icons.add_photo_alternate), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    // Regression guard: a Stack lays out non-positioned children with loose
    // constraints, so overlaying the launcher without Positioned.fill let
    // Options size to its natural height and overflow by ~98,000 pixels.
    testWidgets('does not squeeze the screen underneath it', (tester) async {
      useTestSurface(tester);
      await tester.pumpWidget(appWith(const Options()));
      await drainDb(tester);

      expect(tester.takeException(), isNull);

      final options = tester.getRect(find.byType(Options));
      final screen = tester.getRect(find.byType(MaterialApp));
      expect(options.height, screen.height);
      expect(options.width, screen.width);
    });
  });

  testWidgets('the panel prompts for a key when Gemini is not configured',
      (tester) async {
    // No key is ever set in this file, so Gemini is already unconfigured.
    // Deleting it here would mean awaiting a real-async database call inside
    // a widget test, which fake async never advances.
    useTestSurface(tester);
    await tester.pumpWidget(appWith(const Gateway()));
    await drainDb(tester);

    // Open it through the launcher rather than calling AiChatSheet.show
    // directly: show() only completes when the sheet is dismissed, so it can
    // neither be awaited nor left dangling — an un-awaited guarded call
    // poisons every test that runs after it.
    await openPanel(tester);

    expect(find.textContaining('No Gemini API key'), findsOneWidget);
    expect(find.text('Add key'), findsOneWidget);
  });

  group('statement review table', () {
    List<ProposedBankRow> rows() => [
          ProposedBankRow(
            date: DateTime(2026, 5, 2),
            description: 'NEFT rent payment',
            amount: 4500,
            isDeposit: false,
            ledgerId: rentLedgerId,
            ledgerName: 'Rent',
            suggestionLabel: 'Suggested by the assistant',
            confident: true,
          ),
          ProposedBankRow(
            date: DateTime(2026, 5, 3),
            description: 'Unknown deposit',
            amount: 1200,
            isDeposit: true,
            suggestionLabel: 'Parked in Suspense — please review',
          ),
        ];

    testWidgets('renders every row with its ledger and reason', (tester) async {
      useTestSurface(tester);
      await tester.pumpWidget(bare(BankRowsReview(
        rows: rows(),
        service: AiAccountingService(),
      )));
      await drainDb(tester);

      expect(find.text('NEFT rent payment'), findsOneWidget);
      expect(find.text('Unknown deposit'), findsOneWidget);
      expect(find.text('02 May 2026'), findsOneWidget);

      // A confident row names its ledger and why.
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text('Suggested by the assistant'), findsOneWidget);

      // An unresolved row says so rather than defaulting silently.
      expect(find.text('Choose ledger'), findsOneWidget);
      expect(find.textContaining('Suspense'), findsOneWidget);
      expect(find.textContaining('need a closer look'), findsOneWidget);
    });

    testWidgets('money in and out are totalled separately', (tester) async {
      useTestSurface(tester);
      await tester.pumpWidget(bare(BankRowsReview(
        rows: rows(),
        service: AiAccountingService(),
      )));
      await drainDb(tester);

      expect(find.text('Received'), findsWidgets);
      expect(find.text('Paid'), findsWidgets);
      // 1,200 in and 4,500 out, formatted for India.
      expect(find.textContaining('1,200.00'), findsWidgets);
      expect(find.textContaining('4,500.00'), findsWidgets);
    });

    testWidgets('the Post button counts only the selected rows',
        (tester) async {
      useTestSurface(tester);
      await tester.pumpWidget(bare(BankRowsReview(
        rows: rows(),
        service: AiAccountingService(),
      )));
      await drainDb(tester);

      expect(find.text('Post 2 transaction(s)'), findsOneWidget);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      expect(find.text('Post 1 transaction(s)'), findsOneWidget);
    });

    testWidgets('the direction chips flip a row between paid and received',
        (tester) async {
      useTestSurface(tester);
      final data = rows();
      await tester.pumpWidget(bare(BankRowsReview(
        rows: data,
        service: AiAccountingService(),
      )));
      await drainDb(tester);

      expect(data.first.isDeposit, isFalse);
      await tester.tap(find.text('Received').last);
      await tester.pump();
      expect(data.any((r) => r.isDeposit), isTrue);
    });

    testWidgets('editing an amount is written back to the row', (tester) async {
      useTestSurface(tester);
      final data = rows();
      await tester.pumpWidget(bare(BankRowsReview(
        rows: data,
        service: AiAccountingService(),
      )));
      await drainDb(tester);

      // The row amount, not the "Paid" total in the summary above it: only
      // row amounts carry the +/− sign, and only they are tappable.
      await tester.tap(find.textContaining('− ').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '5200.50');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(data.first.amount, 5200.50);
    });
  });

  // Last on purpose: pumping the real MyApp uses a `create:` provider, which
  // disposes the PeriodService singleton on teardown and would break any test
  // that ran after it.
  testWidgets('the real MyApp installs the launcher over its navigator',
      (tester) async {
    useTestSurface(tester);
    await tester.pumpWidget(MyApp());
    await drainDb(tester);

    expect(find.byType(AiChatLauncher), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(AiChatLauncher),
        matching: find.byType(Stack),
      ),
      findsWidgets,
    );
  });
}
