import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:accounting_app/data/storage_service.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({Key? key}) : super(key: key);
  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  final _urlCtrl    = TextEditingController();
  final _secretCtrl = TextEditingController();
  bool _saved       = false;
  bool _testing     = false;
  String _testMsg   = '';
  bool _testOk      = false;
  bool _hideSecret  = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url    = await StorageService.getSetting(0, 'ai_backend_url');
    final secret = await StorageService.getSetting(0, 'ai_app_secret');
    if (mounted) {
      if (url    != null) _urlCtrl.text    = url;
      if (secret != null) _secretCtrl.text = secret;
      if (url != null) setState(() => _saved = true);
    }
  }

  Future<void> _save() async {
    final url    = _urlCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
    final secret = _secretCtrl.text.trim();
    if (url.isEmpty) return;
    await StorageService.setSetting(0, 'ai_backend_url', url);
    await StorageService.setSetting(0, 'ai_app_secret', secret);
    if (mounted) {
      setState(() { _saved = true; _testMsg = ''; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  Future<void> _test() async {
    final url = _urlCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
    if (url.isEmpty) return;
    setState(() { _testing = true; _testMsg = ''; });
    try {
      final res = await http
          .get(Uri.parse('$url/health'))
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final ok = res.statusCode == 200;
      setState(() {
        _testing = false;
        _testOk  = ok;
        _testMsg = ok
            ? '✓ Connected — backend is running'
            : '✗ ${res.statusCode}: ${res.body.substring(0, res.body.length.clamp(0, 60))}';
      });
    } catch (e) {
      if (mounted) {
        setState(() { _testing = false; _testOk = false; _testMsg = '✗ $e'; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C5545),
        title: const Text('AI Settings', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Backend URL ──
            const Text('Backend URL',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'URL of your Cloudflare Worker. '
              'The Gemini API key lives there — never in the app.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                filled: true, fillColor: Colors.white,
                hintText: 'https://tompa-ai.<account>.workers.dev',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 20),

            // ── App Secret ──
            const Text('App Secret',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'The same value you set with: wrangler secret put APP_SECRET',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _secretCtrl,
              obscureText: _hideSecret,
              decoration: InputDecoration(
                filled: true, fillColor: Colors.white,
                hintText: 'your-app-secret',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: IconButton(
                  icon: Icon(_hideSecret ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _hideSecret = !_hideSecret),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Buttons ──
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C5545),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _test,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _testing
                      ? const SizedBox(height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Test connection'),
                ),
              ),
            ]),

            if (_testMsg.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testOk ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_testMsg,
                    style: TextStyle(
                      color: _testOk ? Colors.green.shade800 : Colors.red.shade800)),
              ),
            ],

            if (_saved && _testOk) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(child: Text('AI features ready — OCR, Chat, and Voice.')),
                ]),
              ),
            ],

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text('First time setup (3 commands)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _step('1', 'npm install wrangler -g'),
            _step('2', 'wrangler secret put GEMINI_API_KEY   ← paste your key'),
            _step('3', 'wrangler secret put APP_SECRET       ← any password'),
            _step('', 'wrangler deploy   → gives you the URL above'),
            const SizedBox(height: 8),
            const Text(
              'Free tier: 100,000 requests/day. An SME doing 200 AI queries/day '
              'uses 0.2% of the limit.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (num.isNotEmpty)
            Container(
              width: 24, height: 24,
              margin: const EdgeInsets.only(right: 10, top: 1),
              decoration: const BoxDecoration(
                color: Color(0xFF2C5545),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(num,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            )
          else
            const SizedBox(width: 34),
          Expanded(child: Text(text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
        ],
      ),
    );
  }
}
