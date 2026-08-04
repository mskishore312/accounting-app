import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/financial_statement_service.dart';
import 'package:accounting_app/services/gemini_service.dart';

/// One side of a proposed voucher.
class ProposedEntry {
  final String ledgerName;
  final int ledgerId;
  final double debit;
  final double credit;

  const ProposedEntry({
    required this.ledgerName,
    required this.ledgerId,
    required this.debit,
    required this.credit,
  });
}

/// A voucher the AI suggests. Nothing is written to the books until the
/// user confirms it, so this is only ever a draft.
class ProposedVoucher {
  final String type;
  final DateTime date;
  final String narration;
  final List<ProposedEntry> entries;

  /// Things the user should look at (assumed date, guessed ledger, ...).
  final List<String> warnings;

  const ProposedVoucher({
    required this.type,
    required this.date,
    required this.narration,
    required this.entries,
    this.warnings = const [],
  });

  double get totalDebit =>
      entries.fold(0.0, (sum, e) => sum + e.debit);

  double get totalCredit =>
      entries.fold(0.0, (sum, e) => sum + e.credit);

  bool get isBalanced => (totalDebit - totalCredit).abs() < 0.005;
}

/// Raised when the model's answer cannot be turned into a valid voucher.
class AiDraftException implements Exception {
  final String message;
  const AiDraftException(this.message);
  @override
  String toString() => message;
}

/// The app's AI layer: turns plain language and bill photos into voucher
/// drafts, and answers questions about the books.
///
/// Every draft is validated against the company's real ledgers and must
/// balance before it is offered to the user — the model is never trusted
/// to invent accounts or arithmetic.
class AiAccountingService {
  final GeminiService _gemini;

  AiAccountingService({GeminiService? gemini})
      : _gemini = gemini ?? GeminiService();

  static const List<String> voucherTypes = [
    'Receipt',
    'Payment',
    'Journal',
    'Contra',
    'Sales',
    'Purchase',
  ];

