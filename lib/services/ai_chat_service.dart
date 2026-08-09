import 'dart:convert';

import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/ai_accounting_service.dart';
import 'package:accounting_app/services/gemini_service.dart';

enum ChatRole { user, assistant }

/// What the assistant decided the user wanted.
enum ChatIntent { answer, voucher, bankStatement, navigate }

/// An account a draft needs that the books do not have yet.
class ProposedLedger {
  final String name;
  final String group;

  const ProposedLedger({required this.name, required this.group});
}

/// A screen the assistant wants to open, with the settings it should carry.
///
/// "Show me the trial balance for May" is a navigation with a period, not a
/// question — the app already knows how to draw that report, so the assistant
/// should set it up and get out of the way.
class ChatNavigation {
  final String target;
  final String? ledgerName;
  final DateTime? startDate;
  final DateTime? endDate;

  const ChatNavigation({
    required this.target,
    this.ledgerName,
    this.startDate,
    this.endDate,
  });

  bool get hasPeriod => startDate != null && endDate != null;

  /// Screens the assistant is allowed to open, and what to call them.
  static const Map<String, String> targets = {
    'daybook': 'Day Book',
    'trial_balance': 'Trial Balance',
    'balance_sheet': 'Balance Sheet',
    'profit_and_loss': 'Trading and Profit & Loss',
    'cash_bank_book': 'Cash / Bank Book',
    'group_summary': 'Group Summary',
    'ledger': 'Ledger',
    'list_of_accounts': 'List of Accounts',
    'registers': 'Registers',
    'final_reports': 'Final Reports',
    'reports': 'Reports',
    'vouchers': 'Vouchers',
    'account_masters': 'Masters',
  };

  String get label => targets[target] ?? target;
}

/// One bubble in the conversation.
///
/// An assistant message may carry a draft the user still has to act on:
/// [voucher] for a single entry, [bankRows] for a statement. Neither has
/// touched the books until the user confirms it, at which point [settled]
/// records that the card is no longer actionable.
class ChatMessage {
  final ChatRole role;
  final String text;
  final List<String> images;
  final ProposedVoucher? voucher;
  final List<ProposedBankRow>? bankRows;
  final ChatNavigation? navigation;

  /// Accounts the draft needs before it can be built, and the raw draft that
  /// is waiting on them. Once they exist the voucher is re-validated.
  final List<ProposedLedger>? pendingLedgers;
  final Map<String, dynamic>? pendingVoucher;

  bool settled;

  /// Row id once stored, so the message can be settled in the history too.
  int? id;

  /// Set on a message read back from storage that once carried a draft.
  /// The draft itself is not restored — the ledgers and images behind it may
  /// have moved on — so the conversation shows what happened instead of
  /// offering to post something stale.
  final String? historyNote;

  ChatMessage({
    required this.role,
    required this.text,
    this.images = const [],
    this.voucher,
    this.bankRows,
    this.navigation,
    this.pendingLedgers,
    this.pendingVoucher,
    this.settled = false,
    this.id,
    this.historyNote,
  });

  bool get hasDraft => voucher != null || bankRows != null;

  /// What kind of draft this carried, for the history row.
  String? get draftKind => voucher != null
      ? 'voucher'
      : bankRows != null
          ? 'bank_rows'
          : null;

  /// One-line description of the draft, kept in the history.
  String? get draftSummary {
    final v = voucher;
    if (v != null) {
      return '${v.type} voucher, ${v.totalDebit.toStringAsFixed(2)}';
    }
    final rows = bankRows;
    if (rows != null) return '${rows.length} statement transactions';
    return null;
  }
}

/// Drives the in-app chatbot.
///
/// One Gemini call per user message decides between answering a question,
/// drafting a voucher, and reading a bank statement, and returns the payload
/// for whichever it chose. Anything that would change the books comes back as
/// a draft for the user to confirm.
class AiChatService {
  final GeminiService _gemini;
  final AiAccountingService _accounting;

  AiChatService({GeminiService? gemini, AiAccountingService? accounting})
      : _gemini = gemini ?? GeminiService(),
        _accounting = accounting ?? AiAccountingService();

  AiAccountingService get accounting => _accounting;

