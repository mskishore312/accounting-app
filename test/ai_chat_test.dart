import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/ai_accounting_service.dart';
import 'package:accounting_app/services/ai_chat_service.dart';
import 'package:accounting_app/services/gemini_service.dart';

/// The chatbot and bank-statement layers, with Gemini replaced by a scripted
/// fake. The point of these tests is that a confident-sounding model answer
/// never reaches the books unchecked.
void main() {
  late Directory tempDir;
  late int companyId;
  late int bankLedgerId;
  late int rentLedgerId;

  /// Gemini that replies with [replies] in order, one per request.
  /// Request bodies are appended to [sink] when given.
  GeminiService scriptedGemini(
    List<String> replies, {
    List<Map<String, dynamic>>? sink,
  }) {
    final queue = List<String>.from(replies);
    final client = MockClient((request) async {
      sink?.add(jsonDecode(request.body) as Map<String, dynamic>);
      final reply = queue.isEmpty ? queue.last : queue.removeAt(0);
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': reply}
                ]
              }
            }
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    return GeminiService(client: client);
  }

  AiAccountingService accountingWith(
    List<String> replies, {
    List<Map<String, dynamic>>? sink,
  }) =>
      AiAccountingService(gemini: scriptedGemini(replies, sink: sink));

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('ai_chat_test');
    await databaseFactory.setDatabasesPath(tempDir.path);

    companyId = await StorageService.saveCompany({
      'name': 'Chat Test Co',
      'financial_year_from': '01/04/2026',
      'books_from': '01/04/2026',
    });
    await StorageService.selectCompany(companyId);

    bankLedgerId = await StorageService.saveLedger({
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
    await StorageService.saveLedger({
      'company_id': companyId,
      'name': 'Cash',
      'classification': 'Cash-in-hand',
      'balance': 0.0,
    });
    await GeminiService.setApiKey('test-key');
  });

  tearDownAll(() async {
    await StorageService.closeDatabase();
    await tempDir.delete(recursive: true);
  });

  group('reading a bank statement', () {
    test('rows are parsed and known ledgers matched', () async {
      final ai = accountingWith([
        jsonEncode({
          'rows': [
            {
              'date': '2026-05-02',
              'description': 'NEFT rent payment',
              'amount': 4500,
              'direction': 'withdrawal',
              'ledger': 'Rent',
            },
            {
              'date': '2026-05-03',
              'description': 'Customer receipt',
              'amount': 12000.50,
              'direction': 'deposit',
              'ledger': '',
            },
          ],
        }),
      ]);

      final rows = await ai.extractBankRows(['/nonexistent/page1.jpg']);

      expect(rows, hasLength(2));
      expect(rows[0].amount, 4500);
      expect(rows[0].isDeposit, isFalse);
      expect(rows[0].ledgerId, rentLedgerId);
      expect(rows[0].ledgerName, 'Rent');

      expect(rows[1].amount, 12000.50);
      expect(rows[1].isDeposit, isTrue);
      // No suggestion offered, so the row waits for a human.
      expect(rows[1].ledgerId, isNull);
      expect(rows[1].isReady, isFalse);
    });

    test('a ledger the company does not have is kept as an unmatched hint',
        () async {
      final ai = accountingWith([
        jsonEncode({
          'rows': [
            {
              'date': '2026-05-02',
              'description': 'Diesel',
              'amount': 800,
              'direction': 'withdrawal',
              'ledger': 'Fuel Expenses',
            },
          ],
        }),
      ]);

      final rows = await ai.extractBankRows(['/nonexistent/p.jpg']);
      expect(rows.single.ledgerId, isNull);
      expect(rows.single.unmatchedSuggestion, 'Fuel Expenses');
    });

    test('unusable rows are dropped rather than guessed at', () async {
      final ai = accountingWith([
        jsonEncode({
          'rows': [
            {
              'date': 'not a date',
              'description': 'Bad date',
              'amount': 100,
              'direction': 'deposit',
            },
            {
              'date': '2026-05-04',
              'description': 'Zero amount',
              'amount': 0,
              'direction': 'deposit',
            },
            {
              'date': '2026-05-05',
              'description': 'Good row',
              'amount': 250,
              'direction': 'deposit',
            },
          ],
        }),
      ]);

      final rows = await ai.extractBankRows(['/nonexistent/p.jpg']);
      expect(rows, hasLength(1));
      expect(rows.single.description, 'Good row');
    });

    test('a statement yielding nothing usable is reported, not posted',
        () async {
      final ai = accountingWith([jsonEncode({'rows': []})]);
      await expectLater(
        ai.extractBankRows(['/nonexistent/p.jpg']),
        throwsA(isA<AiDraftException>()
            .having((e) => e.message, 'message', contains('No transactions'))),
      );
    });

    test('attaching nothing is refused before any network call', () async {
      final ai = accountingWith([]);
      await expectLater(
        ai.extractBankRows(const []),
        throwsA(isA<AiDraftException>()),
      );
    });

    test('the statement prompt carries the chart of accounts', () async {
      final sent = <Map<String, dynamic>>[];
      final ai = accountingWith(
        [
          jsonEncode({
            'rows': [
              {
                'date': '2026-05-05',
                'description': 'x',
                'amount': 1,
                'direction': 'deposit',
              }
            ]
          })
        ],
        sink: sent,
      );
      await ai.extractBankRows(['/nonexistent/p.jpg']);

      final prompt = sent.single['contents'][0]['parts'][0]['text'] as String;
      expect(prompt, contains('Rent (Indirect Expenses)'));
      expect(prompt, contains('HDFC Bank'));
    });
  });

  group('posting reviewed statement rows', () {
    ProposedBankRow row({
      required double amount,
      required bool isDeposit,
      int? ledgerId,
      bool selected = true,
    }) =>
        ProposedBankRow(
          date: DateTime(2026, 5, 6),
          description: 'Statement line',
          amount: amount,
          isDeposit: isDeposit,
          ledgerId: ledgerId,
          selected: selected,
        );

    test('a row without a ledger blocks the whole batch', () async {
      final ai = accountingWith([]);
      await expectLater(
        ai.postBankRows(
          bankLedgerId: bankLedgerId,
          rows: [
            row(amount: 100, isDeposit: true, ledgerId: rentLedgerId),
            row(amount: 200, isDeposit: false),
          ],
        ),
        throwsA(isA<AiDraftException>().having(
            (e) => e.message, 'message', contains('counterparty ledger'))),
      );
    });

    test('the bank ledger cannot be its own counterparty', () async {
      final ai = accountingWith([]);
      await expectLater(
        ai.postBankRows(
          bankLedgerId: bankLedgerId,
          rows: [row(amount: 100, isDeposit: true, ledgerId: bankLedgerId)],
        ),
        throwsA(isA<AiDraftException>()),
      );
    });

    test('deselected rows are ignored, and an empty batch is refused',
        () async {
      final ai = accountingWith([]);
      await expectLater(
        ai.postBankRows(
          bankLedgerId: bankLedgerId,
          rows: [
            row(
              amount: 100,
              isDeposit: true,
              ledgerId: rentLedgerId,
              selected: false,
            )
          ],
        ),
        throwsA(isA<AiDraftException>()
            .having((e) => e.message, 'message', contains('No rows'))),
      );
    });

    test('selected rows become double-entry vouchers', () async {
      final ai = accountingWith([]);
      final posted = await ai.postBankRows(
        bankLedgerId: bankLedgerId,
        rows: [
          row(amount: 4500, isDeposit: false, ledgerId: rentLedgerId),
          row(amount: 1000, isDeposit: true, ledgerId: rentLedgerId),
          row(
            amount: 99,
            isDeposit: true,
            ledgerId: rentLedgerId,
            selected: false,
          ),
        ],
      );
      expect(posted, 2);

      final payments = await StorageService.getVouchers(companyId, 'Payment');
      final receipts = await StorageService.getVouchers(companyId, 'Receipt');
      expect(payments, hasLength(1));
      expect(receipts, hasLength(1));

      // Money leaving the bank credits the bank and debits the expense.
      final entries =
          await StorageService.getVoucherEntries(payments.single['id'] as int);
      expect(entries, hasLength(2));
      final debit = entries.firstWhere((e) => (e['debit'] as num) > 0);
      final credit = entries.firstWhere((e) => (e['credit'] as num) > 0);
      expect(debit['ledger_id'], rentLedgerId);
      expect(credit['ledger_id'], bankLedgerId);
      expect((debit['debit'] as num).toDouble(), 4500);
    });
  });

  group('chat routing', () {
    test('a question comes back as plain text with no draft attached',
        () async {
      final chat = AiChatService(
        gemini: scriptedGemini([
          jsonEncode({
            'intent': 'answer',
            'reply': 'Your rent expense is 4,500.',
          })
        ]),
        accounting: accountingWith([]),
      );

      final reply = await chat.send(text: 'how much rent?', history: const []);
      expect(reply.role, ChatRole.assistant);
      expect(reply.text, contains('4,500'));
      expect(reply.hasDraft, isFalse);
    });

    test('a voucher intent produces a validated draft', () async {
      final chat = AiChatService(
        gemini: scriptedGemini([
          jsonEncode({
            'intent': 'voucher',
            'reply': 'Drafted a payment for rent.',
            'voucher': {
              'voucher_type': 'Payment',
              'date': '2026-05-07',
              'narration': 'May rent',
              'entries': [
                {'ledger': 'Rent', 'debit': 4500, 'credit': 0},
                {'ledger': 'Cash', 'debit': 0, 'credit': 4500},
              ],
            },
          })
        ]),
        accounting: accountingWith([]),
      );

      final reply = await chat.send(text: 'paid 4500 rent', history: const []);
      expect(reply.voucher, isNotNull);
      expect(reply.voucher!.isBalanced, isTrue);
      expect(reply.voucher!.type, 'Payment');
      expect(reply.settled, isFalse);
    });

    test('an invalid draft becomes a message rather than an exception',
        () async {
      final chat = AiChatService(
        gemini: scriptedGemini([
          jsonEncode({
            'intent': 'voucher',
            'reply': 'Here you go.',
            'voucher': {
              'voucher_type': 'Payment',
              'date': '2026-05-07',
              'entries': [
                {'ledger': 'Imaginary Ledger', 'debit': 10, 'credit': 0},
                {'ledger': 'Cash', 'debit': 0, 'credit': 10},
              ],
            },
          })
        ]),
        accounting: accountingWith([]),
      );

      final reply = await chat.send(text: 'pay something', history: const []);
      expect(reply.hasDraft, isFalse);
      expect(reply.text, contains('Imaginary Ledger'));
    });

    test('a bank statement intent with no image asks for one', () async {
      final chat = AiChatService(
        gemini: scriptedGemini([
          jsonEncode({
            'intent': 'bank_statement',
            'reply': 'Sure, importing.',
          })
        ]),
        accounting: accountingWith([]),
      );

      final reply = await chat.send(text: 'import my statement', history: const []);
      expect(reply.bankRows, isNull);
      expect(reply.text, contains('Attach'));
    });

    test('a bank statement intent with an image returns rows to review',
        () async {
      final chat = AiChatService(
        gemini: scriptedGemini([
          jsonEncode({'intent': 'bank_statement', 'reply': 'Reading it now.'})
        ]),
        accounting: accountingWith([
          jsonEncode({
            'rows': [
              {
                'date': '2026-05-08',
                'description': 'Rent',
                'amount': 4500,
                'direction': 'withdrawal',
                'ledger': 'Rent',
              }
            ]
          })
        ]),
      );

      final reply = await chat.send(
        text: 'import this',
        images: ['/nonexistent/statement.jpg'],
        history: const [],
      );
      expect(reply.bankRows, hasLength(1));
      expect(reply.bankRows!.single.ledgerId, rentLedgerId);
    });

    test('earlier turns are replayed with speaker roles', () async {
      final sent = <Map<String, dynamic>>[];
      final chat = AiChatService(
        gemini: scriptedGemini(
          [
            jsonEncode({'intent': 'answer', 'reply': 'ok'})
          ],
          sink: sent,
        ),
        accounting: accountingWith([]),
      );

      await chat.send(
        text: 'and the month before?',
        history: [
          ChatMessage(role: ChatRole.user, text: 'what was rent in May?'),
          ChatMessage(role: ChatRole.assistant, text: 'Rent in May was 4,500.'),
        ],
      );

      final contents = sent.single['contents'] as List<dynamic>;
      expect(contents, hasLength(3));
      expect(contents[0]['role'], 'user');
      expect(contents[0]['parts'][0]['text'], contains('what was rent in May?'));
      expect(contents[1]['role'], 'model');
      expect(contents[2]['role'], 'user');
      expect(contents[2]['parts'][0]['text'], contains('and the month before?'));
    });
  });
}
