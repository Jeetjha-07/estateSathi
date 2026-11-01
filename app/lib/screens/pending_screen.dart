import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'tenant_detail_screen.dart';

class PendingTile extends StatelessWidget {
  final Map<String, dynamic> p;
  final VoidCallback onTap;
  const PendingTile({super.key, required this.p, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final days = n(p['overdueDays']).toInt();
    return SoftCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Avatar(photo: p['photo'] as String?, name: '${p['name']}', size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${p['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${p['room']}  •  ${p['property']}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: kGrey)),
                const SizedBox(height: 2),
                Text(days > 0 ? '$days ${days == 1 ? 'day' : 'days'} overdue' : 'Payment baaki hai',
                    style: const TextStyle(fontSize: 12, color: kRed, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text(rupee(p['balance']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ],
      ),
    );
  }
}

class PendingScreen extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const PendingScreen({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Payments')),
      body: items.isEmpty
          ? const Center(child: EmptyBox(Icons.check_circle_rounded, 'Koi payment pending nahi hai'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                for (final p in items)
                  PendingTile(
                    p: p,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TenantDetailScreen(tenantId: '${p['tenantId']}')),
                    ),
                  ),
              ],
            ),
    );
  }
}