  /// The books summary is expensive to build, so it is cached for the
  /// conversation and dropped whenever something is posted.
  String? _booksCache;

  void invalidateBooks() => _booksCache = null;

  // --- history ---

  /// The stored conversation for the selected company, oldest first.
  ///
  /// Drafts are not revived: a message that carried one comes back as plain
  /// text plus a note saying what it was, because the ledgers, images and
  /// balances it was built from may all have changed since.
  Future<List<ChatMessage>> loadHistory() async {
    final rows = await StorageService.getChatMessages();
    return rows.map((row) {
      final kind = row['draft_kind'] as String?;
      final summary = row['draft_summary'] as String?;
      final settled = (row['settled'] as int? ?? 0) == 1;
      return ChatMessage(
        id: row['id'] as int?,
        role: row['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
        text: row['text'] as String? ?? '',
        images: _decodeImages(row['images'] as String?),
        settled: true,
        historyNote: kind == null
            ? null
            : '${summary ?? 'Draft'} — ${settled ? 'posted' : 'not posted'}',
      );
    }).toList();
  }

  /// Store a message and stamp it with its row id.
  Future<void> remember(ChatMessage message) async {
    try {
      message.id = await StorageService.saveChatMessage({
        'role': message.role == ChatRole.user ? 'user' : 'assistant',
        'text': message.text,
        'images': message.images.isEmpty ? null : jsonEncode(message.images),
        'draft_kind': message.draftKind,
        'draft_summary': message.draftSummary,
        'settled': message.settled ? 1 : 0,
      });
    } catch (_) {
      // History is a convenience; never break the conversation over it.
    }
  }

  /// Record that a draft was acted on, so a reopened chat says so.
  Future<void> rememberSettled(ChatMessage message) async {
    final id = message.id;
    if (id == null) return;
    try {
      await StorageService.markChatMessageSettled(id);
    } catch (_) {}
  }

  Future<void> clearHistory() => StorageService.clearChatMessages();

  /// Create the accounts a draft was waiting on, skipping any that turned up
  /// in the meantime.
  Future<void> createLedgers(List<ProposedLedger> proposals) async {
    final company = await StorageService.getSelectedCompany();
    if (company == null) {
      throw const AiDraftException('No company selected.');
    }
    for (final proposal in proposals) {
      final ledgers = await StorageService.getLedgers();
      final exists = ledgers.any((l) =>
          (l['name'] as String).toLowerCase() == proposal.name.toLowerCase());
      if (exists) continue;
      await StorageService.saveLedger({
        'company_id': company['id'],
        'name': proposal.name,
        'classification': proposal.group,
        'balance': 0.0,
      });
    }
  }

  /// Re-validate a draft that was held back, now that its accounts exist.
  Future<ProposedVoucher> rebuildDraft(Map<String, dynamic> raw) =>
      _accounting.validateDraft(raw, fallbackDate: DateTime.now());

  static List<String> _decodeImages(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
    return const [];
  }

  /// How many earlier turns to replay. Older turns keep their text but drop
  /// their images, which otherwise dominate the request payload.
  static const int _historyTurns = 10;

  static final Map<String, dynamic> _schema = {
    'type': 'OBJECT',
    'properties': {
      'intent': {
        'type': 'STRING',
        'enum': ['answer', 'voucher', 'bank_statement', 'navigate'],
      },
      'navigation': {
        'type': 'OBJECT',
        'properties': {
          'target': {
            'type': 'STRING',
            'enum': ChatNavigation.targets.keys.toList(),
          },
          'ledger': {
            'type': 'STRING',
            'description': 'Ledger name, only when target is "ledger"',
          },
          'start_date': {'type': 'STRING', 'description': 'YYYY-MM-DD'},
          'end_date': {'type': 'STRING', 'description': 'YYYY-MM-DD'},
        },
      },
      'new_ledgers': {
        'type': 'ARRAY',
        'description':
            'Accounts a voucher needs that do not exist in the chart yet',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'name': {'type': 'STRING'},
            'group': {
              'type': 'STRING',
              'description':
                  'e.g. Indirect Expenses, Sundry Creditors, Sundry Debtors',
            },
          },
          'required': ['name', 'group'],
        },
      },
      'reply': {
        'type': 'STRING',
        'description': 'What to say to the user, always filled in.',
      },
      'voucher': {
        'type': 'OBJECT',
        'properties': {
          'voucher_type': {
            'type': 'STRING',
            'enum': AiAccountingService.voucherTypes,
          },
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
      },
    },
    'required': ['intent', 'reply'],
  };

