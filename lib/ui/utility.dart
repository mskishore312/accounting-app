import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/services/backup_service.dart';
import 'package:accounting_app/services/split_company_service.dart';
import 'package:accounting_app/ui/company_settings_selection.dart';
import 'package:accounting_app/ui/edit_company.dart';
import 'package:accounting_app/ui/ai_settings.dart';

class Utility extends StatelessWidget {
  const Utility({Key? key}) : super(key: key);

  void _showSnack(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _runBackup(BuildContext context) async {
    try {
      final path = await BackupService.backupToFile();
      if (!context.mounted) return;
      if (path != null) {
        _showSnack(context, 'Backup saved');
      }
    } catch (e) {
      if (context.mounted) _showSnack(context, 'Backup failed: $e', error: true);
    }
  }

  Future<void> _runBackupAndMail(BuildContext context) async {
    try {
      await BackupService.backupAndShare();
    } catch (e) {
      if (context.mounted) _showSnack(context, 'Backup failed: $e', error: true);
    }
  }

  Future<void> _runRestore(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore'),
        content: const Text(
          'Restoring replaces ALL current data on this device with the '
          'selected backup. This cannot be undone.\n\nContinue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await BackupService.restoreFromPickedFile();
      await StorageService.clearSelectedCompany();
      if (context.mounted) {
        _showSnack(context, 'Data restored successfully');
      }
    } on RestoreCancelled {
      // user backed out of the file picker
    } catch (e) {
      if (context.mounted) _showSnack(context, 'Restore failed: $e', error: true);
    }
  }

  Future<void> _runEmergencyBackup(BuildContext context) async {
    try {
      await BackupService.emergencyBackup();
      if (context.mounted) {
        _showSnack(context, 'Emergency backup saved on this device');
      }
    } catch (e) {
      if (context.mounted) _showSnack(context, 'Backup failed: $e', error: true);
    }
  }

  Future<void> _runEmergencyRestore(BuildContext context) async {
    List<File> backups;
    try {
      backups = await BackupService.listEmergencyBackups();
    } catch (e) {
      if (context.mounted) _showSnack(context, 'Error: $e', error: true);
      return;
    }
    if (!context.mounted) return;
    if (backups.isEmpty) {
      _showSnack(context, 'No emergency backups found on this device',
          error: true);
      return;
    }
    final chosen = await showDialog<File>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Emergency Restore'),
        children: backups
            .map(
              (file) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(file),
                child: Text(
                  _describeBackupFile(file),
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (chosen == null || !context.mounted) return;
    try {
      await BackupService.restoreFromEmergencyBackup(chosen);
      await StorageService.clearSelectedCompany();
      if (context.mounted) {
        _showSnack(context, 'Data restored from emergency backup');
      }
    } catch (e) {
      if (context.mounted) _showSnack(context, 'Restore failed: $e', error: true);
    }
  }

  String _describeBackupFile(File file) {
    // tompa_backup_yyyyMMdd_HHmmss.db
    final name = file.uri.pathSegments.last;
    final match =
        RegExp(r'tompa_backup_(\d{8})_(\d{6})\.db').firstMatch(name);
    if (match == null) return name;
    final d = match.group(1)!;
    final t = match.group(2)!;
    return '${d.substring(6, 8)}/${d.substring(4, 6)}/${d.substring(0, 4)} '
        '${t.substring(0, 2)}:${t.substring(2, 4)}:${t.substring(4, 6)}';
  }

  Future<void> _runSplitCompany(BuildContext context) async {
    List<Map<String, dynamic>> companies;
    try {
      companies = await StorageService.loadCompanies();
    } catch (e) {
      if (context.mounted) _showSnack(context, 'Error: $e', error: true);
      return;
    }
    if (!context.mounted) return;
    if (companies.isEmpty) {
      _showSnack(context, 'No companies to split', error: true);
      return;
    }
    final company = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Split Company'),
        children: companies
            .map(
              (c) => SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(c),
                child: Text(c['name'] as String? ?? '',
                    style: const TextStyle(fontSize: 16)),
              ),
            )
            .toList(),
      ),
    );
    if (company == null || !context.mounted) return;

    final splitDate = await showDatePicker(
      context: context,
      initialDate: DateTime(DateTime.now().year, 4, 1),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Split books from',
    );
    if (splitDate == null || !context.mounted) return;

    final splitDateDisplay = DateFormat('dd/MM/yyyy').format(splitDate);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Split Company?'),
        content: Text(
          'A new company "${company['name']} (from $splitDateDisplay)" will be '
          'created with books beginning $splitDateDisplay.\n\n'
          '• Closing balances up to that date become opening balances.\n'
          '• Vouchers from that date onwards are copied across.\n'
          '• "${company['name']}" itself is not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Split',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await SplitCompanyService.splitCompany(
        companyId: company['id'] as int,
        splitDate: splitDate,
      );
      if (context.mounted) {
        _showSnack(context,
            'Company split. New books start $splitDateDisplay');
      }
    } catch (e) {
      if (context.mounted) _showSnack(context, 'Split failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF5F0),

      
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF2C5545),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 32,
                    width: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      size: 20,
                      color: Color(0xFF2C5545),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: const Text(
                    'TOM-PA (V 4.5, R 73)',
              overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFF2C5545),
                    width: 1,
                  ),
                ),
              ),
              child: const Text(
                'Utility',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C5545),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildButton(
                      'Company Edit',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditCompanyScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      'Backup',
                      onPressed: () => _runBackup(context),
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      'Backup And Mail',
                      onPressed: () => _runBackupAndMail(context),
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      'Restore',
                      onPressed: () => _runRestore(context),
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      'Split Company',
                      onPressed: () => _runSplitCompany(context),
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      'Delete Company',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DeleteCompanyScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      'Settings',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CompanySettingsSelection(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      'AI Settings',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AiSettings(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      'Emergency Backup',
                      onPressed: () => _runEmergencyBackup(context),
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      'Emergency Restore',
                      onPressed: () => _runEmergencyRestore(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String text, {required VoidCallback onPressed}) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF4C7380),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DeleteCompanyScreen extends StatefulWidget {
  const DeleteCompanyScreen({Key? key}) : super(key: key);

  @override
  State<DeleteCompanyScreen> createState() => _DeleteCompanyScreenState();
}

class _DeleteCompanyScreenState extends State<DeleteCompanyScreen> {
  List<Map<String, dynamic>> companies = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    try {
      final loadedCompanies = await StorageService.loadCompanies();
      setState(() {
        companies = loadedCompanies;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading companies: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmationDialog(int companyId, String companyName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Company?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Warning: All data for this company will be permanently deleted from this device. This action cannot be undone.',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Company to be deleted:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  '• $companyName',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Do you really want to delete this company?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('No, Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteCompany(companyId, companyName);
              },
              child: const Text(
                'Yes, Delete',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCompany(int companyId, String companyName) async {
    try {
      await StorageService.deleteCompany(companyId);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Company "$companyName" deleted successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Reload the company list to reflect the deletion
        await _loadCompanies();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting company: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF5F0),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C5545),
        title: Row(
          children: [
            Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.account_balance,
                size: 20,
                color: Color(0xFF2C5545),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'TOM-PA (V 4.5, R 73)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF2C5545),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
            ),
            child: const Text(
              'Select Company to Delete',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : companies.isEmpty
                    ? const Center(
                        child: Text(
                          'No companies found.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        itemCount: companies.length,
                        itemBuilder: (context, index) {
                          final company = companies[index];
                          final companyId = company['id'] as int;
                          final companyName = company['name'] as String;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4C7380),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  _showDeleteConfirmationDialog(companyId, companyName);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          companyName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white70,
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
