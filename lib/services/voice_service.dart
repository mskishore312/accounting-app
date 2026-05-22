// Voice Service - cheapest viable stack:
//   STT: device-native Android (speech_to_text package) - FREE
//   Brain: Gemini 2.5 Flash-Lite via GeminiChatService - ~₹0.01 per turn
//   TTS: device-native Android (flutter_tts) - FREE
//
// Versus OpenAI Realtime which is $0.18-$0.46 per minute.
// For an Indian SME doing ~20 voice queries/day = ~₹0.20/day vs ~$2-5/day for Realtime.

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static final FlutterTts _tts = FlutterTts();
  static bool _ready = false;

  static Future<bool> ensureReady() async {
    if (_ready) return true;
    if (kIsWeb) return false; // Use webkit speech on web later
    final available = await _speech.initialize(
      onError: (e) => debugPrint('[Voice] STT error: $e'),
    );
    if (available) {
      await _tts.setLanguage('en-IN');
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(true);
      _ready = true;
    }
    return _ready;
  }

  /// Start listening. onResult is called with transcribed text.
  /// Caller passes onPartial for live mid-utterance updates.
  static Future<void> startListening({
    required Function(String) onResult,
    Function(String)? onPartial,
  }) async {
    if (!_ready) await ensureReady();
    await _speech.listen(
      onResult: (r) {
        if (r.finalResult) {
          onResult(r.recognizedWords);
        } else if (onPartial != null) {
          onPartial(r.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      localeId: 'en-IN',
      cancelOnError: true,
      partialResults: true,
    );
  }

  static Future<void> stopListening() async {
    await _speech.stop();
  }

  static bool get isListening => _speech.isListening;

  /// Speak text aloud.
  static Future<void> speak(String text) async {
    if (!_ready) await ensureReady();
    await _tts.speak(text);
  }

  static Future<void> stopSpeaking() async {
    await _tts.stop();
  }
}
