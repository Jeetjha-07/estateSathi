import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../api.dart';
import '../theme.dart';
import '../ui_extras.dart';
import '../utils.dart';
import '../widgets.dart';

class _FamilyRow {
  final name = TextEditingController();
  final relation = TextEditingController();
  final age = TextEditingController();
  void dispose() {
    name.dispose();
    relation.dispose();
    age.dispose();
  }
}

/// Teen tarah se use hota hai:
///  - propertyId do  -> naya room + (optional) tenant
///  - roomId do      -> khaali room me tenant
///  - tenant do      -> tenant edit
class TenantFormScreen extends StatefulWidget {
  final String? propertyId;
  final String? roomId;
  final Map<String, dynamic>? tenant;
  const TenantFormScreen(
      {super.key, this.propertyId, this.roomId, this.tenant});

  @override
  State<TenantFormScreen> createState() => _TenantFormScreenState();
}

class _TenantFormScreenState extends State<TenantFormScreen> {
  final _form = GlobalKey<FormState>();
  int _step = 0;
  bool _withTenant = true;
  bool _saving = false;
  String? _createdRoomId;

  final _roomName = TextEditingController();
  String _floor = '1st Floor';
  late final List<String> _floors = [
    'Ground Floor',
    for (int i = 1; i <= 10; i++) '${ordinal(i)} Floor'
  ];

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _aadhar = TextEditingController();
  final _rent = TextEditingController();
  final _water = TextEditingController(text: '0');
  final _garbage = TextEditingController(text: '0');
  final _rate = TextEditingController();
  final _reading = TextEditingController();
  DateTime _entry = DateTime.now();
  XFile? _photo;
  XFile? _meterPhoto;
  String? _existingPhoto;
  final List<_FamilyRow> _family = [];

  bool get _isEdit => widget.tenant != null;
  bool get _newRoom => widget.propertyId != null;
  bool get _hasTenantStep => !_newRoom || _withTenant;

