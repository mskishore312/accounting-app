import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<File> generateLedgerPdf({
    required String companyName,
    required String ledgerName,
    required String periodText,
    required double openingBalance,
    required bool isOpeningBalanceDebit,
    required List<Map<String, dynamic>> entries,
    required double closingBalance,
    required bool isClosingBalanceDebit,
    required double totalDebit,
    required double totalCredit,
    bool showNarration = false,
  }) async {
    final pdf = pw.Document();

    // Format currency
    String formatAmount(double amount) {
      return amount.toStringAsFixed(2);
    }

    // Define column widths for consistent alignment
    final dateWidth = 60.0;
    final particularsWidth = 140.0;
    final vchTypeWidth = 50.0;
    final vchNoWidth = 40.0;
    final debitWidth = 60.0;
    final creditWidth = 60.0;
    final balanceWidth = 70.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          // Build all table rows
          List<pw.TableRow> allRows = [];

          // Header Row
          allRows.add(
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Container(
                  width: dateWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ),
                pw.Container(
                  width: particularsWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Particulars', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ),
                pw.Container(
                  width: vchTypeWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Vch Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                ),
                pw.Container(
                  width: vchNoWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Vch No.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                ),
                pw.Container(
                  width: debitWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Debit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right),
                ),
                pw.Container(
                  width: creditWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Credit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right),
                ),
                pw.Container(
                  width: balanceWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Balance', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9), textAlign: pw.TextAlign.right),
                ),
              ],
            ),
          );

          // Opening Balance Row
          allRows.add(
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                pw.Container(
                  width: dateWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Container(
                  width: particularsWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Opening Balance', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                ),
                pw.Container(
                  width: vchTypeWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Container(
                  width: vchNoWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Container(
                  width: debitWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    isOpeningBalanceDebit ? formatAmount(openingBalance.abs()) : '',
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Container(
                  width: creditWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    !isOpeningBalanceDebit ? formatAmount(openingBalance.abs()) : '',
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Container(
                  width: balanceWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    '${formatAmount(openingBalance.abs())} ${isOpeningBalanceDebit ? "Dr" : "Cr"}',
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          );

          // Transaction Rows
          for (var entry in entries) {
            final date = entry['voucher_date'] as String? ?? '';
            final particulars = entry['particulars'] as String? ?? '';
            final narration = showNarration ? (entry['description'] as String? ?? '') : '';
            final voucherType = entry['voucher_type'] as String? ?? '';
            final voucherNo = entry['voucher_no']?.toString() ?? '';
            final debit = (entry['debit'] as num?)?.toDouble() ?? 0.0;
            final credit = (entry['credit'] as num?)?.toDouble() ?? 0.0;
            final balance = (entry['balance'] as num?)?.toDouble() ?? 0.0;
            final balanceType = entry['balance_type'] as String? ?? 'Dr';

            allRows.add(
              pw.TableRow(
                children: [
                  pw.Container(
                    width: dateWidth,
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(date, style: const pw.TextStyle(fontSize: 8)),
                  ),
                  pw.Container(
                    width: particularsWidth,
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(particulars, style: const pw.TextStyle(fontSize: 8)),
                        if (showNarration && narration.isNotEmpty)
                          pw.Text(
                            '($narration)',
                            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                          ),
                      ],
                    ),
                  ),
                  pw.Container(
                    width: vchTypeWidth,
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(voucherType, style: const pw.TextStyle(fontSize: 7)),
                  ),
                  pw.Container(
                    width: vchNoWidth,
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(voucherNo, style: const pw.TextStyle(fontSize: 8)),
                  ),
                  pw.Container(
                    width: debitWidth,
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      debit > 0 ? formatAmount(debit) : '',
                      style: const pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Container(
                    width: creditWidth,
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      credit > 0 ? formatAmount(credit) : '',
                      style: const pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Container(
                    width: balanceWidth,
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      '${formatAmount(balance.abs())} $balanceType',
                      style: const pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }

          // Current Total Row
          allRows.add(
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                pw.Container(
                  width: dateWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Container(
                  width: particularsWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Current Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                ),
                pw.Container(
                  width: vchTypeWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Container(
                  width: vchNoWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Container(
                  width: debitWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    formatAmount(totalDebit + (isOpeningBalanceDebit ? openingBalance.abs() : 0)),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Container(
                  width: creditWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    formatAmount(totalCredit + (!isOpeningBalanceDebit ? openingBalance.abs() : 0)),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Container(
                  width: balanceWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('', style: const pw.TextStyle(fontSize: 8)),
                ),
              ],
            ),
          );

          // Closing Balance Row
          allRows.add(
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Container(
                  width: dateWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Container(
                  width: particularsWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Closing Balance', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                ),
                pw.Container(
                  width: vchTypeWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Container(
                  width: vchNoWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('', style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.Container(
                  width: debitWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    isClosingBalanceDebit ? formatAmount(closingBalance.abs()) : '',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Container(
                  width: creditWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    !isClosingBalanceDebit ? formatAmount(closingBalance.abs()) : '',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
                pw.Container(
                  width: balanceWidth,
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    '${formatAmount(closingBalance.abs())} ${isClosingBalanceDebit ? "Dr" : "Cr"}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          );

          return [
            // Company Name Header
            pw.Center(
              child: pw.Text(
                companyName,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 6),

            // Ledger Name
            pw.Center(
              child: pw.Text(
                'Ledger: $ledgerName',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 3),

            // Period
            pw.Center(
              child: pw.Text(
                'Period: $periodText',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
            pw.SizedBox(height: 10),

            // Single unified table with all rows
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey800, width: 0.5),
              columnWidths: {
                0: pw.FixedColumnWidth(dateWidth),
                1: pw.FixedColumnWidth(particularsWidth),
                2: pw.FixedColumnWidth(vchTypeWidth),
                3: pw.FixedColumnWidth(vchNoWidth),
                4: pw.FixedColumnWidth(debitWidth),
                5: pw.FixedColumnWidth(creditWidth),
                6: pw.FixedColumnWidth(balanceWidth),
              },
              children: allRows,
            ),

            pw.SizedBox(height: 10),

            // Footer
            pw.Text(
              'Generated on ${DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
          ];
        },
      ),
    );

    // Save PDF to temporary directory
    final output = await getTemporaryDirectory();
    final fileName = 'Ledger_${ledgerName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  static Future<void> shareViaEmail(File pdfFile, String ledgerName) async {
    final result = await Share.shareXFiles(
      [XFile(pdfFile.path)],
      subject: 'Ledger Report - $ledgerName',
      text: 'Please find attached the ledger report for $ledgerName.',
    );

    if (result.status == ShareResultStatus.success) {
      // Successfully shared
    }
  }

  static Future<void> shareViaWhatsApp(File pdfFile, String ledgerName) async {
    try {
      // Share via WhatsApp
      await Share.shareXFiles(
        [XFile(pdfFile.path)],
        subject: 'Ledger Report - $ledgerName',
        text: 'Ledger Report: $ledgerName',
      );
    } catch (e) {
      throw Exception('Failed to share via WhatsApp');
    }
  }

  static Future<void> sendViaSMS(String phoneNumber, String message) async {
    final uri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': message},
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw Exception('Could not launch SMS');
    }
  }
}
