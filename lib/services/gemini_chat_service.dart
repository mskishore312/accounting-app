// Gemini Chat Service
// Calls the TOM-PA AI backend (a Cloudflare Worker).
// The Worker holds the Gemini API key — the app only knows the backend URL
// and a shared app secret. Both are stored in CompanySettings (local SQLite).

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/storage_service.dart';
import '../services/financial_statement_service.dart';

class ChatMessage {
  final String role; // 'user' or 'model'
  final String text;
  final DateTime timestamp;
  ChatMessage({required this.role, required this.text, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

class GeminiChatService {
  static Future<Map<String, String?>> _config() async {
    final url = await StorageService.getSetting(0, 'ai_backend_url');
    final secret = await StorageService.getSetting(0, 'ai_app_secret');
    return {'url': url, 'secret': secret};
  }

  static Future<String> _buildContext() async {
    final company = await StorageService.getSelectedCompany();
    if (company == null) return 'No company selected.';
    final ledgers = await StorageService.getLedgers();
    final lines = [
      'Company: ${company['name']}',
      'Books from: ${company['books_from'] ?? "?"}',
      '\nLedgers:',
    ];
    for (final l in ledgers) {
      try {
        final bal = await FinancialStatementService.calculateLedgerBalance(
          ledgerId: l['id'] as int,
          ledger: l,
          startDate: null,
          endDate: null,
          booksBeginningDate: company['books_from'] as String?,
        );
        lines.add('  ${l['name']} (${l['classification'] ?? "?"}): '
            '${bal.toStringAsFixed(2)} ${bal >= 0 ? "Dr" : "Cr"}');
      } catch (_) {}
    }
    return lines.join('\n');
  }

  /// Send a message. Returns the assistant's reply text, or an error string.
  static Future<String> send({
    required List<ChatMessage> history,
    required String userMessage,
  }) async {
    final cfg = await _config();
    final backendUrl = cfg['url'];
    final secret = cfg['secret'] ?? '';

    if (backendUrl == null || backendUrl.isEmpty) {
      return 'Backend not configured. Go to Utility → AI Settings and enter the backend URL.';
    }

    final context = await _buildContext();
    final historyJson = history
        .map((m) => {'role': m.role, 'text': m.text})
        .toList();

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $secret',
        },
        body: jsonEncode({
          'message': userMessage,
          'history': historyJson,
          'context': context,
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 401) return 'Auth error — check App Secret in AI Settings.';
      if (res.statusCode != 200) return 'Backend error ${res.statusCode}.';

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['reply'] as String? ?? 'No reply.';
    } catch (e) {
      debugPrint('[Chat] error: $e');
      return 'Network error: $e';
    }
  }
}
