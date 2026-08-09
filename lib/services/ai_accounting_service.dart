import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/bank_statement_service.dart';
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

/// One line read off a bank statement, awaiting review.
///
/// Deliberately mutable: the review table edits these in place before any
/// of them become vouchers.
class ProposedBankRow {
  DateTime date;
  String description;
  double amount;
  bool isDeposit;
  int? ledgerId;
  String? ledgerName;

  /// Why this counterparty was chosen, shown next to it in the review table.
  String suggestionLabel;

  /// A ledger name the model proposed that this company does not have, with
  /// the group it belongs under. The row is still assigned something postable
  /// (usually Suspense), but the review offers this as a one-tap creation —
  /// it is normally the account the books are actually missing.
  String? proposedLedgerName;
  String? proposedLedgerGroup;

  bool get hasProposal =>
      proposedLedgerName != null && proposedLedgerName!.isNotEmpty;

  /// True only for a guess strong enough that it does not need a second look.
  /// Suspense is never confident.
  bool confident;

  bool selected;

  ProposedBankRow({
    required this.date,
    required this.description,
    required this.amount,
    required this.isDeposit,
    this.ledgerId,
    this.ledgerName,
    this.suggestionLabel = '',
    this.proposedLedgerName,
    this.proposedLedgerGroup,
    this.confident = false,
    this.selected = true,
  });

  bool get isReady => ledgerId != null && amount > 0;

  /// Assigned, but the user should still look at it.
  bool get needsReview => ledgerId != null && !confident;

  /// Record a ledger the user picked themselves.
  void chooseLedger(int id, String name) {
    ledgerId = id;
    ledgerName = name;
    suggestionLabel = 'Chosen by you';
    confident = true;
  }
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
  Future<String> chartOfAccountsBlock() async {
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
    final chart = await chartOfAccountsBlock();
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
    return validateDraft(json, fallbackDate: now);
  }

