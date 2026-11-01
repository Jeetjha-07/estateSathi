import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../api.dart';
import '../theme.dart';
import '../ui_extras.dart';
import '../utils.dart';
import '../widgets.dart';

const kPropertyTypes = ['Residential Building', 'Independent House', 'PG / Hostel', 'Commercial', 'Shop / Office', 'Other'];

class AddPropertyScreen extends StatefulWidget {
  final Map<String, dynamic>? property; // edit mode
  const AddPropertyScreen({super.key, this.property});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _floors = TextEditingController();
  final _desc = TextEditingController();
  String _type = kPropertyTypes.first;
  XFile? _photo;
  String? _existingPhoto;
  bool _locating = false;
  bool _saving = false;

  bool get _isEdit => widget.property != null;

  @override
  void initState() {
    super.initState();
    final p = widget.property;
    if (p != null) {
      _name.text = '${p['name']}';
      _location.text = '${p['location'] ?? ''}';
      _floors.text = n(p['floors']) > 0 ? fmtNum(p['floors']) : '';
      _desc.text = '${p['description'] ?? ''}';
      _type = '${p['type'] ?? ''}'.isEmpty ? kPropertyTypes.first : '${p['type']}';
      _existingPhoto = p['photo'] as String?;
    }
  }

  Future<void> _autoFill() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw 'Phone ki Location (GPS) on karein';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Location ki permission nahi mili';
      }
      final pos = await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 25));
      String address = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      String suggestedName = '';
      try {
        final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (marks.isNotEmpty) {
          final m = marks.first;
          final parts = <String>[];
          for (final s in [m.street, m.subLocality, m.locality, m.administrativeArea, m.postalCode]) {
            final v = (s ?? '').trim();
            if (v.isNotEmpty && !parts.contains(v)) parts.add(v);
          }
          if (parts.isNotEmpty) address = parts.join(', ');
          suggestedName = (m.name ?? '').trim();
          if (suggestedName.isEmpty) suggestedName = (m.subLocality ?? '').trim();
        }
      } catch (_) {
        // address nahi mila to coordinates hi rakh lete hain
      }
      _location.text = address;
      if (_name.text.trim().isEmpty && suggestedName.isNotEmpty) _name.text = suggestedName;
      if (mounted) toast(context, 'Location bhar di gayi, chaho to edit kar lein');
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      toast(context, 'Property ka naam likhein', error: true);
      return;
    }
    if (_location.text.trim().isEmpty) {
      toast(context, 'Location likhein ya current location use karein', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final fields = {
        'name': _name.text.trim(),
        'location': _location.text.trim(),
        'type': _type,
        'floors': _floors.text.trim().isEmpty ? '0' : _floors.text.trim(),
        'description': _desc.text.trim(),
      };
      if (_isEdit) {
        await Api.multipart('PUT', '/properties/${widget.property!['_id']}', fields, {'photo': _photo});
      } else {
        await Api.multipart('POST', '/properties', fields, {'photo': _photo});
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Property' : 'Add Property')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          PhotoBox(
            file: _photo,
            existing: _existingPhoto,
            label: 'Add Property Photo (Optional)',
            height: 130,
            onTap: () async {
              final f = await pickPhoto(context);
              if (f != null) setState(() => _photo = f);
            },
            onClear: () => setState(() => _photo = null),
          ),
          const SizedBox(height: 18),
          labeled('Property Name', required: true,
              TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Sharma Residency'))),
          labeled('Location', required: true,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _location,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: 'Area, City', suffixIcon: Icon(Icons.location_on_rounded, color: kPrimary)),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _locating ? null : _autoFill,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _locating
                            ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.my_location_rounded, size: 15, color: kBlue),
                        const SizedBox(width: 6),
                        Text(_locating ? 'Location dhundh rahe hain...' : 'Use My Current Location',
                            style: const TextStyle(color: kBlue, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              )),
          labeled('Property Type', dropdownField(_type, kPropertyTypes, (v) => setState(() => _type = v ?? _type))),
          labeled('Total Floors',
              TextField(controller: _floors, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '3'))),
          labeled('Description (Optional)',
              TextField(controller: _desc, minLines: 3, maxLines: 5, decoration: const InputDecoration(hintText: '3 floor building with 12 rooms'))),
          const SizedBox(height: 6),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Save ho raha hai...' : (_isEdit ? 'Update Property' : 'Create Property')),
          ),
        ],
      ),
    );
  }
}
