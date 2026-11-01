import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'bill_detail_screen.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  String _filter = 'all';

  Widget _chip(String label, String value) {
    final sel = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: sel ? kPrimary : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: sel ? kPrimary : kLine),
          ),
          child: Text(label, style: TextStyle(color: sel ? Colors.white : kInk, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      load: () async => List<Map<String, dynamic>>.from(await Api.get('/bills') as List),
      builder: (ctx, all, reload) {
        final list = _filter == 'all' ? all : all.where((b) => b['status'] == _filter).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Bills')),
          body: RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [_chip('All', 'all'), _chip('Pending', 'pending'), _chip('Partial', 'partial'), _chip('Paid', 'paid')]),
                ),
                const SizedBox(height: 14),
                if (list.isEmpty) const EmptyBox(Icons.receipt_long_rounded, 'Koi bill nahi mila'),
                for (final b in list)
                  SoftCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    onTap: () {
                      final detail = {
                        'tenant': {'name': b['tenantName'], 'phone': b['phone']},
                        'property': {'name': b['property']},
                        'room': {'name': b['room']},
                      };
                      Navigator.push(
                        ctx,
                        MaterialPageRoute(builder: (_) => BillDetailScreen(bill: b, detail: detail, balance: n(b['balance']))),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: kPrimary.withAlpha(22), borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.receipt_long_rounded, color: kPrimary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${b['tenantName']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${fmtMonth(b['billDate'])}  •  ${b['room']}',
                                  style: const TextStyle(fontSize: 12, color: kGrey)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(rupee(b['total']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            StatusPill('${b['status']}'),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
