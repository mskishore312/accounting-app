import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:accounting_app/data/storage_service.dart';

/// Raised when the Gemini API cannot be used. [isConfigError] marks the
/// cases the user can fix themselves (missing or invalid key).
class GeminiException implements Exception {
  final String message;
  final bool isConfigError;

  const GeminiException(this.message, {this.isConfigError = false});

  @override
  String toString() => message;
}

/// One earlier turn of a conversation, replayed to give the model context.
class GeminiTurn {
  final bool fromUser;
  final String text;
  final List<String> images;

  const GeminiTurn({
    required this.fromUser,
    required this.text,
    this.images = const [],
  });
}

/// Minimal client for the Gemini generative language REST API.
///
/// The key is supplied by the user and kept in local app settings; it is
/// never bundled with the app or committed to the repository.
class GeminiService {
  static const String apiKeySetting = 'gemini_api_key';
  static const String modelSetting = 'gemini_model';
  static const String defaultModel = 'gemini-3.6-flash';
  static const String _host = 'generativelanguage.googleapis.com';

  /// Generally available models offered in settings, newest first.
  ///
  /// Preview models are deliberately excluded: they can be withdrawn at short
  /// notice, and this app has already been broken once by a model that went
  /// away underneath it.
  static const List<String> availableModels = [
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
  ];

  /// Models Google has shut down or scheduled for shutdown.
  ///
  /// The 2.0 family was retired on 1 June 2026 and the 2.5 family retires on
  /// 16 October 2026. A device still holding one of these in its settings
  /// would fail every request, so [getModel] migrates it to [defaultModel].
  static const Set<String> retiredModels = {
    'gemini-2.0-flash',
    'gemini-2.0-flash-001',
    'gemini-2.0-flash-lite',
    'gemini-2.0-flash-lite-001',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.5-pro',
  };

  final http.Client _client;

  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  static Future<String?> getApiKey() => StorageService.getSetting(apiKeySetting);

  static Future<void> setApiKey(String key) =>
      StorageService.setSetting(apiKeySetting, key.trim());

  /// The model to use, upgrading away from any retired one.
  ///
  /// The migration is written back, so a device that was pinned to a dead
  /// model recovers on its own and Settings shows the model actually in use.
  static Future<String> getModel() async {
    final stored = (await StorageService.getSetting(modelSetting))?.trim();
    if (stored == null || stored.isEmpty) return defaultModel;
    if (retiredModels.contains(stored)) {
      await StorageService.setSetting(modelSetting, defaultModel);
      return defaultModel;
    }
    return stored;
  }

  static Future<void> setModel(String model) =>
      StorageService.setSetting(modelSetting, model);

  static Future<bool> isConfigured() async {
    final key = await getApiKey();
    return key != null && key.trim().isNotEmpty;
  }

