import 'package:flutter/material.dart';
import 'package:accounting_app/services/gemini_chat_service.dart';
import 'package:accounting_app/services/voice_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _history = [];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  bool _listening = false;
  String _partialText = '';

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _history.add(ChatMessage(role: 'user', text: text));
      _sending = true;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    final reply = await GeminiChatService.send(
      history: _history.sublist(0, _history.length - 1),
      userMessage: text,
    );
    if (!mounted) return;
    setState(() {
      _history.add(ChatMessage(role: 'model', text: reply));
      _sending = false;
    });
    _scrollToBottom();
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await VoiceService.stopListening();
      setState(() => _listening = false);
      return;
    }
    final ok = await VoiceService.ensureReady();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission needed.')),
      );
      return;
    }
    setState(() { _listening = true; _partialText = ''; });
    await VoiceService.startListening(
      onPartial: (t) => setState(() => _partialText = t),
      onResult: (text) async {
        setState(() { _listening = false; _partialText = ''; });
        if (text.trim().isEmpty) return;
        _inputCtrl.text = text;
        await _send();
        if (_history.isNotEmpty && _history.last.role == 'model') {
          VoiceService.speak(_history.last.text);
        }
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C5545),
        title: const Text('Assistant', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: _history.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'Ask me about your ledgers, balances, GST, or how to record a transaction.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: _history.length,
                    itemBuilder: (_, i) => _bubble(_history[i]),
                  ),
          ),
          if (_listening && _partialText.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFFF3E0),
              child: Text('🎙️ $_partialText', style: const TextStyle(color: Color(0xFF856404))),
            ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Ask something…',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _listening ? Icons.mic : Icons.mic_none,
                      color: _listening ? Colors.red : const Color(0xFF2C5545),
                    ),
                    onPressed: _toggleVoice,
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF2C5545)),
                    onPressed: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF2C5545) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(m.text, style: TextStyle(color: isUser ? Colors.white : Colors.black87)),
      ),
    );
  }
}
