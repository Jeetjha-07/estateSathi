import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../ui_extras.dart';
import '../utils.dart';
import '../widgets.dart';
import 'bill_detail_screen.dart';
import 'generate_bill_screen.dart';
import 'record_payment_screen.dart';
import 'tenant_form_screen.dart';

class TenantDetailScreen extends StatefulWidget {
  final String tenantId;
  const TenantDetailScreen({super.key, required this.tenantId});

  @override
  State<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends State<TenantDetailScreen> {
  int _tab = 0; // 0 Details, 1 Family, 2 Bills, 3 Payments

  String _reminder(Map<String, dynamic> d) {
    final t = d['tenant'] as Map;
    return reminderText(
      name: '${t['name']}',
      property: '${d['property']?['name'] ?? ''}',
      room: '${d['room']?['name'] ?? ''}',
      balance: d['balance'],
      dueDay: parseD(t['entryDate']).day,
    );
  }

  Future<void> _sendReminder(Map<String, dynamic> d) async {
    if (n(d['balance']) <= 0) {
      toast(context, 'Is tenant ka koi payment baaki nahi hai');
      return;
    }
    final phone = '${(d['tenant'] as Map)['phone']}';
    final text = _reminder(d);
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
                child: Text('Reminder bhejein', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
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
    if (choice == null || !mounted) return;
    if (choice == 'sms' || choice == 'both') await sendSms(context, phone, text);
    if ((choice == 'wa' || choice == 'both') && mounted) await sendWhatsApp(context, phone, text);
  }

  Future<void> _deleteTenant(Map<String, dynamic> d) async {
    final t = d['tenant'] as Map;
    final ok = await confirmDelete(context, 'Tenant delete karein?',
        '"${t['name']}" ka poora data (bills, payments, photos) delete ho jayega aur room khaali ho jayega.');
    if (!ok) return;
    try {
      await Api.delete('/tenants/${widget.tenantId}');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: Text(label, style: const TextStyle(color: kGrey, fontSize: 13))),
          Expanded(
            flex: 5,
            child: Text(value.isEmpty ? '-' : value,
                textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _roundIcon(IconData icon, Color c, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.withAlpha(120)), color: c.withAlpha(18)),
          child: Icon(icon, size: 20, color: c),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Loader<Map<String, dynamic>>(
      standalone: true,
      load: () async => Map<String, dynamic>.from(await Api.get('/tenants/${widget.tenantId}')),
      builder: (ctx, d, reload) {
        final t = Map<String, dynamic>.from(d['tenant'] as Map);
        final bills = List<Map<String, dynamic>>.from(d['bills'] as List);
        final payments = List<Map<String, dynamic>>.from(d['payments'] as List);
        final family = List<Map<String, dynamic>>.from((t['family'] as List?) ?? []);
        final balance = n(d['balance']);
        final dueDay = parseD(t['entryDate']).day;
        final floor = '${d['room']?['floor'] ?? ''}';

        Widget detailsTab() => SoftCard(
              child: Column(
                children: [
                  _row('Address', '${t['address'] ?? ''}'),
                  _row('Aadhar Number', '${t['aadhar'] ?? ''}'),
                  _row('Entry Date', fmtDate(t['entryDate'])),
                  _row('Due Date', 'Har mahine ${ordinal(dueDay)} ko'),
                  const Divider(height: 18),
                  _row('Monthly Rent', rupee(t['monthlyRent'])),
                  _row('Electricity Rate', '${rupee(t['electricityRate'])} per unit'),
                  _row('Water Charge (Fixed)', rupee(t['waterAmount'])),
                  _row('Garbage Charge (Fixed)', rupee(t['garbageAmount'])),
                  _row('Current Meter Reading', '${fmtNum(t['currentReading'])} units'),
                ],
              ),
            );

        Widget familyTab() {
          if (family.isEmpty) return const EmptyBox(Icons.family_restroom_rounded, 'Koi family member add nahi kiya.\nEdit se add kar sakte hain.');
          return SoftCard(
            child: Column(
              children: [
                for (final f in family)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Avatar(name: '${f['name']}', size: 42),
                    title: Text('${f['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      if ('${f['relation'] ?? ''}'.isNotEmpty) '${f['relation']}',
                      if ('${f['age'] ?? ''}'.isNotEmpty) '${f['age']} saal',
                    ].join(' • ')),
                  ),
              ],
            ),
          );
        }

        Widget billsTab() {
          if (bills.isEmpty) return const EmptyBox(Icons.receipt_long_rounded, 'Abhi koi bill nahi bana');
          return Column(
            children: [
              for (final b in bills)
                SoftCard(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(builder: (_) => BillDetailScreen(bill: b, detail: d, balance: balance)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: kPrimary.withAlpha(22), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.receipt_long_rounded, color: kPrimary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fmtMonth(b['billDate']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${fmtDate(b['billDate'])} • ${fmtNum(b['units'])} unit',
                                style: const TextStyle(fontSize: 12, color: kGrey)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(rupee(b['total']), style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          StatusPill('${b['status'] ?? 'pending'}'),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: kRed, size: 22),
                        onPressed: () async {
                          final ok = await confirmDelete(ctx, 'Bill delete karein?', '${fmtMonth(b['billDate'])} ka bill delete ho jayega.');
                          if (!ok) return;
                          try {
                            await Api.delete('/bills/${b['_id']}');
                            await reload();
                          } catch (e) {
                            if (ctx.mounted) toast(ctx, '$e', error: true);
                          }
                        },
                      ),
                    ],
                  ),
                ),
            ],
          );
        }

        Widget paymentsTab() {
          if (payments.isEmpty) return const EmptyBox(Icons.payments_rounded, 'Abhi koi payment record nahi hui');
          return Column(
            children: [
              for (final p in payments)
                SoftCard(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: kGreen.withAlpha(26), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.calendar_month_rounded, color: kGreen, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fmtMonth(p['date']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(
                              [fmtDate(p['date']), '${p['mode'] ?? 'Cash'}', if ('${p['note'] ?? ''}'.isNotEmpty) '${p['note']}'].join(' • '),
                              style: const TextStyle(fontSize: 12, color: kGrey),
                            ),
                          ],
                        ),
                      ),
                      Text(rupee(p['amount']), style: const TextStyle(fontWeight: FontWeight.w700, color: kGreen)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: kRed, size: 22),
                        onPressed: () async {
                          final ok = await confirmDelete(ctx, 'Payment delete karein?', '${rupee(p['amount'])} ki payment delete ho jayegi.');
                          if (!ok) return;
                          try {
                            await Api.delete('/payments/${p['_id']}');
                            await reload();
                          } catch (e) {
                            if (ctx.mounted) toast(ctx, '$e', error: true);
                          }
                        },
                      ),
                    ],
                  ),
                ),
            ],
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tenant Profile'),
            actions: [
              PopupMenuButton<String>(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (v) async {
                  if (v == 'edit') {
                    final ok = await Navigator.push(ctx, MaterialPageRoute(builder: (_) => TenantFormScreen(tenant: t)));
                    if (ok == true) reload();
                  } else if (v == 'reminder') {
                    _sendReminder(d);
                  } else if (v == 'delete') {
                    _deleteTenant(d);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Details edit karein')),
                  PopupMenuItem(value: 'reminder', child: Text('Reminder bhejein')),
                  PopupMenuItem(value: 'delete', child: Text('Tenant delete karein', style: TextStyle(color: kRed))),
                ],
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        await Navigator.push(ctx, MaterialPageRoute(builder: (_) => GenerateBillScreen(detail: d)));
                        reload();
                      },
                      child: const Text('Generate Bill'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final ok = await Navigator.push(ctx, MaterialPageRoute(builder: (_) => RecordPaymentScreen(detail: d)));
                        if (ok == true) {
                          await reload();
                          if (ctx.mounted) toast(ctx, 'Payment record ho gayi');
                        }
                      },
                      child: const Text('Record Payment'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                SoftCard(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => showPhoto(ctx, t['photo'] as String?),
                        child: Avatar(photo: t['photo'] as String?, name: '${t['name']}', size: 84),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${t['name']}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(
                              '${d['room']?['name'] ?? ''}${floor.isNotEmpty ? ' • $floor' : ''}',
                              style: const TextStyle(color: kGrey, fontSize: 13),
                            ),
                            Text('${d['property']?['name'] ?? ''}', style: const TextStyle(color: kGrey, fontSize: 12)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Pill('Active', kGreen),
                                const Spacer(),
                                _roundIcon(Icons.call_rounded, kGreen, () => callNumber('${t['phone']}')),
                                const SizedBox(width: 8),
                                _roundIcon(Icons.chat_rounded, kGreen, () => sendWhatsApp(ctx, '${t['phone']}', 'Namaste ${t['name']} ji,')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: (balance > 0 ? kRed : kGreen).withAlpha(20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: (balance > 0 ? kRed : kGreen).withAlpha(70)),
                  ),
                  child: Row(
                    children: [
                      Icon(balance > 0 ? Icons.warning_amber_rounded : Icons.check_circle_rounded, color: balance > 0 ? kRed : kGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          balance > 0
                              ? 'Baaki: ${rupee(balance)}'
                              : (balance < 0 ? 'Sab clear (Advance ${rupee(-balance)})' : 'Sab clear'),
                          style: TextStyle(fontWeight: FontWeight.w700, color: balance > 0 ? kRed : kGreen),
                        ),
                      ),
                      if (balance > 0)
                        TextButton(
                          style: TextButton.styleFrom(foregroundColor: kRed),
                          onPressed: () => _sendReminder(d),
                          child: const Text('Reminder'),
                        ),
                    ],
                  ),
                ),
                TabsRow(
                  labels: ['Details', 'Family', 'Bills', 'Payments'],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
                if (_tab == 0) detailsTab(),
                if (_tab == 1) familyTab(),
                if (_tab == 2) billsTab(),
                if (_tab == 3) paymentsTab(),
              ],
            ),
          ),
        );
      },
    );
  }
}
