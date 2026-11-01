import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'tenant_detail_screen.dart';

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      load: () async => List<Map<String, dynamic>>.from(await Api.get('/tenants') as List),
      builder: (ctx, all, reload) {
        final q = _q.toLowerCase();
        final list = all
            .where((t) => q.isEmpty ||
                '${t['name']}'.toLowerCase().contains(q) ||
                '${t['phone']}'.contains(q) ||
                '${t['room']}'.toLowerCase().contains(q) ||
                '${t['property']}'.toLowerCase().contains(q))
            .toList();
        return Scaffold(
          appBar: AppBar(title: Text('Tenants (${all.length})')),
          body: RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: const InputDecoration(hintText: 'Naam, phone ya room se dhundhein', prefixIcon: Icon(Icons.search_rounded)),
                ),
                const SizedBox(height: 14),
                if (list.isEmpty)
                  EmptyBox(Icons.people_outline_rounded, all.isEmpty ? 'Abhi koi tenant nahi hai.\nProperty > Room se tenant add karein.' : 'Koi tenant nahi mila'),
                for (final t in list)
                  SoftCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    onTap: () async {
                      await Navigator.push(ctx, MaterialPageRoute(builder: (_) => TenantDetailScreen(tenantId: '${t['_id']}')));
                      reload();
                    },
                    child: Row(
                      children: [
                        Avatar(photo: t['photo'] as String?, name: '${t['name']}', size: 50),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${t['name']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              Text('${t['room']}  •  ${t['property']}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: kGrey)),
                              const SizedBox(height: 2),
                              Text('${rupee(t['monthlyRent'])} / month', style: const TextStyle(fontSize: 12, color: kGrey)),
                            ],
                          ),
                        ),
                        n(t['balance']) > 0 ? Pill('Baaki ${rupee(t['balance'])}', kRed) : const Pill('Clear', kGreen),
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
