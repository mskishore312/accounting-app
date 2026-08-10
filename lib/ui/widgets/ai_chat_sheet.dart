import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:accounting_app/services/ai_accounting_service.dart';
import 'package:accounting_app/services/ai_chat_service.dart';
import 'package:accounting_app/services/gemini_service.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:accounting_app/ui/ai_settings.dart';
import 'package:accounting_app/ui/bank_rows_review.dart';
import 'package:accounting_app/ui/widgets/ai_chat_launcher.dart';
import 'package:accounting_app/ui/widgets/ai_navigator.dart';

const Color _kGreen = Color(0xFF2C5545);

/// The assistant panel, opened from the floating button on any screen.
///
/// Holds a conversation, takes photos, and offers drafts the user confirms.
/// Nothing here writes to the books directly — posting always goes through
/// [AiAccountingService] after an explicit confirmation.
class AiChatSheet extends StatefulWidget {
  const AiChatSheet({super.key});

  /// Opens the panel as a draggable sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiChatSheet(),
    );
  }

  @override
  State<AiChatSheet> createState() => _AiChatSheetState();
}

class _AiChatSheetState extends State<AiChatSheet> {
  final _service = AiChatService();
  final _input = TextEditingController();
  final _picker = ImagePicker();

  /// Owned by [DraggableScrollableSheet]; using it for the message list is
  /// what lets the user drag the panel down from anywhere in the list.
  ScrollController? _scroll;

  final List<ChatMessage> _messages = [];
  final List<String> _pending = [];

  bool _busy = false;
  bool _configured = true;

  /// Progress of a batch read, shown next to Stop so a long run is not a
  /// blank spinner.
  String? _progress;

  /// One pager per invoice batch, keyed by message identity so a rebuild does
  /// not throw the user back to the first voucher.
  final Map<int, PageController> _pagers = {};
  final Map<int, int> _pages = {};

  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _checkConfig();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final past = await _service.loadHistory();
      if (!mounted) return;
      setState(() {
        _messages.insertAll(0, past);
        _loadingHistory = false;
      });
      _scrollToEnd();
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _confirmClearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear chat history?'),
        content: const Text(
          'This deletes the conversation on this device. Vouchers you already '
          'posted are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _service.clearHistory();
    if (!mounted) return;
    setState(_messages.clear);
  }

  @override
  void dispose() {
    _input.dispose();
    for (final pager in _pagers.values) {
      pager.dispose();
    }
    // Closing the panel mid-request should not leave one running.
    if (_busy) _service.stop();
    super.dispose();
  }