  @override
  void initState() {
    super.initState();
    final t = widget.tenant;
    if (t != null) {
      _name.text = '${t['name']}';
      _phone.text = '${t['phone']}';
      _address.text = '${t['address'] ?? ''}';
      _aadhar.text = '${t['aadhar'] ?? ''}';
      _rent.text = fmtNum(t['monthlyRent']);
      _water.text = fmtNum(t['waterAmount']);
      _garbage.text = fmtNum(t['garbageAmount']);
      _rate.text = fmtNum(t['electricityRate']);
      _reading.text = fmtNum(t['currentReading']);
      _entry = parseD(t['entryDate']);
      _existingPhoto = t['photo'] as String?;
      for (final f in (t['family'] as List? ?? [])) {
        final row = _FamilyRow();
        row.name.text = '${f['name'] ?? ''}';
        row.relation.text = '${f['relation'] ?? ''}';
        row.age.text = '${f['age'] ?? ''}';
        _family.add(row);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _roomName,
      _name,
      _phone,
      _address,
      _aadhar,
      _rent,
      _water,
      _garbage,
      _rate,
      _reading
    ]) {
      c.dispose();
    }
    for (final f in _family) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _entry,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _entry = d);
  }

  Future<void> _next() async {
    if (!_form.currentState!.validate()) return;
    if (_step == 0 && _hasTenantStep) {
      setState(() => _step = 1);
    } else {
      await _save();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      String? roomId = widget.roomId ?? _createdRoomId;
      if (_newRoom && roomId == null) {
        final r = await Api.post('/properties/${widget.propertyId}/rooms',
            {'name': _roomName.text.trim(), 'floor': _floor});
        roomId = '${r['_id']}';
        _createdRoomId = roomId;
      }
      if (_hasTenantStep) {
        String z(TextEditingController c) =>
            c.text.trim().isEmpty ? '0' : c.text.trim();
        final fields = <String, String>{
          'name': _name.text.trim(),
          'phone': _phone.text.trim(),
          'address': _address.text.trim(),
          'aadhar': _aadhar.text.trim(),
          'entryDate': apiDate(_entry),
          'monthlyRent': z(_rent),
          'waterAmount': z(_water),
          'garbageAmount': z(_garbage),
          'electricityRate': z(_rate),
          'currentReading': z(_reading),
          'family': jsonEncode([
            for (final r in _family)
              if (r.name.text.trim().isNotEmpty)
                {
                  'name': r.name.text.trim(),
                  'relation': r.relation.text.trim(),
                  'age': r.age.text.trim()
                }
          ]),
        };
        final files = <String, XFile?>{
          'photo': _photo,
          'meterPhoto': _meterPhoto
        };
        if (_isEdit) {
          await Api.multipart(
              'PUT', '/tenants/${widget.tenant!['_id']}', fields, files);
        } else {
          await Api.multipart('POST', '/rooms/$roomId/tenant', fields, files);
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _text(
    TextEditingController c,
    String label,
    String hint, {
    TextInputType? type,
    bool required = false,
    int maxLines = 1,
    List<TextInputFormatter>? formatters,
    IconData? icon,
    bool optional = false,
  }) {
    return labeled(
      optional ? '$label (Optional)' : label,
      required: required,
      TextFormField(
        controller: c,
        keyboardType: type,
        maxLines: maxLines,
        inputFormatters: formatters,
        textCapitalization: type == null
            ? TextCapitalization.sentences
            : TextCapitalization.none,
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? '$label zaroori hai' : null
            : null,
        decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon, size: 20)),
      ),
    );
  }

  Widget _money(TextEditingController c, String label, String hint,
      {bool required = false, bool optional = false}) {
    return _text(c, label, hint,
        type: const TextInputType.numberWithOptions(decimal: true),
        required: required,
        optional: optional,
        formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]);
  }

  List<Widget> _stepOne() {
    return [
      if (_newRoom) ...[
        const SectionTitle('Room Details'),
        _text(_roomName, 'Room Number / Name', 'Room 101', required: true),
        labeled(
            'Floor',
            required: true,
            dropdownField(
                _floor, _floors, (v) => setState(() => _floor = v ?? _floor))),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: kPrimary,
          title: const Text('Tenant abhi add karein',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: const Text('Band karne par sirf khaali room banega'),
          value: _withTenant,
          onChanged: (v) => setState(() => _withTenant = v),
        ),
      ],
      if (_hasTenantStep) ...[
        const SectionTitle('Tenant Details'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 84,
              child: PhotoBox(
                file: _photo,
                existing: _existingPhoto,
                label: 'Add Photo',
                height: 84,
                width: 84,
                onTap: () async {
                  final f = await pickPhoto(context);
                  if (f != null) setState(() => _photo = f);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  _text(_name, 'Full Name', 'Tenant ka naam', required: true),
                  _text(_phone, 'Phone Number', '9876543210',
                      type: TextInputType.phone,
                      required: true,
                      formatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))
                      ]),
                ],
              ),
            ),
          ],
        ),
        _text(_address, 'Address', 'Ghar ka pata', maxLines: 2, required: true),
        _text(_aadhar, 'Aadhar Number', '1234 5678 9012',
            type: TextInputType.number,
          optional: true,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12)
            ]),
        labeled(
          'Entry Date',
          required: true,
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.calendar_month_rounded, size: 20)),
              child: Text(fmtDate(_entry)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('Har mahine ${ordinal(_entry.day)} ko rent due hoga',
              style: const TextStyle(fontSize: 12, color: kGrey)),
        ),
      ],
    ];
  }

  List<Widget> _stepTwo() {
    return [
      const SectionTitle('Rent & Utilities'),
      _money(_rent, 'Monthly Rent (₹)', '12000', required: true),
      _money(_water, 'Water Charge - Fixed (₹)', '500', optional: true),
      _money(_garbage, 'Garbage Charge - Fixed (₹)', '200', optional: true),
      _money(_rate, 'Electricity Rate per Unit (₹)', '8', required: true),
      _money(_reading, 'Current Meter Reading (Units)', '1320', required: true),
      if (!_isEdit)
        labeled(
          'Meter Photo (Optional)',
          Align(
            alignment: Alignment.centerLeft,
            child: PhotoBox(
              file: _meterPhoto,
              label: 'Add Photo',
              height: 90,
              width: 110,
              onTap: () async {
                final f = await pickPhoto(context);
                if (f != null) setState(() => _meterPhoto = f);
              },
              onClear: () => setState(() => _meterPhoto = null),
            ),
          ),
        ),
      SectionTitle('Family Members (Optional)',
          trailing: TextButton.icon(
            onPressed: () => setState(() => _family.add(_FamilyRow())),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
          )),
      if (_family.isEmpty)
        const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Koi member add nahi kiya',
                style: TextStyle(color: kGrey, fontSize: 13))),
      for (int i = 0; i < _family.length; i++)
        SoftCard(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Text('Member ${i + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: kRed),
                    onPressed: () =>
                        setState(() => _family.removeAt(i).dispose()),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  children: [
                    TextField(
                        controller: _family[i].name,
                        decoration: const InputDecoration(hintText: 'Naam')),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                            flex: 3,
                            child: TextField(
                                controller: _family[i].relation,
                                decoration:
                                    const InputDecoration(hintText: 'Rishta'))),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _family[i].age,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: 'Umar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit
        ? 'Edit Tenant'
        : (_newRoom ? 'Add Room & Tenant' : 'Add Tenant');
    final lastStep = _step == 1 || !_hasTenantStep;
    final btnText = _saving
        ? 'Save ho raha hai...'
        : (!lastStep
            ? 'Next: Rent & Utilities'
            : (_hasTenantStep
                ? (_isEdit ? 'Update Tenant' : 'Save Tenant')
                : 'Save Room'));
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step = 0);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (_step == 1) {
                setState(() => _step = 0);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            if (_hasTenantStep)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                    child: Text('Step ${_step + 1}/2',
                        style: const TextStyle(color: kGrey, fontSize: 13))),
              ),
          ],
        ),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              ..._step == 0 ? _stepOne() : _stepTwo(),
              const SizedBox(height: 8),
              FilledButton(
                  onPressed: _saving ? null : _next, child: Text(btnText)),
            ],
          ),
        ),
      ),
    );
  }
}
