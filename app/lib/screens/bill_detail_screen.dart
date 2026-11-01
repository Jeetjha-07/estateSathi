import 'package:flutter/material.dart';
import '../api.dart';
import '../pdf_bill.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

class BillDetailScreen extends StatelessWidget {
  final Map<String, dynamic> bill;
  final Map<String, dynamic> detail;
  final num balance; // tenant ka kul baaki (sab milakar)
  const BillDetailScreen({super.key, required this.bill, required this.detail, required this.balance});

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(k, style: const TextStyle(color: kGrey, fontSize: 13))),
            const Text(':  ', style: TextStyle(color: kGrey)),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
      );

  Widget _tr(String a, String b, {bool head = false, bool total = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: total ? kGreen.withAlpha(30) : (head ? const Color(0xFFF0EEE6) : null),
          border: total || head ? null : const Border(bottom: BorderSide(color: kLine)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(a,
                  style: TextStyle(fontSize: 13, fontWeight: head || total ? FontWeight.w700 : FontWeight.w500, color: total ? kGreen : kInk)),
            ),
            Text(b, style: TextStyle(fontSize: 13, fontWeight: head || total ? FontWeight.w800 : FontWeight.w600, color: total ? kGreen : kInk)),
          ],
        ),
      );

  Future<void> _remind(BuildContext context) async {
    final t = detail['tenant'] as Map;
    final phone = '${t['phone']}';
    final text = billText(bill, detail, balance);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Bill / Reminder bhejein', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
              ),
              ListTile(
                leading: const Icon(Icons.chat_rounded, color: kGreen),
                title: const Text('WhatsApp'),
                onTap: () => Navigator.pop(ctx, 'wa'),
              ),
              ListTile(
                leading: const Icon(Icons.sms_rounded, color: kPrimary),
                title: const Text('SMS (seedha bhejein)'),
                subtitle: const Text('Phone/SMS permission maangega'),
                onTap: () => Navigator.pop(ctx, 'sms'),
              ),
              ListTile(
                leading: const Icon(Icons.send_rounded, color: kAmber),
                title: const Text('Dono'),
                onTap: () => Navigator.pop(ctx, 'both'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'sms' || choice == 'both') await sendSms(context, phone, text);
    if ((choice == 'wa' || choice == 'both') && context.mounted) await sendWhatsApp(context, phone, text);
  }

  Future<void> _savePdf(BuildContext context) async {
    try {
      await saveBillPdf(bill, detail, balance);
    } catch (e) {
      if (context.mounted) toast(context, 'PDF nahi ban paya: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = detail['tenant'] as Map;
    final status = bill['status'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Preview'),
        actions: [IconButton(tooltip: 'Share / Save PDF', icon: const Icon(Icons.share_rounded), onPressed: () => _savePdf(context))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          SoftCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: AppLogo(size: 26)),
                const SizedBox(height: 14),
                const Center(child: Text('RENT INVOICE', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2))),
                Center(child: Text(fmtMonth(bill['billDate']), style: const TextStyle(color: kGrey, fontSize: 13))),
                if (status != null) ...[
                  const SizedBox(height: 8),
                  Center(child: StatusPill('$status')),
                ],
                const SizedBox(height: 16),
                _kv('Tenant Name', '${t['name']}'),
                _kv('Room No.', '${detail['room']?['name'] ?? ''}'),
                _kv('Property', '${detail['property']?['name'] ?? ''}'),
                _kv('Due Date', billDueDate(bill, t)),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: kLine)),
                    child: Column(
                      children: [
                        _tr('Description', 'Amount', head: true),
                        _tr('Monthly Rent', rupee(bill['rent'])),
                        _tr('Electricity (${fmtNum(bill['units'])} units × ${rupee(bill['rate'])})', rupee(bill['electricity'])),
                        _tr('Water Charge (Fixed)', rupee(bill['water'])),
                        _tr('Garbage Charge (Fixed)', rupee(bill['garbage'])),
                        _tr('Total Amount', rupee(bill['total']), total: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Meter reading: ${fmtNum(bill['prevReading'])} → ${fmtNum(bill['newReading'])}',
                    style: const TextStyle(color: kGrey, fontSize: 12)),
                if (balance > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Kul baaki (sab bills milakar): ${rupee(balance)}',
                        style: const TextStyle(color: kRed, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                const SizedBox(height: 16),
                const Text('Please pay by due date. Thank you!', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          if ('${bill['meterPhoto'] ?? ''}'.isNotEmpty) ...[
            const SectionTitle('Meter ki photo'),
            GestureDetector(
              onTap: () => showPhoto(context, bill['meterPhoto'] as String?),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: Image.network(
                    Api.fileUrl(bill['meterPhoto'] as String?),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: kGrey),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _remind(context),
                  icon: const Icon(Icons.chat_rounded, size: 19),
                  label: const Text('Send Reminder'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _savePdf(context),
                  icon: const Icon(Icons.download_rounded, size: 19),
                  label: const Text('Save Bill'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
