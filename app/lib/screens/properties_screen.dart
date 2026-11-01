import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import 'add_property_screen.dart';
import 'property_detail_screen.dart';

class PropertiesScreen extends StatefulWidget {
  const PropertiesScreen({super.key});

  @override
  State<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> {
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

  Widget _stat(String text, Color c) =>
      Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c));

  Widget _divider() => Container(height: 12, width: 1, margin: const EdgeInsets.symmetric(horizontal: 8), color: kLine);

  @override
  Widget build(BuildContext context) {
    return Loader<List<Map<String, dynamic>>>(
      load: () async => List<Map<String, dynamic>>.from(await Api.get('/properties') as List),
      builder: (ctx, all, reload) {
        final active = all.where((p) => p['archived'] != true).toList();
        final archived = all.where((p) => p['archived'] == true).toList();
        final list = _filter == 'all' ? all : (_filter == 'active' ? active : archived);

        Future<void> add() async {
          final ok = await Navigator.push(ctx, MaterialPageRoute(builder: (_) => const AddPropertyScreen()));
          if (ok == true) reload();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Properties'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Material(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: add,
                    child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.add_rounded, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _chip('All (${all.length})', 'all'),
                    _chip('Active (${active.length})', 'active'),
                    _chip('Archived (${archived.length})', 'archived'),
                  ]),
                ),
                const SizedBox(height: 14),
                if (list.isEmpty)
                  const EmptyBox(Icons.apartment_rounded, 'Koi property nahi hai.\nUpar + button se nayi property add karein.'),
                for (final p in list)
                  SoftCard(
                    padding: EdgeInsets.zero,
                    margin: const EdgeInsets.only(bottom: 14),
                    onTap: () async {
                      await Navigator.push(ctx, MaterialPageRoute(builder: (_) => PropertyDetailScreen(propertyId: '${p['_id']}')));
                      reload();
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                              child: PropertyImage(photo: p['photo'] as String?, height: 150),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: PopupMenuButton<String>(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  child: const Icon(Icons.more_vert_rounded, size: 20),
                                ),
                                onSelected: (v) async {
                                  try {
                                    if (v == 'archive') {
                                      await Api.post('/properties/${p['_id']}/archive', {'archived': p['archived'] != true});
                                      await reload();
                                    } else if (v == 'delete') {
                                      final ok = await confirmDelete(ctx, 'Property delete karein?',
                                          '"${p['name']}" ke saare rooms, tenants, bills aur payments bhi delete ho jayenge.');
                                      if (!ok) return;
                                      await Api.delete('/properties/${p['_id']}');
                                      await reload();
                                    }
                                  } catch (e) {
                                    if (ctx.mounted) toast(ctx, '$e', error: true);
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(value: 'archive', child: Text(p['archived'] == true ? 'Unarchive karein' : 'Archive karein')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete karein', style: TextStyle(color: kRed))),
                                ],
                              ),
                            ),
                            if (p['archived'] == true)
                              const Positioned(top: 10, left: 10, child: Pill('Archived', kAmber)),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${p['name']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                              if ('${p['location'] ?? ''}'.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 14, color: kGrey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text('${p['location']}',
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, color: kGrey)),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _stat('${p['roomCount']} Rooms', kInk),
                                  _divider(),
                                  _stat('${p['occupied']} Occupied', kGreen),
                                  _divider(),
                                  _stat('${p['vacant']} Vacant', kRed),
                                ],
                              ),
                            ],
                          ),
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
