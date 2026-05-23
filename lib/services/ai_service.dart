import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  // Hardcoded — users should never configure this
  static const String _backendUrl = 'https://tompa-ai.mskishore312.workers.dev';
  static const String _appSecret  = 'f82764090532158ff906b3eb177de22a';

  /// Send a chat message and get a response.
  /// [history] is a list of {role: 'user'|'assistant', content: String}
  static Future<String> chat({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/chat'),
        headers: {
          'Content-Type': 'application/json',
          'X-App-Secret': _appSecret,
        },
        body: jsonEncode({
          'message': message,
          'history': history,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] as String? ?? 'No response received.';
      } else {
        return 'Error: Server returned ${response.statusCode}. Please try again.';
      }
    } catch (e) {
      return 'Error: Could not connect to assistant. Please check your internet connection.';
    }
  }
}