  static final Map<String, dynamic> _voucherSchema = {
    'type': 'OBJECT',
    'properties': {
      'voucher_type': {'type': 'STRING', 'enum': voucherTypes},
      'date': {'type': 'STRING', 'description': 'YYYY-MM-DD'},
      'narration': {'type': 'STRING'},
      'entries': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'ledger': {'type': 'STRING'},
            'debit': {'type': 'NUMBER'},
            'credit': {'type': 'NUMBER'},
          },
          'required': ['ledger', 'debit', 'credit'],
        },
      },
      'notes': {'type': 'STRING'},
    },
    'required': ['voucher_type', 'date', 'entries'],
  };

  static const String _systemInstruction = '''
You are a bookkeeping assistant for an Indian double-entry accounting app
that follows Tally conventions. Convert the user's input into ONE voucher.

Rules you must follow:
- Use ONLY ledger names from the provided chart of accounts, spelled exactly.
- Total debits must equal total credits.
- Each entry has either a debit or a credit, never both non-zero.
- Money received into cash/bank is a Receipt; money paid out is a Payment;
  a transfer between two cash/bank accounts is a Contra; a credit sale is
  Sales; a credit purchase is Purchase; anything else is a Journal.
- Amounts are plain numbers without currency symbols or separators.
- If the input does not state a date, use the fallback date given to you
  and say so in "notes".
- If no sensible ledger exists for something, pick the closest available
  one and explain the choice in "notes". Never invent a ledger.
''';

  /// Chart of accounts as a compact prompt block.
  Future<String> _chartOfAccounts() async {
    final ledgers = await StorageService.getLedgers();
    if (ledgers.isEmpty) {
      throw const AiDraftException(
          'This company has no ledgers yet. Create some under Masters first.');
    }
    final lines = ledgers
        .map((l) => '- ${l['name']} (${l['classification'] ?? 'Primary'})')
        .join('\n');
    return lines;
  }

  /// Draft a voucher from a sentence like
  /// "paid 4,500 shop rent by cash yesterday".
  Future<ProposedVoucher> draftVoucherFromText(
    String input, {
    DateTime? today,
  }) async {
    final now = today ?? DateTime.now();
    final chart = await _chartOfAccounts();
    final prompt = '''
Chart of accounts:
$chart

Today's date is ${_iso(now)}. Use it as the fallback date.

Transaction described by the user:
"$input"
''';
    final json = await _gemini.generateJson(
      prompt: prompt,
      systemInstruction: _systemInstruction,
      schema: _voucherSchema,
    );
    return _validate(json, fallbackDate: now);
  }

  /// Draft a voucher by reading a bill or receipt photo.
  Future<ProposedVoucher> draftVoucherFromImage(
    String imagePath, {
    DateTime? today,
    String? hint,
  }) async {
    final now = today ?? DateTime.now();
    final chart = await _chartOfAccounts();
    final prompt = '''
Chart of accounts:
$chart

Today's date is ${_iso(now)}. Use it as the fallback date.

Read the attached bill or receipt image. Identify the supplier or
customer, the document date, the taxable amount and any GST, and draft
the matching voucher. If GST is shown separately, post it to the
appropriate Input/Output GST ledger when one exists.
${hint == null || hint.trim().isEmpty ? '' : '\nUser note: $hint'}
''';
    final json = await _gemini.generateJson(
      prompt: prompt,
      systemInstruction: _systemInstruction,
      images: [imagePath],
      schema: _voucherSchema,
    );
    return _validate(json, fallbackDate: now);
  }

  /// Answer a question about the books, grounded in the current numbers.
  Future<String> answerQuestion(
    String question, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final summary = await buildBooksSummary(
      startDate: startDate,
      endDate: endDate,
    );
    final prompt = '''
Here is the current state of the books.

$summary

Question: $question

Answer in at most six short lines, using only the figures above. Amounts
are Indian rupees. If the figures do not answer the question, say exactly
what is missing instead of guessing.
''';
    return _gemini.generate(
      prompt: prompt,
      systemInstruction:
          'You are a concise accounting analyst. Never invent numbers that '
          'are not in the data you are given.',
      temperature: 0.2,
    );
  }

  /// Compact, factual snapshot of the books used to ground answers.
  Future<String> buildBooksSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final company = await StorageService.getSelectedCompany();
    if (company == null) {
      throw const AiDraftException('No company selected.');
    }
    final booksFrom = company['books_from'] as String?;
    final ledgers = await StorageService.getLedgers();

    final buffer = StringBuffer()
      ..writeln('Company: ${company['name']}')
      ..writeln('Period: ${_display(startDate)} to ${_display(endDate)}')
      ..writeln('')
      ..writeln('Ledger balances (Dr positive, Cr negative):');

    for (final ledger in ledgers) {
      final balance = await FinancialStatementService.calculateLedgerBalance(
        ledgerId: ledger['id'] as int,
        ledger: ledger,
        startDate: startDate,
        endDate: endDate,
        booksBeginningDate: booksFrom,
      );
      if (balance.abs() < 0.005) continue;
      buffer.writeln(
          '- ${ledger['name']} [${ledger['classification'] ?? 'Primary'}]: '
          '${balance.toStringAsFixed(2)}');
    }

    final trading = await FinancialStatementService.calculateTradingAccount(
      startDate: startDate,
      endDate: endDate,
      booksBeginningDate: booksFrom,
    );
    final pl = await FinancialStatementService.calculateProfitAndLoss(
      startDate: startDate,
      endDate: endDate,
      booksBeginningDate: booksFrom,
      grossProfit: trading['grossProfit'] as double,
    );

    buffer
      ..writeln('')
      ..writeln('Sales: ${(trading['totalSales'] as double).toStringAsFixed(2)}')
      ..writeln(
          'Purchases: ${(trading['totalPurchases'] as double).toStringAsFixed(2)}')
      ..writeln(
          'Direct expenses: ${(trading['totalDirectExpenses'] as double).toStringAsFixed(2)}')
      ..writeln(
          'Indirect expenses: ${(pl['totalIndirectExpenses'] as double).toStringAsFixed(2)}')
      ..writeln(
          'Opening stock: ${(trading['openingStock'] as double).toStringAsFixed(2)}')
      ..writeln(
          'Closing stock: ${(trading['closingStock'] as double).toStringAsFixed(2)}')
      ..writeln(
          'Gross profit: ${(trading['grossProfit'] as double).toStringAsFixed(2)}')
      ..writeln('Net profit: ${(pl['netProfit'] as double).toStringAsFixed(2)}');

    return buffer.toString();
  }

  /// Persist a confirmed draft as a real voucher. Returns its id.
  Future<int> postVoucher(ProposedVoucher draft) async {
    if (!draft.isBalanced) {
      throw const AiDraftException('Refusing to post an unbalanced voucher.');
    }
    final company = await StorageService.getSelectedCompany();
    if (company == null) {
      throw const AiDraftException('No company selected.');
    }
    final number = await StorageService.getNextVoucherNumber(draft.type);
    final db = await StorageService().database;
    return db.transaction<int>((txn) async {
      final voucherId = await StorageService.saveVoucher({
        'company_id': company['id'],
        'voucher_number': number,
        'voucher_date': _iso(draft.date),
        'type': draft.type,
        'total': draft.totalDebit,
      }, txn);
      for (final entry in draft.entries) {
        await StorageService.insertVoucherEntry({
          'voucher_id': voucherId,
          'ledger_id': entry.ledgerId,
          'description': draft.narration,
          'debit': entry.debit,
          'credit': entry.credit,
        }, txn);
      }
      return voucherId;
    });
  }

  // --- validation ---

  /// Turns the model's JSON into a draft, rejecting anything that would
  /// corrupt the books: unknown ledgers, bad numbers, unbalanced entries.
  Future<ProposedVoucher> _validate(
    Map<String, dynamic> json, {
    required DateTime fallbackDate,
  }) async {
    final ledgers = await StorageService.getLedgers();
    final byName = {
      for (final l in ledgers) (l['name'] as String).toLowerCase(): l,
    };

    final type = (json['voucher_type'] as String?)?.trim() ?? 'Journal';
    if (!voucherTypes.contains(type)) {
      throw AiDraftException('Unsupported voucher type "$type".');
    }

    final warnings = <String>[];
    final notes = (json['notes'] as String?)?.trim();
    if (notes != null && notes.isNotEmpty) warnings.add(notes);

    DateTime date;
    final rawDate = (json['date'] as String?)?.trim();
    try {
      date = DateTime.parse(rawDate!);
    } catch (_) {
      date = fallbackDate;
      warnings.add('Could not read a date, used ${_display(fallbackDate)}.');
    }

    final rawEntries = json['entries'] as List<dynamic>?;
    if (rawEntries == null || rawEntries.length < 2) {
      throw const AiDraftException(
          'The draft needs at least two entries to balance.');
    }

    final entries = <ProposedEntry>[];
    for (final raw in rawEntries) {
      final entry = raw as Map<String, dynamic>;
      final name = (entry['ledger'] as String?)?.trim() ?? '';
      final ledger = byName[name.toLowerCase()];
      if (ledger == null) {
        throw AiDraftException(
            'The draft refers to "$name", which is not a ledger in this '
            'company. Create it first, or rephrase.');
      }
      final debit = _toAmount(entry['debit']);
      final credit = _toAmount(entry['credit']);
      if (debit < 0 || credit < 0) {
        throw const AiDraftException('Negative amounts are not allowed.');
      }
      if (debit > 0 && credit > 0) {
        throw AiDraftException(
            'Entry for "$name" has both a debit and a credit.');
      }
      if (debit == 0 && credit == 0) continue;
      entries.add(ProposedEntry(
        ledgerName: ledger['name'] as String,
        ledgerId: ledger['id'] as int,
        debit: debit,
        credit: credit,
      ));
    }

    if (entries.length < 2) {
      throw const AiDraftException(
          'The draft needs at least two entries with amounts.');
    }

    final draft = ProposedVoucher(
      type: type,
      date: date,
      narration: (json['narration'] as String?)?.trim() ?? '',
      entries: entries,
      warnings: warnings,
    );
    if (!draft.isBalanced) {
      throw AiDraftException(
          'The draft does not balance: debits ${draft.totalDebit.toStringAsFixed(2)} '
          'vs credits ${draft.totalCredit.toStringAsFixed(2)}.');
    }
    return draft;
  }

  static double _toAmount(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '')) ?? 0;
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _display(DateTime? d) => d == null
      ? 'all dates'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
