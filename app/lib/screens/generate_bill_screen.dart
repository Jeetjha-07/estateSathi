import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../api.dart';
import '../theme.dart';
import '../ui_extras.dart';
import '../utils.dart';
import '../widgets.dart';
import 'bill_detail_screen.dart';

class GenerateBillScreen extends StatefulWidget {
  final Map<String, dynamic> detail;
  const GenerateBillScreen({super.key, required this.detail});

  @override
  State<GenerateBillScreen> createState() => _GenerateBillScreenState();
}

class _GenerateBillScreenState extends State<GenerateBillScreen> {
  final _reading = TextEditingController();
  DateTime _date = DateTime.now();
  XFile? _photo;
  bool _busy = false;

  Map get _t => widget.detail['tenant'] as Map;
  num get _prev => n(_t['currentReading']);
  num get _rate => n(_t['electricityRate']);
  double? get _newReading => double.tryParse(_reading.text.trim());
  num get _units => (_newReading != null && _newReading! > _prev) ? _newReading! - _prev : 0;
  num get _electricity => _units * _rate;
  num get _total => n(_t['monthlyRent']) + _electricity + n(_t['waterAmount']) + n(_t['garbageAmount']);

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 31)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _submit() async {
    final r = _newReading;
    if (r == null) {
      toast(context, 'Current meter reading daalein', error: true);
      return;
    }
    if (r < _prev) {
      toast(context, 'Reading purani reading (${fmtNum(_prev)}) se kam nahi ho sakti', error: true);
      return;
    }
    if (_photo == null) {
      toast(context, 'Meter reading ki photo lagana zaroori hai', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await Api.multipart(
        'POST',
        '/tenants/${_t['_id']}/bills',
        {'billDate': apiDate(_date), 'newReading': '$r'},
        {'meterPhoto': _photo},
      );
      if (!mounted) return;
      final bill = Map<String, dynamic>.from(res['bill'] as Map);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BillDetailScreen(bill: bill, detail: widget.detail, balance: n(res['balance']))),
      );
    } catch (e) {
      if (mounted) {
        toast(context, '$e', error: true);
        setState(() => _busy = false);
      }
    }
  }

  Widget _line(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: bold ? kInk : kGrey, fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 16 : 13, color: color)),
        ],
      ),
    );
  }

  Widget _readonly(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(color: const Color(0xFFF0EEE6), borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
        child: Text(text, style: const TextStyle(color: kGrey)),
      );

  @override
  Widget build(BuildContext context) {
    final dues = n(widget.detail['balance']);
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Bill')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14, left: 2),
            child: Text('${_t['name']}  •  ${widget.detail['room']?['name'] ?? ''}', style: const TextStyle(color: kGrey)),
          ),
          labeled(
            'Billing Month',
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_month_rounded, size: 20)),
                child: Text(fmtMonth(_date)),
              ),
            ),
          ),
          labeled(
            'Current Meter Reading',
            required: true,
            TextField(
              controller: _reading,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: '1450', suffixText: 'Units'),
            ),
          ),
          labeled('Previous Reading', _readonly('${fmtNum(_prev)} Units')),
          labeled('Units Consumed', _readonly('${fmtNum(_units)} Units')),
          labeled(
            'Meter Reading Photo',
            required: true,
            Align(
              alignment: Alignment.centerLeft,
              child: PhotoBox(
                file: _photo,
                label: 'Add Photo',
                height: 100,
                width: 120,
                onTap: () async {
                  final f = await pickPhoto(context);
                  if (f != null) setState(() => _photo = f);
                },
                onClear: () => setState(() => _photo = null),
              ),
            ),
          ),
          SoftCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bill Calculation', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                _line('Monthly Rent', rupee(_t['monthlyRent'])),
                _line('Electricity (${fmtNum(_units)} × ${rupee(_rate)})', rupee(_electricity)),
                _line('Water Charge (Fixed)', rupee(_t['waterAmount'])),
                _line('Garbage Charge (Fixed)', rupee(_t['garbageAmount'])),
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: kGreen.withAlpha(26), borderRadius: BorderRadius.circular(10)),
                  child: _line('Total Amount', rupee(_total), bold: true, color: kGreen),
                ),
                if (dues > 0) ...[
                  const SizedBox(height: 6),
                  _line('Pichla baaki', rupee(dues), color: kRed),
                  _line('Kul dena hoga', rupee(dues + _total), bold: true, color: kRed),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Bill ban raha hai...' : 'Generate Bill'),
          ),
        ],
      ),
    );
  }
}
