import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../features/transactions/domain/transaction.dart';

/// Writes ledger exports to the app's own documents directory and hands
/// them to the OS share sheet -- this replaces a prior implementation that
/// hardcoded a Windows dev-machine path (`d:\FinFlow\docs\...`), which
/// silently failed (or wrote nowhere useful) on every real device.
class ExportService {
  const ExportService._();

  static Future<File> exportCsv(List<TransactionModel> transactions) async {
    final buffer = StringBuffer();
    buffer.writeln(
      'Transaction ID,Date,Payee/Merchant,Category,Bucket,Amount,Note,Reference ID',
    );
    for (final t in transactions) {
      final dateStr = DateFormat('yyyy-MM-dd').format(t.date);
      final payee = t.payee.replaceAll('"', '""');
      final note = t.note.replaceAll('"', '""');
      buffer.writeln(
        '"${t.id}","$dateStr","$payee","${t.category}","${t.bucket.displayName}",${t.amount},"$note","${t.refId}"',
      );
    }

    final file = await _writeToDocuments(
      'FinFlow_Ledger_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      buffer.toString(),
    );
    await _share(file, 'FinFlow ledger export (CSV)');
    return file;
  }

  static Future<File> exportPdf(List<TransactionModel> transactions) async {
    final doc = pw.Document();
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: 'Rs. ',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM yyyy');

    const rowsPerPage = 28;
    for (var start = 0; start < transactions.length; start += rowsPerPage) {
      final pageRows = transactions.skip(start).take(rowsPerPage).toList();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (start == 0) ...[
                  pw.Text(
                    'FinFlow Ledger Export',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Generated ${dateFormat.format(DateTime.now())} -- ${transactions.length} transactions',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 12),
                ],
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(2),
                    1: pw.FlexColumnWidth(3),
                    2: pw.FlexColumnWidth(2),
                    3: pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _pdfCell('Date', bold: true),
                        _pdfCell('Payee / Category', bold: true),
                        _pdfCell('Bucket', bold: true),
                        _pdfCell('Amount', bold: true, alignRight: true),
                      ],
                    ),
                    ...pageRows.map((t) {
                      final isDebit = t.bucket != BudgetBucket.income;
                      return pw.TableRow(
                        children: [
                          _pdfCell(dateFormat.format(t.date)),
                          _pdfCell(
                            '${t.payee.isNotEmpty ? t.payee : t.category}\n${t.category}',
                          ),
                          _pdfCell(t.bucket.displayName),
                          _pdfCell(
                            '${isDebit ? '-' : '+'}${currency.format(t.amount)}',
                            alignRight: true,
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    final bytes = await doc.save();
    final file = await _writeBytesToDocuments(
      'FinFlow_Ledger_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      bytes,
    );
    await _share(file, 'FinFlow ledger export (PDF)');
    return file;
  }

  static pw.Widget _pdfCell(String text, {bool bold = false, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  static Future<File> _writeToDocuments(String fileName, String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    return file.writeAsString(content);
  }

  static Future<File> _writeBytesToDocuments(
    String fileName,
    List<int> bytes,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    return file.writeAsBytes(bytes);
  }

  static Future<void> _share(File file, String text) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: text),
    );
  }
}
