import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/gemini_service.dart';

/// Where the user supplies their own Gemini API key.
class AiSettings extends StatefulWidget {
  const AiSettings({Key? key}) : super(key: key);

  @override
  State<AiSettings> createState() => _AiSettingsState();
}

class _AiSettingsState extends State<AiSettings> {
  final _keyController = TextEditingController();
  String _model = GeminiService.defaultModel;
  bool _obscure = true;
  bool _loading = true;
  bool _testing = false;
  String? _status;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final key = await GeminiService.getApiKey();
    final model = await GeminiService.getModel();
    if (!mounted) return;
    setState(() {
      _keyController.text = key ?? '';
      _model = model;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await GeminiService.setApiKey(_keyController.text);
    await GeminiService.setModel(_model);
    if (!mounted) return;
    setState(() {
      _status = 'Saved on this device.';
      _statusIsError = false;
    });
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _status = null;
    });
    await GeminiService.setApiKey(_keyController.text);
    await GeminiService.setModel(_model);
    final service = GeminiService();
    try {
      await service.testConnection();
      if (!mounted) return;
      setState(() {
        _status = 'Connected — $_model is responding.';
        _statusIsError = false;
      });
    } on GeminiException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = e.message;
        _statusIsError = true;
      });
    } finally {
      service.dispose();
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _clear() async {
    await StorageService.deleteSetting(GeminiService.apiKeySetting);
    if (!mounted) return;
    setState(() {
      _keyController.clear();
      _status = 'Key removed from this device.';
      _statusIsError = false;
    });
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
          'AI Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Gemini API key',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C5545),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The AI features use Google Gemini with your own key. '
                    'It is stored only on this device and is sent solely to '
                    'Google when you use an AI feature.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF4C7380)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyController,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'API key',
                      hintText: 'AIza...',
                      filled: true,
                      fillColor: Colors.white,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Get a free key from Google AI Studio'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2C5545),
                      ),
                      onPressed: () async {
                        final uri =
                            Uri.parse('https://aistudio.google.com/apikey');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _model,
                    decoration: const InputDecoration(
                      labelText: 'Model',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    items: GeminiService.availableModels
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _model = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2C5545),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _testing ? null : _save,
                          child: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2C5545),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _testing ? null : _test,
                          child: _testing
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Text('Test connection'),
                        ),
                      ),
                    ],
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _statusIsError
                            ? Colors.red.shade50
                            : const Color(0xFFD5EADF),
                        border: Border.all(
                          color: _statusIsError
                              ? Colors.red.shade300
                              : const Color(0xFF2C5545),
                        ),
                      ),
                      child: Text(
                        _status!,
                        style: TextStyle(
                          color: _statusIsError
                              ? Colors.red.shade900
                              : const Color(0xFF2C5545),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Remove key from this device',
                        style: TextStyle(color: Colors.red)),
                    onPressed: _clear,
                  ),
                ],
              ),
            ),
    );
  }
}
