import 'package:flutter/material.dart';
import 'package:accounting_app/services/drive_sync_service.dart';

class DriveSyncScreen extends StatefulWidget {
  const DriveSyncScreen({Key? key}) : super(key: key);
  @override
  State<DriveSyncScreen> createState() => _DriveSyncScreenState();
}

class _DriveSyncScreenState extends State<DriveSyncScreen> {
  bool _busy = false;
  String _status = '';
  int _remoteCount = 0;

  @override
  void initState() {
    super.initState();
    _trySilentSignIn();
  }

  Future<void> _trySilentSignIn() async {
    setState(() => _busy = true);
    await DriveSyncService.signInSilently();
    if (mounted) {
      setState(() => _busy = false);
      if (DriveSyncService.isSignedIn) {
        _refreshRemoteCount();
      }
    }
  }

  Future<void> _signIn() async {
    setState(() { _busy = true; _status = 'Signing in…'; });
    final ok = await DriveSyncService.signIn();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = ok ? 'Signed in as ${DriveSyncService.userEmail}' : 'Sign-in failed';
    });
    if (ok) _refreshRemoteCount();
  }

  Future<void> _signOut() async {
    await DriveSyncService.signOut();
    if (mounted) setState(() { _status = 'Signed out'; _remoteCount = 0; });
  }

  Future<void> _syncNow() async {
    if (!DriveSyncService.isSignedIn) {
      setState(() => _status = 'Please sign in first');
      return;
    }
    setState(() { _busy = true; _status = 'Uploading pending receipts…'; });
    final uploaded = await DriveSyncService.syncPendingUploads();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = '$uploaded receipt(s) uploaded';
    });
    _refreshRemoteCount();
  }

  Future<void> _refreshRemoteCount() async {
    final list = await DriveSyncService.listRemoteReceipts();
    if (mounted) setState(() => _remoteCount = list.length);
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = DriveSyncService.isSignedIn;
    return Scaffold(
      backgroundColor: const Color(0xFFEBF5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C5545),
        title: const Text('Backup & Sync', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(signedIn ? Icons.cloud_done : Icons.cloud_off,
                          color: signedIn ? Colors.green : Colors.grey),
                      const SizedBox(width: 8),
                      Text(signedIn ? 'Connected to Drive' : 'Not connected',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
                    if (signedIn) ...[
                      const SizedBox(height: 8),
                      Text('Account: ${DriveSyncService.userEmail ?? "?"}',
                          style: const TextStyle(color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text('Receipts in Drive: $_remoteCount',
                          style: const TextStyle(color: Colors.black54)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (!signedIn)
              ElevatedButton.icon(
                onPressed: _busy ? null : _signIn,
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C5545), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              )
            else ...[
              ElevatedButton.icon(
                onPressed: _busy ? null : _syncNow,
                icon: const Icon(Icons.sync),
                label: const Text('Sync now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C5545), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : _signOut,
                child: const Text('Sign out'),
              ),
            ],
            const SizedBox(height: 20),
            if (_busy) const Center(child: CircularProgressIndicator()),
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_status),
              ),
            const Spacer(),
            const Text(
              'Receipts are stored in your Google Drive\'s hidden app folder. '
              'They don\'t appear in your normal Drive UI and aren\'t shared. '
              'Sign in with the same account on any device to access them.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