  Future<void> _checkConfig() async {
    final ok = await GeminiService.isConfigured();
    if (mounted) setState(() => _configured = ok);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scroll = _scroll;
      if (scroll == null || !scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty && _pending.isEmpty) return;
    if (_busy) return;

    final images = List<String>.from(_pending);
    final history = List<ChatMessage>.from(_messages);
    final outgoing =
        ChatMessage(role: ChatRole.user, text: text, images: images);

    setState(() {
      _messages.add(outgoing);
      _input.clear();
      _pending.clear();
      _busy = true;
    });
    _scrollToEnd();
    await _service.remember(outgoing);

    final period = Provider.of<PeriodService>(context, listen: false);
    try {
      final reply = await _service.send(
        text: text.isEmpty ? 'Read the attached image.' : text,
        images: images,
        history: history,
        startDate: period.startDate,
        endDate: period.endDate,
      );
      if (!mounted) return;
      setState(() => _messages.add(reply));
      await _service.remember(reply);
    } on AiDraftException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_error(e.message)));
    } on GeminiException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_error(e.message)));
      if (e.isConfigError) _checkConfig();
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_error('Something went wrong: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  ChatMessage _error(String message) =>
      ChatMessage(role: ChatRole.assistant, text: message);

  /// Read the attached images as a bank statement, without asking the model
  /// to work out that that is what they are. Intent routing gets a statement
  /// wrong often enough that this needs to be something the user can just say.
  Future<void> _importStatement() async {
    if (_busy || _pending.isEmpty) return;
    final images = List<String>.from(_pending);
    final text = _input.text.trim();
    final outgoing = ChatMessage(
      role: ChatRole.user,
      text: text.isEmpty ? 'Import these statement pages.' : text,
      images: images,
    );

    setState(() {
      _messages.add(outgoing);
      _input.clear();
      _pending.clear();
      _busy = true;
    });
    _scrollToEnd();
    await _service.remember(outgoing);

    try {
      final rows =
          await _service.accounting.extractBankRows(images, hint: text);
      if (!mounted) return;
      final reply = ChatMessage(
        role: ChatRole.assistant,
        text: 'I read ${rows.length} transactions. '
            'Check them and post when you are ready.',
        bankRows: rows,
      );
      setState(() => _messages.add(reply));
      await _service.remember(reply);
    } on AiDraftException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_error(e.message)));
    } on GeminiException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_error(e.message)));
      if (e.isConfigError) _checkConfig();
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_error('Could not read the statement: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  /// Abandon whatever is running. The request's socket is closed, so the
  /// answer never arrives rather than arriving unwanted.
  void _stop() {
    if (!_busy) return;
    _service.stop();
    setState(() {
      _busy = false;
      _progress = null;
      _messages.add(_error('Stopped.'));
    });
    _scrollToEnd();
  }

  /// Read each attached image as its own invoice, into one reviewable batch.
  Future<void> _readInvoices() async {
    if (_busy || _pending.isEmpty) return;
    final images = List<String>.from(_pending);
    final text = _input.text.trim();
    final outgoing = ChatMessage(
      role: ChatRole.user,
      text: text.isEmpty
          ? 'Enter these ${images.length} invoices.'
          : text,
      images: images,
    );

    _service.resume();
    setState(() {
      _messages.add(outgoing);
      _input.clear();
      _pending.clear();
      _busy = true;
      _progress = 'Reading invoice 1 of ${images.length}…';
    });
    _scrollToEnd();
    await _service.remember(outgoing);

    try {
      final drafts = await _service.draftInvoices(
        images,
        hint: text,
        onProgress: (done, total) {
          if (!mounted || done >= total) return;
          setState(() =>
              _progress = 'Reading invoice ${done + 1} of $total…');
        },
      );
      if (!mounted) return;
      final read = drafts.where((d) => d.error == null).length;
      final reply = ChatMessage(
        role: ChatRole.assistant,
        text: 'Read $read of ${images.length} invoices. '
            'Swipe through them and post when you are happy.',
        invoices: drafts,
      );
      setState(() => _messages.add(reply));
      await _service.remember(reply);
    } on GeminiCancelled {
      // _stop already said so.
    } on AiDraftException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_error(e.message)));
    } on GeminiException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_error(e.message)));
      if (e.isConfigError) _checkConfig();
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_error('Could not read the invoices: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
      _scrollToEnd();
    }
  }

  /// Read the attached images as one bill, invoice or receipt. The mirror of
  /// [_importStatement]: whichever way the model would have guessed, the user
  /// can say which it is.
  Future<void> _draftFromBill() async {
    if (_busy || _pending.isEmpty) return;
    final images = List<String>.from(_pending);
    final text = _input.text.trim();
    final outgoing = ChatMessage(
      role: ChatRole.user,
      text: text.isEmpty ? 'Enter this bill.' : text,
      images: images,
    );

    setState(() {
      _messages.add(outgoing);
      _input.clear();
      _pending.clear();
      _busy = true;
    });
    _scrollToEnd();
    await _service.remember(outgoing);

    try {
      final reply = await _service.draftFromBill(images, hint: text);
      if (!mounted) return;
      setState(() => _messages.add(reply));
      await _service.remember(reply);
    } on AiDraftException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_error(e.message)));
    } on GeminiException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_error(e.message)));
      if (e.isConfigError) _checkConfig();
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_error('Could not read the bill: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  Future<void> _attach(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final picked = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 2000);
        if (picked.isEmpty || !mounted) return;
        setState(() => _pending.addAll(picked.map((f) => f.path)));
      } else {
        final picked = await _picker.pickImage(
            source: source, imageQuality: 85, maxWidth: 2000);
        if (picked == null || !mounted) return;
        setState(() => _pending.add(picked.path));
      }
    } catch (e) {
      if (mounted) setState(() => _messages.add(_error('Could not attach: $e')));
    }
  }

  void _attachMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _kGreen),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _attach(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _kGreen),
              title: const Text('Choose images'),
              subtitle: const Text('Bills, receipts or bank statement pages'),
              onTap: () {
                Navigator.pop(context);
                _attach(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _postVoucher(ChatMessage message) async {
    final draft = message.voucher;
    if (draft == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _service.accounting.postVoucher(draft);
      _service.invalidateBooks();
      await _service.rememberSettled(message);
      if (!mounted) return;
      final confirmation = ChatMessage(
        role: ChatRole.assistant,
        text: 'Posted. The ${draft.type} voucher is in the books.',
      );
      setState(() {
        message.settled = true;
        _messages.add(confirmation);
      });
      await _service.remember(confirmation);
    } on AiDraftException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_error(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_error('Could not post: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  Future<void> _reviewRows(ChatMessage message) async {
    final rows = message.bankRows;
    if (rows == null) return;
    final posted = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => BankRowsReview(
          rows: rows,
          service: _service.accounting,
        ),
      ),
    );
    if (posted == null || !mounted) return;
    _service.invalidateBooks();
    await _service.rememberSettled(message);
    if (!mounted) return;
    final confirmation = ChatMessage(
      role: ChatRole.assistant,
      text: 'Posted $posted transaction(s) from the statement.',
    );
    setState(() {
      message.settled = true;
      _messages.add(confirmation);
    });
    await _service.remember(confirmation);
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, sheetScroll) {
        _scroll = sheetScroll;
        return Container(
        decoration: const BoxDecoration(
          color: Color(0xFFE0F2E9),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            _header(),
            if (!_configured) _configBanner(),
            Expanded(
              child: _loadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? _emptyState(sheetScroll)
                  : ListView.builder(
                      controller: sheetScroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _bubble(_messages[i]),
                    ),
            ),
            if (_busy) ...[
              const LinearProgressIndicator(minHeight: 2),
              if (_progress != null)
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    _progress!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ),
            ],
            _composer(),
          ],
        ),
        );
      },
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: const BoxDecoration(
          color: _kGreen,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'AI Assistant',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
            if (_messages.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.white, size: 20),
                tooltip: 'Clear chat history',
                onPressed: _busy ? null : _confirmClearHistory,
              ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white, size: 20),
              tooltip: 'AI Settings',
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AiSettings()));
                _checkConfig();
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );

  Widget _configBanner() => Container(
        width: double.infinity,
        color: Colors.amber.shade50,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'No Gemini API key yet — add one to use the assistant.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AiSettings()));
                _checkConfig();
              },
              child: const Text('Add key'),
            ),
          ],
        ),
      );

  Widget _emptyState(ScrollController controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.auto_awesome, size: 40, color: _kGreen),
          const SizedBox(height: 12),
          const Text(
            'Ask about your books, describe an entry, or attach a photo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _kGreen, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          ...[
            'paid 4500 shop rent by cash',
            'what is my net profit this period?',
            'attach a bank statement photo to import transactions',
            'photograph a bill to draft a purchase entry',
          ].map(
            (example) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: _kGreen)),
                  Expanded(
                    child: Text(example,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade700)),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _bubble(ChatMessage message) {
    final isUser = message.role == ChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isUser ? _kGreen : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kGreen.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.images.isNotEmpty) _thumbnails(message.images),
            if (message.text.isNotEmpty)
              SelectableText(
                message.text,
                style: TextStyle(color: isUser ? Colors.white : Colors.black87),
              ),
            if (message.historyNote != null) _historyNote(message.historyNote!),
            if (message.navigation != null) _navigationCard(message.navigation!),
            if (message.pendingLedgers != null) _pendingLedgersCard(message),
            if (message.invoices != null) _invoiceBatchCard(message),
            if (message.voucher != null) _voucherCard(message),
            if (message.bankRows != null) _rowsCard(message),
          ],
        ),
      ),
    );
  }

  Widget _thumbnails(List<String> paths) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: paths
              .map((p) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(p),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 64,
                        height: 64,
                        child: Icon(Icons.broken_image, size: 20),
                      ),
                    ),
                  ))
              .toList(),
        ),
      );

  /// Apply any period the assistant asked for, close the panel and open the
  /// screen. Navigation is acted on rather than merely offered: "show me the
  /// trial balance" wants the report, not a button that says Trial Balance.
  Future<void> _go(ChatNavigation nav) async {
    final period = Provider.of<PeriodService>(context, listen: false);
    if (nav.hasPeriod) {
      period.setPeriod(nav.startDate!, nav.endDate!);
    }

    final screen = await AiNavigator.build(nav);
    if (!mounted) return;
    if (screen == null) {
      setState(() => _messages.add(_error(
          'I could not open ${nav.label}. Try it from the menu.')));
      return;
    }
    Navigator.pop(context); // the chat panel
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _navigationCard(ChatNavigation nav) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2E9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kGreen),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.open_in_new, size: 15, color: _kGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(nav.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: _kGreen)),
                ),
              ],
            ),
            if (nav.hasPeriod)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_date(nav.startDate!)} to ${_date(nav.endDate!)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kGreen,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _busy ? null : () => _go(nav),
                child: Text('Open ${nav.label}'),
              ),
            ),
          ],
        ),
      );

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Accounts a draft is waiting on. Creating them re-runs the draft, so the
  /// user does not have to repeat what they asked for.
  Widget _pendingLedgersCard(ChatMessage message) {
    final pending = message.pendingLedgers!;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB26A00)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Needs a new account',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFFB26A00))),
          const SizedBox(height: 6),
          ...pending.map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• ${p.name}  (${p.group})',
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(height: 8),
          if (message.settled)
            const Text('Created',
                style: TextStyle(
                    fontSize: 12,
                    color: _kGreen,
                    fontWeight: FontWeight.bold))
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGreen,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed:
                        _busy ? null : () => _createPending(message),
                    child: Text(
                        'Create ${pending.length == 1 ? 'it' : 'them'}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => message.settled = true),
                    child: const Text('No thanks'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Create the accounts a draft was missing, then rebuild the draft.
  Future<void> _createPending(ChatMessage message) async {
    final pending = message.pendingLedgers;
    final draft = message.pendingVoucher;
    if (pending == null || draft == null || _busy) return;
    setState(() => _busy = true);
    try {
      await _service.createLedgers(pending);
      final voucher = await _service.rebuildDraft(draft);
      _service.invalidateBooks();
      if (!mounted) return;
      final made = pending.map((p) => p.name).join(', ');
      setState(() {
        message.settled = true;
        _messages.add(ChatMessage(
          role: ChatRole.assistant,
          text: 'Created $made. Here is the entry.',
          voucher: voucher,
        ));
      });
      await _service.remember(_messages.last);
    } on AiDraftException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_error(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_error('Could not create: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  /// A batch of invoices: how many there are, one voucher per page swiped
  /// left to right, and posting either one at a time or the lot.
  Widget _invoiceBatchCard(ChatMessage message) {
    final invoices = message.invoices!;
    final controller = _pagers.putIfAbsent(
      identityHashCode(message),
      () => PageController(),
    );
    final page = _pages[identityHashCode(message)] ?? 0;
    final outstanding = invoices.where((d) => d.isPostable).length;
    final posted = invoices.where((d) => d.posted).length;

    // Once everything is in the books the review has nothing left to say.
    if (posted == invoices.length) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2E9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kGreen),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 18, color: _kGreen),
            const SizedBox(width: 8),
            Text('Posted all $posted vouchers',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: _kGreen)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The count, matching the number of invoices uploaded.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: _kGreen,
              borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${invoices.length} voucher${invoices.length == 1 ? '' : 's'}'
                    '${posted > 0 ? ' · $posted posted' : ''}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
                Text('${page + 1} / ${invoices.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          SizedBox(
            height: 232,
            child: PageView.builder(
              controller: controller,
              itemCount: invoices.length,
              onPageChanged: (i) =>
                  setState(() => _pages[identityHashCode(message)] = i),
              itemBuilder: (_, i) => _invoicePage(invoices[i], i),
            ),
          ),
          // Swipe is the primary gesture; arrows make it discoverable.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                color: _kGreen,
                onPressed: page == 0
                    ? null
                    : () => controller.previousPage(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        ),
              ),
              Row(
                children: List.generate(
                  invoices.length,
                  (i) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == page
                          ? _kGreen
                          : (invoices[i].posted
                              ? _kGreen.withOpacity(0.35)
                              : Colors.grey.shade400),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                color: _kGreen,
                onPressed: page >= invoices.length - 1
                    ? null
                    : () => controller.nextPage(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _kGreen),
                onPressed: _busy || outstanding == 0
                    ? null
                    : () => _postAllInvoices(message),
                icon: const Icon(Icons.done_all, size: 18),
                label: Text(outstanding == 0
                    ? 'Nothing left to post'
                    : 'Post all $outstanding'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One invoice's voucher, or why there isn't one.
  Widget _invoicePage(InvoiceDraft draft, int index) {
    final voucher = draft.voucher;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (draft.error != null) ...[
              Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 16, color: Colors.red.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Invoice ${index + 1} could not be read',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(draft.error!, style: const TextStyle(fontSize: 12)),
            ] else if (draft.needsLedgers) ...[
              const Text('Needs a new account',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFFB26A00))),
              const SizedBox(height: 4),
              ...draft.pendingLedgers!.map((p) => Text('• ${p.name}  (${p.group})',
                  style: const TextStyle(fontSize: 12))),
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kGreen,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _busy ? null : () => _resolveInvoice(draft),
                child: const Text('Create and continue'),
              ),
            ] else if (voucher != null) ...[
              Row(
                children: [
                  Text(
                    '${voucher.type} • '
                    '${_date(voucher.date)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: _kGreen),
                  ),
                  const Spacer(),
                  if (draft.posted)
                    const Text('Posted',
                        style: TextStyle(
                            fontSize: 12,
                            color: _kGreen,
                            fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 12),
              ...voucher.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(e.ledgerName,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        e.debit > 0
                            ? '${e.debit.toStringAsFixed(2)} Dr'
                            : '${e.credit.toStringAsFixed(2)} Cr',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              if (voucher.narration.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(voucher.narration,
                    style: const TextStyle(
                        fontSize: 11, fontStyle: FontStyle.italic)),
              ],
              for (final warning in voucher.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(warning,
                      style: TextStyle(
                          fontSize: 11, color: Colors.amber.shade900)),
                ),
              const SizedBox(height: 8),
              if (!draft.posted)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kGreen,
                      side: const BorderSide(color: _kGreen),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _busy ? null : () => _postOneInvoice(draft),
                    child: Text('Post this one (${index + 1})'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _postOneInvoice(InvoiceDraft draft) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.postInvoice(draft);
    } on AiDraftException catch (e) {
      if (mounted) setState(() => _messages.add(_error(e.message)));
    } catch (e) {
      if (mounted) setState(() => _messages.add(_error('Could not post: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _postAllInvoices(ChatMessage message) async {
    final invoices = message.invoices!;
    if (_busy) return;
    setState(() => _busy = true);
    var done = 0;
    try {
      for (final draft in invoices) {
        if (!draft.isPostable) continue;
        await _service.postInvoice(draft);
        done++;
      }
      if (!mounted) return;
      final confirmation = ChatMessage(
        role: ChatRole.assistant,
        text: 'Posted $done voucher${done == 1 ? '' : 's'} to the books.',
      );
      setState(() => _messages.add(confirmation));
      await _service.remember(confirmation);
    } catch (e) {
      if (mounted) {
        setState(() => _messages
            .add(_error('Posted $done, then stopped: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  Future<void> _resolveInvoice(InvoiceDraft draft) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.resolveInvoice(draft);
    } on AiDraftException catch (e) {
      if (mounted) setState(() => _messages.add(_error(e.message)));
    } catch (e) {
      if (mounted) setState(() => _messages.add(_error('Could not create: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// What a draft in an earlier session turned into. Not actionable — the
  /// ledgers and images behind it may have changed since.
  Widget _historyNote(String note) => Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2E9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 13, color: Colors.grey.shade700),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                note,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      );

  Widget _voucherCard(ChatMessage message) {
    final draft = message.voucher!;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${draft.type} • ${draft.date.day.toString().padLeft(2, '0')}/'
            '${draft.date.month.toString().padLeft(2, '0')}/${draft.date.year}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: _kGreen),
          ),
          const Divider(height: 12),
          ...draft.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                      child: Text(e.ledgerName,
                          style: const TextStyle(fontSize: 13))),
                  Text(
                    e.debit > 0
                        ? '${e.debit.toStringAsFixed(2)} Dr'
                        : '${e.credit.toStringAsFixed(2)} Cr',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          if (draft.narration.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(draft.narration,
                style: const TextStyle(
                    fontSize: 12, fontStyle: FontStyle.italic)),
          ],
          for (final warning in draft.warnings)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Colors.amber.shade800),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(warning,
                        style: TextStyle(
                            fontSize: 11, color: Colors.amber.shade900)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          if (message.settled)
            const Text('Posted',
                style: TextStyle(
                    fontSize: 12,
                    color: _kGreen,
                    fontWeight: FontWeight.bold))
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGreen,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _busy ? null : () => _postVoucher(message),
                    child: const Text('Post'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => message.settled = true),
                    child: const Text('Discard'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _rowsCard(ChatMessage message) {
    final rows = message.bankRows!;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${rows.length} transactions read',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: _kGreen)),
          const SizedBox(height: 4),
          Text(
            '${rows.where((r) => r.ledgerId == null).length} still need a ledger.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          if (message.settled)
            const Text('Posted',
                style: TextStyle(
                    fontSize: 12,
                    color: _kGreen,
                    fontWeight: FontWeight.bold))
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _kGreen,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _busy ? null : () => _reviewRows(message),
                icon: const Icon(Icons.table_rows, size: 16),
                label: const Text('Review in table'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.only(
          left: 8,
          right: 8,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pending.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 4,
                    children: _pending
                        .map((p) => Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(Icons.image, size: 16),
                              label: Text(
                                p.split('/').last,
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                              onDeleted: () =>
                                  setState(() => _pending.remove(p)),
                            ))
                        .toList(),
                  ),
                ),
              ),
              // Say what the image is, rather than leaving the model to guess.
              // Sending without choosing still works and lets it decide.
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kGreen,
                        side: const BorderSide(color: _kGreen),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: _busy ? null : _importStatement,
                      icon: const Icon(Icons.table_rows, size: 15),
                      label: const Text('Statement',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kGreen,
                        side: const BorderSide(color: _kGreen),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      // One image is one bill; several are usually several
                      // bills, so the batch reader is the sensible default.
                      onPressed: _busy
                          ? null
                          : (_pending.length > 1
                              ? _readInvoices
                              : _draftFromBill),
                      icon: const Icon(Icons.receipt_long, size: 15),
                      label: Text(
                        _pending.length > 1
                            ? '${_pending.length} invoices'
                            : 'Bill / receipt',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              if (_pending.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Several images of one bill? Use Statement or just Send.',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate, color: _kGreen),
                  tooltip: 'Attach an image',
                  onPressed: _busy ? null : _attachMenu,
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Ask, or describe an entry…',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Becomes Stop while a request is running, so a long batch or
                // a slow read can always be abandoned.
                if (_busy)
                  IconButton(
                    icon: const Icon(Icons.stop_circle, color: Color(0xFFC62828)),
                    tooltip: 'Stop',
                    onPressed: _stop,
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.send, color: _kGreen),
                    onPressed: _send,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
