import 'dart:convert';

import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/ai_accounting_service.dart';
import 'package:accounting_app/services/gemini_service.dart';

enum ChatRole { user, assistant }

/// What the assistant decided the user wanted.
enum ChatIntent { answer, voucher, bankStatement }

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
        'enum': ['answer', 'voucher', 'bank_statement'],
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
- "bank_statement" when the user attaches a bank or passbook statement and
  wants its transactions imported. Set only intent and reply; the app reads
  the rows separately.
- "voucher" when the user describes one transaction, or attaches a single
  bill, invoice or receipt to be entered. Fill in "voucher".
- "answer" for questions about the books, and for anything else. Fill in
  "reply" only.

When drafting a voucher:
- Use ONLY ledger names from the chart of accounts, spelled exactly.
- Total debits must equal total credits.
- Each entry has either a debit or a credit, never both.
- Money into cash/bank is a Receipt; money out is a Payment; a transfer
  between two cash/bank accounts is a Contra; a credit sale is Sales; a
  credit purchase is Purchase; anything else is a Journal.
- Amounts are plain numbers, no symbols or separators.
- With no date given, use the fallback date and say so in "notes".
- Never invent a ledger. Pick the closest one and explain it in "notes".

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
      default:
        return ChatIntent.answer;
    }
  }

  static String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
