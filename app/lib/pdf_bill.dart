import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'utils.dart';

String _rs(dynamic v) => rupee(v).replaceAll('₹', 'Rs. ');

/// Bill ki due date: bill ke mahine me tenant ki entry wali tarikh
String billDueDate(Map bill, Map tenant) {
  final bd = parseD(bill['billDate']);
  final e = tenant['entryDate'];
  final day = e == null ? bd.day : parseD(e).day;
  final last = DateTime(bd.year, bd.month + 1, 0).day;
  return fmtDate(DateTime(bd.year, bd.month, day > last ? last : day));
}

/// Bill ko PDF bana kar share / save ka option kholta hai
Future<void> saveBillPdf(Map bill, Map detail, num balance) async {
  final t = detail['tenant'] as Map;
  final doc = pw.Document();

  pw.Widget kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.SizedBox(width: 100, child: pw.Text(k, style: pw.TextStyle(color: PdfColors.grey700))),
          pw.Text(': $v'),
        ]),
      );

  pw.Widget row(String k, String v, {bool total = false}) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        decoration: total
            ? pw.BoxDecoration(color: PdfColor.fromInt(0xFFE3F4EA))
            : pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(k, style: total ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
            pw.Text(v, style: total ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null),
          ],
        ),
      );

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a5,
    margin: const pw.EdgeInsets.all(28),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(child: pw.Text('EstateSathi', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('RENT INVOICE', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
        pw.Center(child: pw.Text(fmtMonth(bill['billDate']))),
        pw.SizedBox(height: 16),
        kv('Tenant Name', '${t['name']}'),
        kv('Room No.', '${detail['room']?['name'] ?? ''}'),
        kv('Property', '${detail['property']?['name'] ?? ''}'),
        kv('Due Date', billDueDate(bill, t)),
        pw.SizedBox(height: 14),
        row('Description', 'Amount'),
        row('Monthly Rent', _rs(bill['rent'])),
        row('Electricity (${fmtNum(bill['units'])} units x ${_rs(bill['rate'])})', _rs(bill['electricity'])),
        row('Water Charge (Fixed)', _rs(bill['water'])),
        row('Garbage Charge (Fixed)', _rs(bill['garbage'])),
        row('Total Amount', _rs(bill['total']), total: true),
        if (balance > 0) pw.SizedBox(height: 6),
        if (balance > 0) pw.Text('Total pending (all bills): ${_rs(balance)}'),
        pw.SizedBox(height: 18),
        pw.Text('Please pay by due date. Thank you!'),
      ],
    ),
  ));

  final name = 'EstateSathi_${t['name']}_${bill['billDate'].toString().substring(0, 7)}.pdf'
      .replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  await Printing.sharePdf(bytes: await doc.save(), filename: name);
}
