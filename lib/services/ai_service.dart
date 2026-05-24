import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:accounting_app/data/storage_service.dart';

/// Calls Gemini directly. Single-user app, so the key lives in app constants.
/// Rotate via: console.cloud.google.com → APIs → Credentials.
class AiService {
  static const String _apiKey = 'AIzaSyBFGffBLcrDeX7OjYwmkQ2O8MDGVvGn4GI';
  static const String _model = 'gemini-2.5-flash';
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Build accounting context for the AI from the current company's books.
  static Future<String> _buildContext() async {
    try {
      final company = await StorageService.getSelectedCompany();
      if (company == null) return '';
      final ledgers = await StorageService.getLedgers();

      final buf = StringBuffer();
      buf.writeln('Current company: ${company['name']}');
      buf.writeln('Books from: ${company['books_from'] ?? "?"}');
      buf.writeln('');
      buf.writeln('Ledgers and current balances:');

      for (final ledger in ledgers) {
        final id = ledger['id'] as int?;
        if (id == null) continue;
        final balance = await StorageService.getLedgerBalance(id);
        final name = ledger['name'];
        final group = ledger['classification'] ?? '';
        final type = balance >= 0 ? 'Dr' : 'Cr';
        buf.writeln(
            '- $name [$group]: ₹${balance.abs().toStringAsFixed(2)} $type');
      }
      return buf.toString();
    } catch (e) {
      return '';
    }
  }

  /// Send a chat message and get a response.
  /// [history] is a list of {role: 'user'|'assistant', content: String}
  static Future<String> chat({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    try {
      final context = await _buildContext();

      // Build Gemini-format contents
      final contents = <Map<String, dynamic>>[];

      // System prompt as the first user/model exchange
      contents.add({
        'role': 'user',
        'parts': [
          {
            'text': 'You are an accounting assistant inside a mobile accounting '
                'app. Answer concisely using the company data below. '
                'Use INR (₹) for amounts. If asked about balances or ledger '
                'data, use these figures:\n\n$context'
          }
        ]
      });
      contents.add({
        'role': 'model',
        'parts': [
          {'text': 'Understood. I will answer using this company data.'}
        ]
      });

      // Add history
      for (final h in history) {
        contents.add({
          'role': h['role'] == 'user' ? 'user' : 'model',
          'parts': [
            {'text': h['content'] ?? ''}
          ]
        });
      }

      // Current user message
      contents.add({
        'role': 'user',
        'parts': [
          {'text': message}
        ]
      });

      final response = await http
          .post(
            Uri.parse('$_endpoint/$_model:generateContent?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'contents': contents}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
            as String?;
        return text ?? 'No response received.';
      } else {
        return 'Error ${response.statusCode}: please try again in a moment.';
      }
    } catch (e) {
      return 'Error: could not reach the assistant. Check your internet connection.';
    }
  }
}
