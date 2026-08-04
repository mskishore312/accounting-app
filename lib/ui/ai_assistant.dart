import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:accounting_app/services/ai_accounting_service.dart';
import 'package:accounting_app/services/gemini_service.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:accounting_app/ui/ai_settings.dart';

/// AI assistant: describe a transaction in plain language or photograph a
/// bill to get a voucher draft, or ask a question about the books.
///
/// Drafts are always reviewed by the user before anything is posted.
class AiAssistant extends StatefulWidget {
  const AiAssistant({Key? key}) : super(key: key);

  @override
  State<AiAssistant> createState() => _AiAssistantState();
}

class _AiAssistantState extends State<AiAssistant> {
  final _input = TextEditingController();
  final _service = AiAccountingService();
  final _picker = ImagePicker();

  bool _busy = false;
  bool _configured = false;
  String? _error;
  String? _answer;
  ProposedVoucher? _draft;

  @override
  void initState() {
    super.initState();
    _checkConfig();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _checkConfig() async {
    final ok = await GeminiService.isConfigured();
    if (mounted) setState(() => _configured = ok);
  }

  void _reset() {
    setState(() {
      _error = null;
      _answer = null;
      _draft = null;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    _reset();
    setState(() => _busy = true);
    try {
      await action();
    } on AiDraftException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on GeminiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _draftFromText() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    await _run(() async {
      final draft = await _service.draftVoucherFromText(text);
      if (mounted) setState(() => _draft = draft);
    });
  }

  Future<void> _askQuestion() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final period = Provider.of<PeriodService>(context, listen: false);
    await _run(() async {
      final answer = await _service.answerQuestion(
        text,
        startDate: period.startDate,
        endDate: period.endDate,
      );
      if (mounted) setState(() => _answer = answer);
    });
  }

  Future<void> _draftFromPhoto(ImageSource source) async {
    final picked =
        await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1920);
    if (picked == null) return;
    await _run(() async {
      final draft = await _service.draftVoucherFromImage(
        picked.path,
        hint: _input.text.trim(),
      );
      if (mounted) setState(() => _draft = draft);
    });
  }

  Future<void> _post() async {
    final draft = _draft;
    if (draft == null) return;
    await _run(() async {
      await _service.postVoucher(draft);
      if (!mounted) return;
      setState(() {
        _draft = null;
        _input.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voucher posted'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF2C5545)),
              title: const Text('Photograph a bill'),
              onTap: () {
                Navigator.pop(context);
                _draftFromPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF2C5545)),
              title: const Text('Choose a bill image'),
              onTap: () {
                Navigator.pop(context);
                _draftFromPhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C5545),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'AI Assistant',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'AI Settings',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiSettings()),
              );
              _checkConfig();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_configured) _configBanner(),
            TextField(
              controller: _input,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                hintText:
                    'e.g. "paid 4500 shop rent by cash" or "what is my GST liability?"',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C5545),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _busy ? null : _draftFromText,
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('Draft voucher'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2C5545),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _busy ? null : _askQuestion,
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: const Text('Ask'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2C5545),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _busy ? null : _showPhotoOptions,
              icon: const Icon(Icons.photo_camera, size: 18),
              label: const Text('Draft from a bill photo'),
            ),
            const SizedBox(height: 16),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_error != null) _errorBox(_error!),
            if (_answer != null) _answerBox(_answer!),
            if (_draft != null) _draftCard(_draft!),
          ],
        ),
      ),
    );
  }

  Widget _configBanner() => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          border: Border.all(color: Colors.amber.shade700),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'No Gemini API key yet. Add one to use the AI features.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiSettings()),
                );
                _checkConfig();
              },
              child: const Text('Add key'),
            ),
          ],
        ),
      );

  Widget _errorBox(String message) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Text(message, style: TextStyle(color: Colors.red.shade900)),
      );

  Widget _answerBox(String answer) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF2C5545)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Answer',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF2C5545))),
            const SizedBox(height: 6),
            SelectableText(answer),
            const SizedBox(height: 8),
            Text(
              'Based on the current period\'s figures. Check before relying on it.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      );

  Widget _draftCard(ProposedVoucher draft) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF2C5545)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proposed ${draft.type} voucher',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF2C5545)),
          ),
          const SizedBox(height: 4),
          Text(
            '${draft.date.day.toString().padLeft(2, '0')}/'
            '${draft.date.month.toString().padLeft(2, '0')}/${draft.date.year}',
            style: const TextStyle(color: Color(0xFF4C7380)),
          ),
          const Divider(),
          ...draft.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text(e.ledgerName)),
                  Text(
                    e.debit > 0
                        ? '${e.debit.toStringAsFixed(2)} Dr'
                        : '${e.credit.toStringAsFixed(2)} Cr',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          if (draft.narration.isNotEmpty)
            Text(draft.narration,
                style: const TextStyle(fontStyle: FontStyle.italic)),
          for (final warning in draft.warnings)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.amber.shade800),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(warning,
                        style: TextStyle(
                            fontSize: 12, color: Colors.amber.shade900)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C5545),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _busy ? null : _post,
                  child: const Text('Post voucher'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _reset,
                  child: const Text('Discard'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
