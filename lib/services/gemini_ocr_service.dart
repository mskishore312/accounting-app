// Gemini OCR Service
// Sends receipt images to the TOM-PA AI backend (/ocr endpoint).
// The Gemini API key is on the backend — not in the app.

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../data/storage_service.dart';

class GeminiOcrService {
  static Future<Map<String, String?>> _config() async {
    final url    = await StorageService.getSetting(0, 'ai_backend_url');
    final secret = await StorageService.getSetting(0, 'ai_app_secret');
    return {'url': url, 'secret': secret};
  }

  /// Run OCR on the given local file. Returns extracted map or null.
  /// Updates the Receipts row with ocr_status + ocr_extracted_json.
  static Future<Map<String, dynamic>?> extractFromImage({
    required int receiptId,
    required String localPath,
  }) async {
    final cfg = await _config();
    final backendUrl = cfg['url'];
    final secret     = cfg['secret'] ?? '';

    if (backendUrl == null || backendUrl.isEmpty) {
      await StorageService.updateReceipt(receiptId, {'ocr_status': 'no_backend'});
      return null;
    }
    if (kIsWeb) {
      await StorageService.updateReceipt(receiptId, {'ocr_status': 'web_unsupported'});
      return null;
    }

    final file = File(localPath);
    if (!await file.exists()) {
      await StorageService.updateReceipt(receiptId, {'ocr_status': 'file_missing'});
      return null;
    }

    await StorageService.updateReceipt(receiptId, {'ocr_status': 'processing'});

    final bytes       = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/ocr'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $secret',
        },
        body: jsonEncode({
          'image_base64': base64Image,
          'mime_type': 'image/jpeg',
        }),
      ).timeout(const Duration(seconds: 60)); // OCR can take time on large images

      if (res.statusCode == 401) {
        await StorageService.updateReceipt(receiptId, {'ocr_status': 'auth_failed'});
        return null;
      }
      if (res.statusCode != 200) {
        await StorageService.updateReceipt(receiptId, {'ocr_status': 'failed'});
        return null;
      }

      final data      = jsonDecode(res.body) as Map<String, dynamic>;
      final extracted = data['extracted'] as Map<String, dynamic>?;

      await StorageService.updateReceipt(receiptId, {
        'ocr_status': extracted != null ? 'completed' : 'no_result',
        'ocr_extracted_json': extracted != null ? jsonEncode(extracted) : null,
      });
      return extracted;
    } catch (e) {
      debugPrint('[OCR] error: $e');
      await StorageService.updateReceipt(receiptId, {'ocr_status': 'failed'});
      return null;
    }
  }
}