  static const String _systemInstruction = '''
You are the assistant inside an Indian double-entry accounting app that
follows Tally conventions. Every reply must set "intent" and "reply".

Choose the intent:
- "navigate" when the user wants to SEE something the app already draws: a
  report, a register, a ledger, a list. "show me the trial balance", "open
  the day book for May", "what does Rent look like this quarter". Fill in
  "navigation" and keep "reply" to one short line.
- "bank_statement" when the user attaches a bank or passbook statement and
  wants its transactions imported. Set only intent and reply; the app reads
  the rows separately.
- "voucher" when the user describes one transaction, or attaches a single
  bill, invoice or receipt to be entered. Fill in "voucher".
- "answer" for questions the figures can settle in a sentence, and anything
  else. Fill in "reply" only.

Prefer "navigate" over "answer" whenever a report would show it better than a
sentence would. Set start_date and end_date when the user names a period;
leave them out to keep the period the user is already in.

When drafting a voucher:
- Prefer ledger names from the chart of accounts, spelled exactly.
- If the entry genuinely needs an account that does not exist yet, use the
  name you want in "entries" AND list it in "new_ledgers" with its group.
  The user is offered it as a ledger to create, so this is expected — but
  look hard for an existing account first, even if spelled differently, and
  never propose a second account for a party already in the chart.
- Total debits must equal total credits.
- Each entry has either a debit or a credit, never both.
- Money into cash/bank is a Receipt; money out is a Payment; a transfer
  between two cash/bank accounts is a Contra; a credit sale is Sales; a
  credit purchase is Purchase; anything else is a Journal.
- Amounts are plain numbers, no symbols or separators.
- With no date given, use the fallback date and say so in "notes".

When answering a question, use only the figures you are given, keep it to a
few short lines, and say what is missing rather than guessing. Amounts are
Indian rupees.

"reply" is shown to the user, so write it as a human sentence. When you have
drafted a voucher, describe it in one line rather than repeating every
number: the app shows the draft as a card next to your reply.
''';

