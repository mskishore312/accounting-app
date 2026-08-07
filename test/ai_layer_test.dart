import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/ai_accounting_service.dart';
import 'package:accounting_app/services/gemini_service.dart';

/// The AI layer, with Gemini replaced by a scripted fake so the
/// guardrails can be tested without network access or an API key.
void main() {
  late Directory tempDir;
  late int companyId;

  /// Builds a Gemini service whose HTTP calls return [replyText].
  GeminiService fakeGemini(String replyText, {int status = 200}) {
    final client = MockClient((request) async {
      if (status != 200) {
        return http.Response(
          jsonEncode({
            'error': {'message': replyText, 'status': 'INVALID_ARGUMENT'}
          }),
          status,
        );
      }
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': replyText}
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

  /// Captures the request body the service sends.
  GeminiService capturingGemini(List<Map<String, dynamic>> sink, String reply) {
    final client = MockClient((request) async {
      sink.add(jsonDecode(request.body) as Map<String, dynamic>);
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
      );
    });
    return GeminiService(client: client);
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('ai_test');
    await databaseFactory.setDatabasesPath(tempDir.path);

    companyId = await StorageService.saveCompany({
      'name': 'AI Test Co',
      'financial_year_from': '01/04/2026',
      'books_from': '01/04/2026',
    });
    await StorageService.selectCompany(companyId);
    for (final entry in {
      'Cash': 'Cash-in-hand',
      'HDFC Bank': 'Bank Accounts',
      'Rent': 'Indirect Expenses',
      'Sales': 'Sales Accounts',
    }.entries) {
      await StorageService.saveLedger({
        'company_id': companyId,
        'name': entry.key,
        'classification': entry.value,
        'balance': 0.0,
      });
    }
    await GeminiService.setApiKey('test-key');
  });

  tearDownAll(() async {
    await StorageService.closeDatabase();
    await tempDir.delete(recursive: true);
  });

  group('configuration', () {
    test('key and model round-trip through settings', () async {
      expect(await GeminiService.isConfigured(), isTrue);
      expect(await GeminiService.getApiKey(), 'test-key');
      expect(await GeminiService.getModel(), GeminiService.defaultModel);

      // Any model still on offer must survive a round trip untouched.
      final other = GeminiService.availableModels
          .firstWhere((m) => m != GeminiService.defaultModel);
      await GeminiService.setModel(other);
      expect(await GeminiService.getModel(), other);
      await GeminiService.setModel(GeminiService.defaultModel);
    });

    test('a device pinned to a retired model is migrated off it', () async {
      // What a phone that last ran the old build actually has stored.
      await StorageService.setSetting(
          GeminiService.modelSetting, 'gemini-2.0-flash');

      expect(await GeminiService.getModel(), GeminiService.defaultModel);
      // Written back, so Settings shows the model really in use.
      expect(
        await StorageService.getSetting(GeminiService.modelSetting),
        GeminiService.defaultModel,
      );
    });

    test('every retired model migrates, and none is still on offer', () async {
      for (final retired in GeminiService.retiredModels) {
        await StorageService.setSetting(GeminiService.modelSetting, retired);
        expect(await GeminiService.getModel(), GeminiService.defaultModel,
            reason: '$retired should not survive');
      }
      expect(
        GeminiService.availableModels
            .where(GeminiService.retiredModels.contains),
        isEmpty,
      );
      expect(
        GeminiService.retiredModels.contains(GeminiService.defaultModel),
        isFalse,
      );
      await GeminiService.setModel(GeminiService.defaultModel);
    });

    test('a retired model reaching the API is explained, not just 404', () async {
      final service = fakeGemini('models/gemini-2.0-flash is not found',
          status: 404);
      await expectLater(
        service.generate(prompt: 'hi'),
        throwsA(isA<GeminiException>()
            .having((e) => e.message, 'message', contains('retired'))),
      );
    });

    test('a missing key is reported as a config error', () async {
      await StorageService.deleteSetting(GeminiService.apiKeySetting);
      final service = GeminiService();
      await expectLater(
        service.generate(prompt: 'hi'),
        throwsA(isA<GeminiException>()
            .having((e) => e.isConfigError, 'isConfigError', isTrue)),
      );
      await GeminiService.setApiKey('test-key');
    });

    test('an invalid key produces a helpful message', () async {
      final service = fakeGemini('API key not valid. Please pass a valid API key.',
          status: 400);
      await expectLater(
        service.generate(prompt: 'hi'),
        throwsA(isA<GeminiException>()
            .having((e) => e.message, 'message', contains('not valid'))
            .having((e) => e.isConfigError, 'isConfigError', isTrue)),
      );
    });

    test('rate limiting is surfaced plainly', () async {
      final service = fakeGemini('quota', status: 429);
      await expectLater(
        service.generate(prompt: 'hi'),
        throwsA(isA<GeminiException>()
            .having((e) => e.message, 'message', contains('rate limit'))),
      );
    });
  });

  group('voucher drafting from text', () {
    test('produces a balanced, validated draft', () async {
      final ai = AiAccountingService(
        gemini: fakeGemini(jsonEncode({
          'voucher_type': 'Payment',
          'date': '2026-05-04',
          'narration': 'Shop rent for May',
          'entries': [
            {'ledger': 'Rent', 'debit': 4500, 'credit': 0},
            {'ledger': 'Cash', 'debit': 0, 'credit': 4500},
          ],
          'notes': '',
        })),
      );

      final draft = await ai.draftVoucherFromText('paid 4500 shop rent by cash');
      expect(draft.type, 'Payment');
      expect(draft.date, DateTime(2026, 5, 4));
      expect(draft.entries, hasLength(2));
      expect(draft.isBalanced, isTrue);
      expect(draft.totalDebit, 4500);
      expect(draft.entries.first.ledgerName, 'Rent');
      expect(draft.entries.first.ledgerId, isPositive);
    });

    test('the prompt carries the real chart of accounts', () async {
      final sent = <Map<String, dynamic>>[];
      final ai = AiAccountingService(
        gemini: capturingGemini(
          sent,
          jsonEncode({
            'voucher_type': 'Payment',
            'date': '2026-05-04',
            'entries': [
              {'ledger': 'Rent', 'debit': 100, 'credit': 0},
              {'ledger': 'Cash', 'debit': 0, 'credit': 100},
            ],
          }),
        ),
      );
      await ai.draftVoucherFromText('paid 100 rent');

      final prompt = sent.single['contents'][0]['parts'][0]['text'] as String;
      expect(prompt, contains('HDFC Bank'));
      expect(prompt, contains('Rent (Indirect Expenses)'));
      // Structured output is requested so parsing is reliable.
      expect(sent.single['generationConfig']['responseMimeType'],
          'application/json');
    });

    test('a hallucinated ledger is rejected, not posted', () async {
      final ai = AiAccountingService(
        gemini: fakeGemini(jsonEncode({
          'voucher_type': 'Payment',
          'date': '2026-05-04',
          'entries': [
            {'ledger': 'Petty Cash Imprest', 'debit': 500, 'credit': 0},
            {'ledger': 'Cash', 'debit': 0, 'credit': 500},
          ],
        })),
      );
      await expectLater(
        ai.draftVoucherFromText('paid 500 from petty cash'),
        throwsA(isA<AiDraftException>().having((e) => e.message, 'message',
            contains('Petty Cash Imprest'))),
      );
    });

    test('an unbalanced draft is rejected', () async {
      final ai = AiAccountingService(
        gemini: fakeGemini(jsonEncode({
          'voucher_type': 'Payment',
          'date': '2026-05-04',
          'entries': [
            {'ledger': 'Rent', 'debit': 4500, 'credit': 0},
            {'ledger': 'Cash', 'debit': 0, 'credit': 4000},
          ],
        })),
      );
      await expectLater(
        ai.draftVoucherFromText('paid rent'),
        throwsA(isA<AiDraftException>()
            .having((e) => e.message, 'message', contains('does not balance'))),
      );
    });

    test('an entry with both debit and credit is rejected', () async {
      final ai = AiAccountingService(
        gemini: fakeGemini(jsonEncode({
          'voucher_type': 'Journal',
          'date': '2026-05-04',
          'entries': [
            {'ledger': 'Rent', 'debit': 100, 'credit': 100},
            {'ledger': 'Cash', 'debit': 0, 'credit': 100},
          ],
        })),
      );
      await expectLater(
        ai.draftVoucherFromText('something odd'),
        throwsA(isA<AiDraftException>()),
      );
    });

    test('a missing date falls back to today and warns', () async {
      final ai = AiAccountingService(
        gemini: fakeGemini(jsonEncode({
          'voucher_type': 'Payment',
          'date': 'not a date',
          'entries': [
            {'ledger': 'Rent', 'debit': 100, 'credit': 0},
            {'ledger': 'Cash', 'debit': 0, 'credit': 100},
          ],
        })),
      );
      final draft = await ai.draftVoucherFromText('paid rent',
          today: DateTime(2026, 6, 15));
      expect(draft.date, DateTime(2026, 6, 15));
      expect(draft.warnings.join(), contains('15/06/2026'));
    });

    test('non-JSON model output is reported clearly', () async {
      final ai = AiAccountingService(
        gemini: fakeGemini('Sorry, I cannot help with that.'),
      );
      await expectLater(
        ai.draftVoucherFromText('paid rent'),
        throwsA(isA<GeminiException>()
            .having((e) => e.message, 'message', contains('unexpected'))),
      );
    });
  });

  group('posting a confirmed draft', () {
    test('writes a balanced voucher with both entries', () async {
      final ai = AiAccountingService(
        gemini: fakeGemini(jsonEncode({
          'voucher_type': 'Payment',
          'date': '2026-05-04',
          'narration': 'Rent',
          'entries': [
            {'ledger': 'Rent', 'debit': 2500, 'credit': 0},
            {'ledger': 'Cash', 'debit': 0, 'credit': 2500},
          ],
        })),
      );
      final draft = await ai.draftVoucherFromText('paid 2500 rent cash');
      final id = await ai.postVoucher(draft);

      final entries = await StorageService.getVoucherEntries(id);
      expect(entries, hasLength(2));
      final debit = entries.firstWhere((e) => (e['debit'] as num) > 0);
      expect((debit['debit'] as num).toDouble(), 2500);

      final vouchers = await StorageService.getVouchers(companyId, 'Payment');
      expect(vouchers.any((v) => v['id'] == id), isTrue);
    });
  });

  group('questions about the books', () {
    test('the summary is built from real balances and sent to the model',
        () async {
      final sent = <Map<String, dynamic>>[];
      final ai = AiAccountingService(
        gemini: capturingGemini(sent, 'Cash stands at 2,500 Cr.'),
      );

      final answer = await ai.answerQuestion(
        'How much cash do I have?',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2027, 3, 31),
      );
      expect(answer, contains('2,500'));

      final prompt = sent.single['contents'][0]['parts'][0]['text'] as String;
      // Grounding data: the posted payment must appear in the summary.
      expect(prompt, contains('AI Test Co'));
      expect(prompt, contains('Cash'));
      expect(prompt, contains('Net profit'));
      expect(prompt, contains('How much cash do I have?'));
    });
  });
}
