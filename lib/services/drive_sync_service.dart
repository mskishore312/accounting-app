// Drive Sync Service
// Handles Google Drive auth + upload/download of receipt images.
//
// Storage scope: drive.appdata (hidden appDataFolder, invisible in user's
// Drive UI). Receipts are scoped to the user's Google account, so signing
// into the same account on a new device pulls back all attachments.
//
// State machine for a Receipt row:
//   sync_status='pending'  -> local file saved, not yet uploaded
//   sync_status='uploading'-> upload in progress
//   sync_status='synced'   -> drive_file_id populated, uploaded_at set
//   sync_status='failed'   -> upload failed, retry next time

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import '../data/storage_service.dart';

class DriveSyncService {
  // drive.appdata = read/write the hidden appDataFolder only.
  // We do NOT request full Drive scope — receipts stay invisible in the
  // user's Drive UI and we can't read their other files.
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  static GoogleSignInAccount? _currentUser;
  static drive.DriveApi? _driveApi;

  /// Sign in and initialize the Drive API client. Returns true on success.
  static Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      if (_currentUser == null) return false;
      await _initDriveApi();
      return true;
    } catch (e) {
      debugPrint('[DriveSync] signIn failed: $e');
      return false;
    }
  }

  /// Silently restore an existing session (for app startup).
  static Future<bool> signInSilently() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
      if (_currentUser == null) return false;
      await _initDriveApi();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _driveApi = null;
  }

  static bool get isSignedIn => _currentUser != null && _driveApi != null;
  static String? get userEmail => _currentUser?.email;

  static Future<void> _initDriveApi() async {
    if (_currentUser == null) return;
    final authHeaders = await _currentUser!.authHeaders;
    final authenticatedClient = _AuthClient(authHeaders, http.Client());
    _driveApi = drive.DriveApi(authenticatedClient);
  }

  /// Upload all receipts pending sync to Drive (call after sign-in or
  /// periodically). Updates DB rows with drive_file_id on success.
  static Future<int> syncPendingUploads() async {
    if (!isSignedIn) return 0;
    final pending = await StorageService.getReceiptsPendingSync();
    int successCount = 0;
    for (final r in pending) {
      try {
        await _uploadOne(r);
        successCount++;
      } catch (e) {
        debugPrint('[DriveSync] upload ${r['id']} failed: $e');
        await StorageService.updateReceipt(r['id'] as int, {
          'sync_status': 'failed',
        });
      }
    }
    return successCount;
  }

  static Future<void> _uploadOne(Map<String, dynamic> receipt) async {
    final localPath = receipt['local_path'] as String?;
    if (localPath == null || kIsWeb) {
      // Web: bytes not stored on disk; skip in MVP
      return;
    }
    final file = File(localPath);
    if (!await file.exists()) {
      await StorageService.updateReceipt(receipt['id'] as int, {
        'sync_status': 'failed',
      });
      return;
    }
    await StorageService.updateReceipt(receipt['id'] as int, {
      'sync_status': 'uploading',
    });

    final fileName = receipt['file_name'] as String? ?? 'receipt_${receipt['id']}.jpg';
    final mimeType = receipt['mime_type'] as String? ?? 'image/jpeg';

    final driveFile = drive.File()
      ..name = fileName
      ..parents = ['appDataFolder']
      // appProperties is a hidden key-value store on the Drive file -
      // use it to encode our voucher_id so we can reconcile after re-install
      ..appProperties = {
        'voucher_id': receipt['voucher_id'].toString(),
        'receipt_id': receipt['id'].toString(),
      };

    final bytes = await file.readAsBytes();
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: mimeType,
    );

    final uploaded = await _driveApi!.files.create(driveFile, uploadMedia: media);

    await StorageService.updateReceipt(receipt['id'] as int, {
      'drive_file_id': uploaded.id,
      'sync_status': 'synced',
      'uploaded_at': DateTime.now().toIso8601String(),
    });
  }

  /// Reconcile Drive appDataFolder with local DB after fresh install / new
  /// device. Lists all receipts in appDataFolder; if any have a local
  /// receipt_id not present in local DB, we'd want to download them.
  /// For now: just returns the list so the UI can show a "pull" badge.
  static Future<List<drive.File>> listRemoteReceipts() async {
    if (!isSignedIn) return [];
    final res = await _driveApi!.files.list(
      spaces: 'appDataFolder',
      $fields: 'files(id, name, appProperties, modifiedTime, size)',
      pageSize: 1000,
    );
    return res.files ?? [];
  }
}

/// Wraps an http.Client to inject Google auth headers on every request.
class _AuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner;
  _AuthClient(this._headers, this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