  /// Send one user message and get the assistant's response.
  Future<ChatMessage> send({
    required String text,
    List<String> images = const [],
    required List<ChatMessage> history,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final now = DateTime.now();
    final chart = await _accounting.chartOfAccountsBlock();
    final books = _booksCache ??= await _accounting.buildBooksSummary(
      startDate: startDate,
      endDate: endDate,
    );

    final prompt = '''
Chart of accounts:
$chart

Current state of the books:
$books

Today's date is ${_iso(now)}. Use it as the fallback date.

User says: "$text"
${images.isEmpty ? '' : '\n${images.length} image(s) are attached.'}
''';

    final json = await _gemini.generateJson(
      prompt: prompt,
      systemInstruction: _systemInstruction,
      images: images,
      history: _replay(history),
      schema: _schema,
      timeout: const Duration(seconds: 60),
    );

    final intent = _parseIntent(json['intent'] as String?);
    final reply = (json['reply'] as String?)?.trim() ?? '';

    if (intent == ChatIntent.bankStatement) {
      if (images.isEmpty) {
        return ChatMessage(
          role: ChatRole.assistant,
          text: 'Attach a photo or scan of the statement and I will read it.',
        );
      }
      final rows = await _accounting.extractBankRows(images, hint: text);
      return ChatMessage(
        role: ChatRole.assistant,
        text: reply.isEmpty
            ? 'I read ${rows.length} transactions. Check them and post when ready.'
            : reply,
        bankRows: rows,
      );
    }

    if (intent == ChatIntent.navigate) {
      final nav = _parseNavigation(json['navigation']);
      if (nav != null) {
        return ChatMessage(
          role: ChatRole.assistant,
          text: reply.isEmpty ? 'Opening ${nav.label}.' : reply,
          navigation: nav,
        );
      }
    }

    if (intent == ChatIntent.voucher) {
      final raw = json['voucher'];
      if (raw is Map<String, dynamic>) {
        // A draft that fails validation is reported as text rather than
        // thrown, so the conversation survives a bad suggestion.
        try {
          final draft = await _accounting.validateDraft(raw, fallbackDate: now);
          return ChatMessage(
            role: ChatRole.assistant,
            text: reply.isEmpty ? 'Here is the entry I would make.' : reply,
            voucher: draft,
          );
        } on AiDraftException catch (e) {
          // The usual cause is an account the books do not have yet. Offer to
          // create it instead of dead-ending the conversation.
          final missing = await _missingLedgers(json, raw);
          if (missing.isNotEmpty) {
            return ChatMessage(
              role: ChatRole.assistant,
              text: reply.isEmpty
                  ? 'This needs an account you do not have yet.'
                  : reply,
              pendingLedgers: missing,
              pendingVoucher: raw,
            );
          }
          return ChatMessage(
            role: ChatRole.assistant,
            text: 'I could not build a valid entry: ${e.message}',
          );
        }
      }
    }

    return ChatMessage(
      role: ChatRole.assistant,
      text: reply.isEmpty ? 'I did not have an answer for that.' : reply,
    );
  }

  /// Recent turns as Gemini history. Images are kept only on the most recent
  /// user turn that had them, so a long conversation does not resend photos.
  List<GeminiTurn> _replay(List<ChatMessage> history) {
    final recent = history.length <= _historyTurns
        ? history
        : history.sublist(history.length - _historyTurns);
    return recent
        .where((m) => m.text.trim().isNotEmpty)
        .map((m) => GeminiTurn(
              fromUser: m.role == ChatRole.user,
              text: m.text,
            ))
        .toList();
  }

  static ChatIntent _parseIntent(String? value) {
    switch (value) {
      case 'voucher':
        return ChatIntent.voucher;
      case 'bank_statement':
        return ChatIntent.bankStatement;
      case 'navigate':
        return ChatIntent.navigate;
      default:
        return ChatIntent.answer;
    }
  }

  static ChatNavigation? _parseNavigation(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final target = (raw['target'] as String?)?.trim() ?? '';
    if (!ChatNavigation.targets.containsKey(target)) return null;

    DateTime? parse(String key) {
      final value = (raw[key] as String?)?.trim();
      if (value == null || value.isEmpty) return null;
      return DateTime.tryParse(value);
    }

    final ledger = (raw['ledger'] as String?)?.trim();
    return ChatNavigation(
      target: target,
      ledgerName: ledger == null || ledger.isEmpty ? null : ledger,
      startDate: parse('start_date'),
      endDate: parse('end_date'),
    );
  }

  /// Accounts a rejected draft referred to that the books do not have.
  ///
  /// Takes the model's own "new_ledgers" list where given, and otherwise
  /// works out which entry names are unknown, so a draft that simply named a
  /// missing account still leads somewhere useful.
  Future<List<ProposedLedger>> _missingLedgers(
    Map<String, dynamic> json,
    Map<String, dynamic> voucher,
  ) async {
    final ledgers = await StorageService.getLedgers();
    final known = {
      for (final l in ledgers) (l['name'] as String).toLowerCase(),
    };

    final groups = <String, String>{};
    for (final raw in (json['new_ledgers'] as List<dynamic>? ?? const [])) {
      if (raw is! Map<String, dynamic>) continue;
      final name = (raw['name'] as String?)?.trim() ?? '';
      final group = (raw['group'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      groups[name.toLowerCase()] = group;
    }

    final missing = <String, ProposedLedger>{};
    for (final raw in (voucher['entries'] as List<dynamic>? ?? const [])) {
      if (raw is! Map<String, dynamic>) continue;
      final name = (raw['ledger'] as String?)?.trim() ?? '';
      if (name.isEmpty || known.contains(name.toLowerCase())) continue;
      // Never offer to create something the books already have under a
      // different spelling.
      if (AiAccountingService.findExistingLedger(name, ledgers) != null) {
        continue;
      }
      missing.putIfAbsent(
        name.toLowerCase(),
        () => ProposedLedger(
          name: name,
          group: AiAccountingService.normaliseGroup(groups[name.toLowerCase()]),
        ),
      );
    }
    return missing.values.toList();
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