  /// Raw text generation. [images] are local file paths sent inline.
  /// When [jsonSchema] is given the model is asked for JSON matching it.
  /// [history] replays earlier turns so the model can follow a conversation.
  Future<String> generate({
    required String prompt,
    String? systemInstruction,
    List<String> images = const [],
    List<GeminiTurn> history = const [],
    Map<String, dynamic>? jsonSchema,
    double temperature = 0.2,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final key = await getApiKey();
    if (key == null || key.trim().isEmpty) {
      throw const GeminiException(
        'No Gemini API key set. Add one under Utility → AI Settings.',
        isConfigError: true,
      );
    }
    final model = await getModel();

    final contents = <Map<String, dynamic>>[];
    for (final turn in history) {
      contents.add({
        'role': turn.fromUser ? 'user' : 'model',
        'parts': await _buildParts(turn.text, turn.images),
      });
    }
    contents.add({
      'role': 'user',
      'parts': await _buildParts(prompt, images),
    });

    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': temperature,
        if (jsonSchema != null) 'responseMimeType': 'application/json',
        if (jsonSchema != null) 'responseSchema': jsonSchema,
      },
      if (systemInstruction != null)
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction}
          ]
        },
    };

    final uri = Uri.https(_host, '/v1beta/models/$model:generateContent',
        {'key': key.trim()});

    http.Response response;
    try {
      response = await _client
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body))
          .timeout(timeout);
    } on SocketException {
      throw const GeminiException(
          'Could not reach Gemini. Check your internet connection.');
    } catch (e) {
      throw GeminiException('Gemini request failed: $e');
    }

    if (response.statusCode != 200) {
      throw GeminiException(_describeError(response), isConfigError: _isKeyProblem(response));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      final feedback = decoded['promptFeedback'];
      throw GeminiException(
          'Gemini returned no answer${feedback == null ? '' : ' ($feedback)'}.');
    }
    final content = candidates.first['content'] as Map<String, dynamic>?;
    final responseParts = content?['parts'] as List<dynamic>?;
    final text = responseParts
        ?.map((p) => (p as Map<String, dynamic>)['text'] as String? ?? '')
        .join()
        .trim();
    if (text == null || text.isEmpty) {
      throw const GeminiException('Gemini returned an empty answer.');
    }
    return text;
  }

  /// Generation that must come back as a JSON object.
  Future<Map<String, dynamic>> generateJson({
    required String prompt,
    String? systemInstruction,
    List<String> images = const [],
    List<GeminiTurn> history = const [],
    required Map<String, dynamic> schema,
    double temperature = 0.1,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final raw = await generate(
      prompt: prompt,
      systemInstruction: systemInstruction,
      images: images,
      history: history,
      jsonSchema: schema,
      temperature: temperature,
      timeout: timeout,
    );
    try {
      final cleaned = _stripCodeFence(raw);
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const FormatException('not a JSON object');
    } on FormatException {
      throw GeminiException('Gemini returned an unexpected answer: $raw');
    }
  }

  /// Verifies the stored key with a cheap round-trip.
  Future<void> testConnection() async {
    final reply = await generate(
      prompt: 'Reply with the single word: OK',
      temperature: 0,
      timeout: const Duration(seconds: 20),
    );
    if (!reply.toUpperCase().contains('OK')) {
      throw GeminiException('Unexpected reply from Gemini: $reply');
    }
  }

  void dispose() => _client.close();

  // --- helpers ---

  /// Text plus any readable images, as Gemini content parts. Images that no
  /// longer exist on disk are skipped rather than failing the whole request.
  static Future<List<Map<String, dynamic>>> _buildParts(
    String text,
    List<String> images,
  ) async {
    final parts = <Map<String, dynamic>>[
      {'text': text},
    ];
    for (final path in images) {
      final file = File(path);
      if (!await file.exists()) continue;
      parts.add({
        'inline_data': {
          'mime_type': _mimeTypeFor(path),
          'data': base64Encode(await file.readAsBytes()),
        }
      });
    }
    return parts;
  }

  static String _stripCodeFence(String text) {
    var t = text.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
      if (t.endsWith('```')) t = t.substring(0, t.length - 3);
    }
    return t.trim();
  }

  static String _mimeTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  static bool _isKeyProblem(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) return true;
    if (response.statusCode != 400) return false;
    final body = response.body.toLowerCase();
    // Google reports this either as a reason code or in the message text.
    return body.contains('api_key_invalid') ||
        body.contains('api key not valid') ||
        body.contains('api key expired');
  }

  static String _describeError(http.Response response) {
    String detail = response.body;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      detail = (decoded['error']?['message'] as String?) ?? detail;
    } catch (_) {}
    switch (response.statusCode) {
      case 400:
        if (detail.contains('API key not valid')) {
          return 'That Gemini API key is not valid. Check it in AI Settings.';
        }
        return 'Gemini rejected the request: $detail';
      case 403:
        return 'Gemini denied access. The key may lack permission: $detail';
      case 404:
        // Almost always a model that has been retired, which reads as a
        // baffling "not found" unless the message says so.
        return 'Gemini has no model by that name — it may have been retired. '
            'Pick a different model in AI Settings. ($detail)';
      case 429:
        return 'Gemini rate limit reached. Try again in a moment.';
      case 503:
        return 'Gemini is temporarily unavailable. Try again shortly.';
      default:
        return 'Gemini error ${response.statusCode}: $detail';
    }
  }
}