  /// Draft a voucher by reading a bill or receipt photo.
  Future<ProposedVoucher> draftVoucherFromImage(
    String imagePath, {
    DateTime? today,
    String? hint,
  }) async {
    final now = today ?? DateTime.now();
    final chart = await chartOfAccountsBlock();
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
    return validateDraft(json, fallbackDate: now);
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

  // --- bank statements ---

  static final Map<String, dynamic> _bankRowsSchema = {
    'type': 'OBJECT',
    'properties': {
      'rows': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'date': {'type': 'STRING', 'description': 'YYYY-MM-DD'},
            'description': {'type': 'STRING'},
            'amount': {'type': 'NUMBER'},
            'direction': {
              'type': 'STRING',
              'enum': ['deposit', 'withdrawal'],
            },
            'ledger': {
              'type': 'STRING',
              'description':
                  'Existing ledger from the chart of accounts, or "" if none fits',
            },
            'new_ledger_name': {
              'type': 'STRING',
              'description':
                  'When no existing ledger fits, the account this should be '
                      'posted to, named from the narration. "" if unclear.',
            },
            'new_ledger_group': {
              'type': 'STRING',
              'description': 'Group for new_ledger_name',
              'enum': suggestableGroups,
            },
          },
          'required': ['date', 'description', 'amount', 'direction'],
        },
      },
      'notes': {'type': 'STRING'},
    },
    'required': ['rows'],
  };

  /// Groups the model may put a proposed new ledger under. Kept narrow: these
  /// are the ones a bank narration can actually imply.
  static const List<String> suggestableGroups = [
    'Sundry Debtors',
    'Sundry Creditors',
    'Indirect Expenses',
    'Direct Expenses',
    'Indirect Income',
    'Sales Accounts',
    'Purchase Accounts',
    'Duties & Taxes',
    'Bank Accounts',
    'Cash-in-hand',
    'Loans (Liability)',
    'Loans & Advances (Asset)',
    'Fixed Assets',
    'Capital Account',
  ];

  static const String _bankSystemInstruction = '''
You read Indian bank statements and turn them into a table of transactions.

Rules you must follow:
- One row per transaction, in the order they appear on the statement.
- "deposit" means money came into the account; "withdrawal" means it left.
- Read the amount for the transaction itself, never the running balance.
- Amounts are plain positive numbers, no currency symbols or separators.
- Do not include header rows, opening balance lines, or closing totals.

Choosing the other side of each entry:
- Look through the chart of accounts FIRST. Use an existing ledger whenever
  one plausibly refers to the same party or purpose, even if the narration
  spells it differently: "NAVEEN" belongs to an existing "Naveen Kumar", and
  "EB BILL" belongs to an existing "Electricity". Put its exact name in
  "ledger" and leave "new_ledger_name" empty. Creating a duplicate account
  for a party you already have is the worst outcome here.
- Only when nothing existing fits, leave "ledger" empty and propose an
  account in "new_ledger_name", with a group in "new_ledger_group". The user
  will be offered it as a ledger to create, so this is expected and useful —
  do not hold back merely because the name is not in the chart yet.
- Be consistent across the whole statement. If the same counterparty appears
  in several rows, every one of them must carry the identical name, spelled
  the same way. Never split one party across two spellings.
- Name it from the narration. Indian bank narrations bury the counterparty in
  reference codes: "UPI/231958450352/CR/NAVEEN/PUNB/xyz/UPI" is a payment
  involving NAVEEN, so propose "Naveen". Strip the rails and reference
  numbers (UPI, NEFT, IMPS, RTGS, ACH, CR, DR, bank codes, long digit runs)
  and keep the human or business name. Write it in Title Case.
- Money coming in from a person or business is usually Sundry Debtors; money
  going out to one is usually Sundry Creditors. A recognisable expense —
  rent, fuel, electricity, fees, salary — is an expense group instead.
- Only when the narration names nobody at all, such as a bare ATM withdrawal
  or a bank charge with no payee, leave both empty.
''';

  /// Read a bank statement image (or several pages) into editable rows.
  ///
  /// Nothing is validated as strictly as a voucher here: an unrecognised
  /// ledger name leaves the row unassigned for the user to fix, because
  /// rejecting a whole statement over one bad guess helps nobody.
  Future<List<ProposedBankRow>> extractBankRows(
    List<String> imagePaths, {
    String? hint,
  }) async {
    if (imagePaths.isEmpty) {
      throw const AiDraftException('Attach a statement image first.');
    }
    final chart = await chartOfAccountsBlock();
    final prompt = '''
Chart of accounts:
$chart

Read every transaction from the attached bank statement image(s).
${hint == null || hint.trim().isEmpty ? '' : '\nUser note: $hint'}
''';
    final json = await _gemini.generateJson(
      prompt: prompt,
      systemInstruction: _bankSystemInstruction,
      images: imagePaths,
      schema: _bankRowsSchema,
      timeout: const Duration(seconds: 90),
    );

    var ledgers = await StorageService.getLedgers();
    var byName = {
      for (final l in ledgers) (l['name'] as String).toLowerCase(): l,
    };

    final rows = <ProposedBankRow>[];
    var needSuspense = false;

    for (final raw in (json['rows'] as List<dynamic>? ?? const [])) {
      final row = raw as Map<String, dynamic>;
      final amount = _toAmount(row['amount']);
      if (amount <= 0) continue;

      DateTime? date;
      try {
        date = DateTime.parse((row['date'] as String).trim());
      } catch (_) {
        continue; // a row without a usable date cannot be posted
      }

      final description = (row['description'] as String?)?.trim() ?? '';
      final isDeposit =
          (row['direction'] as String?)?.toLowerCase() == 'deposit';
      final named = (row['ledger'] as String?)?.trim() ?? '';
      final proposed = (row['new_ledger_name'] as String?)?.trim() ?? '';

      // 1. An existing ledger the model named outright.
      var existing = named.isEmpty ? null : byName[named.toLowerCase()];

      // 2. A name it gave — either an existing one it spelled differently, or
      //    one it wants created. Resolve against the real chart first, so a
      //    party we already have never gets a duplicate account.
      var matchedProposal = false;
      if (existing == null) {
        final candidate = named.isNotEmpty ? named : proposed;
        if (candidate.isNotEmpty) {
          existing = _findLedgerByName(candidate, ledgers);
          matchedProposal = existing != null;
        }
      }

      if (existing != null) {
        rows.add(ProposedBankRow(
          date: date,
          description: description,
          amount: amount,
          isDeposit: isDeposit,
          ledgerId: existing['id'] as int?,
          ledgerName: existing['name'] as String?,
          suggestionLabel: matchedProposal
              ? 'Matched to your existing ${existing['name']}'
              : 'Suggested by the assistant',
          confident: true,
        ));
        continue;
      }

      // 3. Nothing existing fits. Fall back to narration matching, then
      //    Suspense, but carry the proposal so it can be offered for creation.
      final suggestion = BankStatementService.suggestLedgerFor(
        description: description,
        isDeposit: isDeposit,
        candidates: ledgers,
      );
      if (suggestion.ledger == null) needSuspense = true;

      final wanted = proposed.isNotEmpty ? proposed : (named.isNotEmpty ? named : '');
      final label = wanted.isEmpty
          ? suggestion.label
          : 'No account for "$wanted" yet — create it?';

      rows.add(ProposedBankRow(
        date: date,
        description: description,
        amount: amount,
        isDeposit: isDeposit,
        ledgerId: suggestion.ledger?['id'] as int?,
        ledgerName: suggestion.ledger?['name'] as String?,
        suggestionLabel: label,
        proposedLedgerName: wanted.isEmpty ? null : wanted,
        proposedLedgerGroup: _groupFor(row['new_ledger_group'], isDeposit),
        confident: suggestion.confident,
      ));
    }

    // The model is asked to spell a party the same way everywhere, but it
    // wavers. Collapse near-identical proposals onto one spelling so a
    // statement never creates "Naveen" and "Naveen Kumar" for one person.
    _canonicaliseProposals(rows);

    if (rows.isEmpty) {
      throw const AiDraftException(
          'No transactions could be read from that image. Try a sharper photo '
          'showing the date, narration and amount columns.');
    }

    // Nothing could be matched and there is no Suspense ledger to park it in,
    // so make one rather than leaving rows unpostable.
    if (needSuspense) {
      final suspenseId = await _ensureSuspenseLedger();
      ledgers = await StorageService.getLedgers();
      byName = {
        for (final l in ledgers) (l['name'] as String).toLowerCase(): l,
      };
      for (final row in rows) {
        if (row.ledgerId != null) continue;
        row.ledgerId = suspenseId;
        row.ledgerName = _suspenseName;
        // Keep whatever we already knew — usually the ledger name the model
        // invented — rather than replacing it with a bare Suspense note.
        row.suggestionLabel =
            row.suggestionLabel.isEmpty || row.suggestionLabel.startsWith('No ')
                ? 'Parked in Suspense — please review'
                : '${row.suggestionLabel}; parked in Suspense';
      }
    }
    return rows;
  }

  static const String _suspenseName = 'Suspense A/c';

  /// Reduce a ledger name to something comparable: lower case, no
  /// punctuation, single spaces, and without the decorations Indian ledger
  /// names collect ("M/s", "A/c", "Pvt Ltd").
  static String _normalise(String name) {
    var n = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    for (final noise in const [
      ' m s ',
      ' a c ',
      ' pvt ',
      ' ltd ',
      ' limited ',
      ' private ',
      ' and ',
      ' the ',
    ]) {
      n = ' $n '.replaceAll(noise, ' ').trim();
    }
    return n.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// A name fit to become a ledger: trimmed, single-spaced.
  static String _tidy(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// An existing ledger that means the same thing as [name], or null.
  ///
  /// Deliberately conservative: exact match after normalising, or one name's
  /// words being a complete subset of the other's ("Naveen" inside "Naveen
  /// Kumar"). Anything looser starts merging unrelated parties.
  static Map<String, dynamic>? _findLedgerByName(
    String name,
    List<Map<String, dynamic>> ledgers,
  ) {
    final target = _normalise(name);
    if (target.isEmpty) return null;
    final targetWords = target.split(' ').toSet();

    Map<String, dynamic>? best;
    var bestWords = 0;
    for (final ledger in ledgers) {
      final candidate = _normalise(ledger['name'] as String? ?? '');
      if (candidate.isEmpty) continue;
      if (candidate == target) return ledger;

      final words = candidate.split(' ').toSet();
      final subset =
          words.containsAll(targetWords) || targetWords.containsAll(words);
      // A single shared word is only convincing if it is a real word.
      final shared = words.intersection(targetWords);
      if (!subset || shared.isEmpty) continue;
      if (shared.every((w) => w.length < 4)) continue;

      if (words.length > bestWords) {
        bestWords = words.length;
        best = ledger;
      }
    }
    return best;
  }

  /// A sane group for a proposed ledger, falling back on direction.
  static String _groupFor(dynamic raw, bool isDeposit) {
    final group = (raw as String?)?.trim() ?? '';
    if (suggestableGroups.contains(group)) return group;
    return isDeposit ? 'Sundry Debtors' : 'Sundry Creditors';
  }

  /// Make every row that means the same party propose the same ledger.
  ///
  /// Groups proposals by their normalised form and elects one spelling — the
  /// most frequent, then the longest, so "Naveen Kumar" beats a lone
  /// "Naveen" — then rewrites every row in the group to it.
  static void _canonicaliseProposals(List<ProposedBankRow> rows) {
    final counts = <String, Map<String, int>>{};
    for (final row in rows) {
      if (!row.hasProposal) continue;
      final key = _normalise(row.proposedLedgerName!);
      if (key.isEmpty) continue;
      // Tidy before counting, or "Biriya  Stores" and "Biriya Stores" are
      // rival spellings and the stray space can win on length.
      (counts[key] ??= <String, int>{}).update(
        _tidy(row.proposedLedgerName!),
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }

    final canonical = <String, String>{};
    final groups = <String, String>{};
    counts.forEach((key, spellings) {
      final best = spellings.entries.toList()
        ..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          return byCount != 0 ? byCount : b.key.length.compareTo(a.key.length);
        });
      canonical[key] = best.first.key;
    });

    // One group per party too, so the same account is not proposed under two
    // different heads on different rows.
    for (final row in rows) {
      if (!row.hasProposal) continue;
      final key = _normalise(row.proposedLedgerName!);
      groups.putIfAbsent(key, () => row.proposedLedgerGroup ?? 'Sundry Debtors');
    }

    for (final row in rows) {
      if (!row.hasProposal) continue;
      final key = _normalise(row.proposedLedgerName!);
      final name = canonical[key];
      if (name == null) continue;
      row.proposedLedgerName = name;
      row.proposedLedgerGroup = groups[key];
      row.suggestionLabel = 'No account for "$name" yet — create it?';
    }
  }

  /// The company's Suspense ledger, created if it does not exist yet.
  Future<int> _ensureSuspenseLedger() async {
    final ledgers = await StorageService.getLedgers();
    for (final ledger in ledgers) {
      if ((ledger['classification'] as String? ?? '') == 'Suspense A/c') {
        return ledger['id'] as int;
      }
    }
    final company = await StorageService.getSelectedCompany();
    if (company == null) {
      throw const AiDraftException('No company selected.');
    }
    return StorageService.saveLedger({
      'company_id': company['id'],
      'name': _suspenseName,
      'classification': 'Suspense A/c',
      'balance': 0.0,
    });
  }

  /// Post reviewed statement rows against [bankLedgerId]. All or nothing.
  Future<int> postBankRows({
    required int bankLedgerId,
    required List<ProposedBankRow> rows,
  }) async {
    final selected = rows.where((r) => r.selected).toList();
    if (selected.isEmpty) {
      throw const AiDraftException('No rows are selected.');
    }
    final unassigned = selected.where((r) => r.ledgerId == null).length;
    if (unassigned > 0) {
      throw AiDraftException(
          '$unassigned selected row(s) still need a counterparty ledger. '
          'Tap the ledger on each one to choose or create it.');
    }
    final clashing = selected.where((r) => r.ledgerId == bankLedgerId).toList();
    if (clashing.isNotEmpty) {
      throw AiDraftException(
          '${clashing.length} row(s) use the same ledger on both sides — a '
          'voucher cannot debit and credit "${clashing.first.ledgerName}". '
          'Give those rows a different counterparty, or pick another bank '
          'ledger for the statement.');
    }
    if (selected.any((r) => r.amount <= 0)) {
      throw const AiDraftException('Every selected row needs an amount above zero.');
    }
    return StorageService.importBankStatementTransactions(
      bankLedgerId: bankLedgerId,
      transactions: selected
          .map((r) => {
                'voucher_date': _iso(r.date),
                'description': r.description,
                'amount': r.amount,
                'is_deposit': r.isDeposit,
                'counterpart_ledger_id': r.ledgerId,
              })
          .toList(),
    );
  }

  // --- validation ---

  /// Turns the model's JSON into a draft, rejecting anything that would
  /// corrupt the books: unknown ledgers, bad numbers, unbalanced entries.
  Future<ProposedVoucher> validateDraft(
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
