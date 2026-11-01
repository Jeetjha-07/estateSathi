import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../ui_extras.dart';
import '../utils.dart';
import '../widgets.dart';
import 'add_property_screen.dart';
import 'tenant_detail_screen.dart';
import 'tenant_form_screen.dart';

class PropertyDetailScreen extends StatefulWidget {
  final String propertyId;
  const PropertyDetailScreen({super.key, required this.propertyId});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  int _tab = 1; // 0 Overview, 1 Rooms, 2 Tenants, 3 Settings

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: kInk),
        ),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(k, style: const TextStyle(color: kGrey, fontSize: 13))),
            const SizedBox(width: 12),
            Expanded(child: Text(v.isEmpty ? '-' : v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          ],
        ),
      );

  Widget _count(String value, String label, Color c) => Expanded(
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
            Text(label, style: const TextStyle(fontSize: 12, color: kGrey)),
          ],
        ),
      );

  Future<void> _delete(BuildContext ctx, Map property) async {
    final ok = await confirmDelete(ctx, 'Property delete karein?',
        '"${property['name']}" ke saare rooms, tenants, bills aur payments bhi delete ho jayenge.');
    if (!ok) return;
    try {
      await Api.delete('/properties/${widget.propertyId}');
      if (ctx.mounted) Navigator.pop(ctx, true);
    } catch (e) {
      if (ctx.mounted) toast(ctx, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loader<Map<String, dynamic>>(
      standalone: true,
      load: () async => Map<String, dynamic>.from(await Api.get('/properties/${widget.propertyId}/rooms')),
      builder: (ctx, d, reload) {
        final property = Map<String, dynamic>.from(d['property'] as Map);
        final rooms = List<Map<String, dynamic>>.from(d['rooms'] as List);
        final occupiedRooms = rooms.where((r) => r['tenant'] != null).toList();
        final archived = property['archived'] == true;
        final top = MediaQuery.of(ctx).padding.top + 8;

        Future<void> addRoom() async {
          final ok = await Navigator.push(
            ctx,
            MaterialPageRoute(builder: (_) => TenantFormScreen(propertyId: widget.propertyId)),
          );
          if (ok == true) reload();
        }

        Future<void> openRoom(Map<String, dynamic> r) async {
          final t = r['tenant'] as Map?;
          if (t != null) {
            await Navigator.push(ctx, MaterialPageRoute(builder: (_) => TenantDetailScreen(tenantId: '${t['_id']}')));
          } else {
            await Navigator.push(ctx, MaterialPageRoute(builder: (_) => TenantFormScreen(roomId: '${r['_id']}')));
          }
          reload();
        }

        Widget roomsTab() {
          return Column(
            children: [
              SoftCard(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    _count('${rooms.length}', 'Total Rooms', kInk),
                    _count('${occupiedRooms.length}', 'Occupied', kGreen),
                    _count('${rooms.length - occupiedRooms.length}', 'Vacant', kRed),
                  ],
                ),
              ),
              if (rooms.isEmpty) const EmptyBox(Icons.meeting_room_rounded, 'Abhi koi room nahi hai.\nNeeche se "Add Room" dabayein.'),
              for (final r in rooms)
                Builder(builder: (_) {
                  final t = r['tenant'] as Map?;
                  return SoftCard(
                    padding: const EdgeInsets.all(12),
                    onTap: () => openRoom(r),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 58,
                            height: 58,
                            child: t != null && '${t['photo'] ?? ''}'.isNotEmpty
                                ? Avatar(photo: t['photo'] as String?, name: '${t['name']}', size: 58)
                                : Container(
                                    color: kPrimary.withAlpha(18),
                                    child: Icon(t != null ? Icons.person_rounded : Icons.bed_rounded, color: kPrimary),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              Text(
                                t != null ? '${t['name']}' : ('${r['floor'] ?? ''}'.isNotEmpty ? '${r['floor']} • Vacant' : 'Vacant'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, color: kGrey),
                              ),
                              if (t != null)
                                Text('${rupee(t['monthlyRent'])} / month',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            t != null ? const Pill('Occupied', kGreen) : const Pill('Vacant', kRed),
                            if (t != null && n(t['balance']) > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Baaki ${rupee(t['balance'])}',
                                    style: const TextStyle(fontSize: 11, color: kRed, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                        PopupMenuButton<String>(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          icon: const Icon(Icons.more_vert_rounded, size: 20),
                          onSelected: (v) async {
                            if (v != 'delete') return;
                            final ok = await confirmDelete(
                              ctx,
                              'Room delete karein?',
                              t != null
                                  ? '"${r['name']}" aur tenant "${t['name']}" ka poora data (bills, payments) delete ho jayega.'
                                  : '"${r['name']}" delete ho jayega.',
                            );
                            if (!ok) return;
                            try {
                              await Api.delete('/rooms/${r['_id']}');
                              await reload();
                            } catch (e) {
                              if (ctx.mounted) toast(ctx, '$e', error: true);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'delete', child: Text('Room delete karein', style: TextStyle(color: kRed))),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(onPressed: addRoom, icon: const Icon(Icons.add_rounded), label: const Text('Add Room')),
              ),
            ],
          );
        }

        Widget overviewTab() {
          final rent = occupiedRooms.fold<num>(0, (s, r) => s + n((r['tenant'] as Map)['monthlyRent']));
          final pct = rooms.isEmpty ? 0 : (occupiedRooms.length * 100 / rooms.length).round();
          return SoftCard(
            child: Column(
              children: [
                _kv('Property Type', '${property['type'] ?? ''}'),
                _kv('Total Floors', n(property['floors']) > 0 ? fmtNum(property['floors']) : ''),
                _kv('Total Rooms', '${rooms.length}'),
                _kv('Occupancy', '$pct%'),
                _kv('Monthly Rent (total)', rupee(rent)),
                _kv('Location', '${property['location'] ?? ''}'),
                _kv('About', '${property['description'] ?? ''}'),
              ],
            ),
          );
        }

        Widget tenantsTab() {
          if (occupiedRooms.isEmpty) return const EmptyBox(Icons.groups_rounded, 'Is property me abhi koi tenant nahi hai');
          return Column(
            children: [
              for (final r in occupiedRooms)
                Builder(builder: (_) {
                  final t = r['tenant'] as Map;
                  return SoftCard(
                    padding: const EdgeInsets.all(12),
                    onTap: () => openRoom(r),
                    child: Row(
                      children: [
                        Avatar(photo: t['photo'] as String?, name: '${t['name']}', size: 46),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${t['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${r['name']}  •  ${t['phone']}', style: const TextStyle(fontSize: 12, color: kGrey)),
                            ],
                          ),
                        ),
                        n(t['balance']) > 0 ? Pill('Baaki ${rupee(t['balance'])}', kRed) : const Pill('Clear', kGreen),
                      ],
                    ),
                  );
                }),
            ],
          );
        }

        Widget settingsTab() {
          return Column(
            children: [
              SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit_rounded, color: kPrimary),
                      title: const Text('Property details edit karein'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final ok = await Navigator.push(
                          ctx,
                          MaterialPageRoute(builder: (_) => AddPropertyScreen(property: property)),
                        );
                        if (ok == true) reload();
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.inventory_2_rounded, color: kAmber),
                      title: const Text('Archive property'),
                      subtitle: const Text('Archive hone par "Active" list me nahi dikhegi'),
                      value: archived,
                      activeColor: kPrimary,
                      onChanged: (v) async {
                        try {
                          await Api.post('/properties/${widget.propertyId}/archive', {'archived': v});
                          await reload();
                        } catch (e) {
                          if (ctx.mounted) toast(ctx, '$e', error: true);
                        }
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: kRed, side: const BorderSide(color: kRed)),
                  onPressed: () => _delete(ctx, property),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Property delete karein'),
                ),
              ),
            ],
          );
        }

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Stack(
                  children: [
                    GestureDetector(
                      onTap: () => showPhoto(ctx, property['photo'] as String?),
                      child: PropertyImage(photo: property['photo'] as String?, height: 230),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 22,
                        decoration: const BoxDecoration(color: kBg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                      ),
                    ),
                    Positioned(top: top, left: 12, child: _circleBtn(Icons.arrow_back_rounded, () => Navigator.pop(ctx))),
                    Positioned(top: top, right: 12, child: _circleBtn(Icons.refresh_rounded, () => reload())),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('${property['name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                          if (archived) const Pill('Archived', kAmber),
                        ],
                      ),
                      if ('${property['location'] ?? ''}'.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 15, color: kGrey),
                              const SizedBox(width: 4),
                              Expanded(child: Text('${property['location']}', style: const TextStyle(color: kGrey, fontSize: 13))),
                            ],
                          ),
                        )
                      else
                        const SizedBox(height: 14),
                      TabsRow(labels: const ['Overview', 'Rooms', 'Tenants', 'Settings'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
                      if (_tab == 0) overviewTab(),
                      if (_tab == 1) roomsTab(),
                      if (_tab == 2) tenantsTab(),
                      if (_tab == 3) settingsTab(),
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
