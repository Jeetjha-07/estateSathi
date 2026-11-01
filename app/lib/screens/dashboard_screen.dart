import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'pending_screen.dart';
import 'tenant_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  List<Map<String, dynamic>> _list(dynamic v) => List<Map<String, dynamic>>.from(v as List);

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good Morning' : (h < 17 ? 'Good Afternoon' : 'Good Evening');
  }

  @override
  Widget build(BuildContext context) {
    return Loader<Map<String, dynamic>>(
      load: () async => Map<String, dynamic>.from(await Api.get('/dashboard')),
      builder: (ctx, d, reload) {
        final pending = _list(d['pending']);
        final toBill = _list(d['toBill']);

        Future<void> open(String id) async {
          await Navigator.push(ctx, MaterialPageRoute(builder: (_) => TenantDetailScreen(tenantId: id)));
          reload();
        }

        Future<void> openPending() async {
          await Navigator.push(ctx, MaterialPageRoute(builder: (_) => PendingScreen(items: pending)));
          reload();
        }

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: const AppLogo(size: 24),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  onPressed: openPending,
                  icon: Badge(
                    isLabelVisible: pending.isNotEmpty,
                    label: Text('${pending.length}'),
                    child: const Icon(Icons.notifications_none_rounded, size: 28),
                  ),
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_greeting()}, ${Api.userName} 👋',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      const Text("Here's your property overview", style: TextStyle(color: kGrey, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _tile(Icons.account_balance_wallet_rounded, kGreen, rupee(d['collectedThisMonth']), 'Collected This Month')),
                    const SizedBox(width: 12),
                    Expanded(child: _tile(Icons.currency_rupee_rounded, kRed, rupee(d['totalPending']), 'Pending Rents')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _tile(Icons.people_alt_rounded, kBlue, '${d['totalTenants']}', 'Total Tenants')),
                    const SizedBox(width: 12),
                    Expanded(child: _tile(Icons.event_available_rounded, kAmber, '${d['dueThisWeek']}', 'Due This Week')),
                  ],
                ),
                const SizedBox(height: 14),
                const CollectionChart(),
                if (n(d['propertiesCount']) == 0)
                  const SoftCard(child: EmptyBox(Icons.add_home_work_rounded, 'Properties tab me jaakar apni pehli property add karein')),
                SectionTitle('Pending Payments',
                    trailing: pending.isEmpty ? null : TextButton(onPressed: openPending, child: const Text('View All'))),
                if (pending.isEmpty && n(d['totalTenants']) > 0)
                  const SoftCard(child: EmptyBox(Icons.check_circle_rounded, 'Koi payment pending nahi hai. Badhiya!')),
                for (final p in pending.take(5)) PendingTile(p: p, onTap: () => open('${p['tenantId']}')),
                if (toBill.isNotEmpty) ...[
                  SectionTitle('Bill banana baaki (${toBill.length})'),
                  for (final t in toBill)
                    SoftCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      onTap: () => open('${t['tenantId']}'),
                      child: Row(
                        children: [
                          Avatar(photo: t['photo'] as String?, name: '${t['name']}', size: 46),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${t['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('${t['room']}  •  ${t['property']}', style: const TextStyle(fontSize: 12, color: kGrey)),
                              ],
                            ),
                          ),
                          Pill('Due ${ordinal(n(t['dueDay']).toInt())}', kAmber),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tile(IconData icon, Color color, String value, String label) {
    return SoftCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withAlpha(28), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                Text(label, maxLines: 2, style: const TextStyle(fontSize: 11, color: kGrey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CollectionChart extends StatefulWidget {
  const CollectionChart({super.key});

  @override
  State<CollectionChart> createState() => _CollectionChartState();
}

class _CollectionChartState extends State<CollectionChart> {
  static const _months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
  final int _thisYear = DateTime.now().year;
  late int _year = _thisYear;
  late Future<Map<String, dynamic>> _future = _load();

  Future<Map<String, dynamic>> _load() async => Map<String, dynamic>.from(await Api.get('/collection?year=$_year'));

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Monthly Collection ($_year)', style: const TextStyle(fontWeight: FontWeight.w600))),
              DropdownButton<int>(
                value: _year,
                underline: const SizedBox(),
                isDense: true,
                borderRadius: BorderRadius.circular(14),
                style: const TextStyle(color: kGrey, fontSize: 12, fontWeight: FontWeight.w500),
                items: [
                  DropdownMenuItem(value: _thisYear, child: const Text('This Year')),
                  DropdownMenuItem(value: _thisYear - 1, child: const Text('Last Year')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _year = v;
                    _future = _load();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (c, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }
                if (snap.hasError || snap.data == null) {
                  return const Center(child: Text('Chart load nahi hua', style: TextStyle(color: kGrey)));
                }
                final vals = (snap.data!['months'] as List).map((e) => n(e).toDouble()).toList();
                final maxV = vals.fold<double>(0, (a, b) => b > a ? b : a);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < 12; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (vals[i] > 0)
                                Text(vals[i] >= 1000 ? '${(vals[i] / 1000).toStringAsFixed(vals[i] >= 10000 ? 0 : 1)}k' : fmtNum(vals[i]),
                                    style: const TextStyle(fontSize: 8, color: kGrey)),
                              const SizedBox(height: 2),
                              Container(
                                height: maxV == 0 ? 3 : (vals[i] / maxV * 100).clamp(3, 100).toDouble(),
                                decoration: BoxDecoration(
                                  color: vals[i] > 0 ? kGreen : kLine,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(_months[i], style: const TextStyle(fontSize: 10, color: kGrey)),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
