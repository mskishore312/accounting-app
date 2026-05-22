// Receipts Service
// Handles image attachment, Drive sync, and local cache for voucher receipts.
// Phase 1 of the AI-accounting feature roadmap.
//
// Storage strategy:
//   1. User attaches image -> save to local app dir, insert Receipts row
//      with sync_status='pending'
//   2. Background sync uploads to Drive's appDataFolder scope, updates
//      drive_file_id + sync_status='synced'
//   3. On a new device, sign in with same Google account -> pull file list
//      from Drive -> reconcile against local Receipts table
//
// Drive integration uses appDataFolder (hidden from user's Drive UI),
// so receipts don't clutter the user's regular files.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../data/storage_service.dart';

class ReceiptsService {
  static final ImagePicker _picker = ImagePicker();

  /// Capture a photo from camera, compress, save locally, and record in DB.
  /// Returns the inserted receipt id, or null on failure/cancel.
  static Future<int?> captureFromCamera(int voucherId) async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return null;
    return _saveAttachment(voucherId, picked);
  }

  /// Pick an image from gallery, compress, save locally, and record in DB.
  static Future<int?> pickFromGallery(int voucherId) async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return null;
    return _saveAttachment(voucherId, picked);
  }

  static Future<int> _saveAttachment(int voucherId, XFile picked) async {
    // Read bytes (works on both mobile + web)
    final Uint8List originalBytes = await picked.readAsBytes();

    // Compress to reduce storage/upload size
    Uint8List finalBytes = originalBytes;
    if (!kIsWeb) {
      // flutter_image_compress works best on mobile
      try {
        finalBytes = await FlutterImageCompress.compressWithList(
          originalBytes,
          quality: 80,
          minWidth: 1280,
          minHeight: 1280,
        );
      } catch (_) {
        // Fall back to original
      }
    }

    // Save to app documents dir (mobile) / use bytes directly (web)
    String? localPath;
    if (!kIsWeb) {
      final Directory dir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory(p.join(dir.path, 'receipts'));
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }
      final fileName = 'receipt_${voucherId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final f = File(p.join(receiptsDir.path, fileName));
      await f.writeAsBytes(finalBytes);
      localPath = f.path;
    }

    final receipt = {
      'voucher_id': voucherId,
      'local_path': localPath,
      'file_name': picked.name,
      'mime_type': 'image/jpeg',
      'file_size': finalBytes.length,
      'ocr_status': 'pending',
      'sync_status': 'pending',
    };
    return await StorageService.insertReceipt(receipt);
  }

  /// List receipts for a voucher
  static Future<List<Map<String, dynamic>>> getForVoucher(int voucherId) {
    return StorageService.getReceiptsByVoucher(voucherId);
  }

  /// Delete a receipt (DB row + local file). Drive cleanup happens during sync.
  static Future<void> delete(int receiptId, String? localPath) async {
    if (localPath != null && !kIsWeb) {
      try { await File(localPath).delete(); } catch (_) {}
    }
    await StorageService.deleteReceipt(receiptId);
  }
}
