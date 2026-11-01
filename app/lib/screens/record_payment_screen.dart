import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../theme.dart';
import '../ui_extras.dart';
import '../utils.dart';
import '../widgets.dart';

const kPayModes = ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Other'];

class RecordPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> detail;
  const RecordPaymentScreen({super.key, required this.detail});

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  late final TextEditingController _amount;
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  String _mode = kPayModes.first;
  bool _busy = false;

  num get _balance => n(widget.detail['balance']);
  Map get _t => widget.detail['tenant'] as Map;

  /// Sabse purana bill jo abhi poora paid nahi hai
  Map<String, dynamic>? get _billFor {
    final bills = List<Map<String, dynamic>>.from(widget.detail['bills'] as List);
    for (int i = bills.length - 1; i >= 0; i--) {
      if (bills[i]['status'] != 'paid') return bills[i];
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: _balance > 0 ? fmtNum(_balance) : '');
  }

  double get _entered => double.tryParse(_amount.text.trim()) ?? 0;
  num get _remaining => (_balance - _entered) > 0 ? (_balance - _entered) : 0;

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _submit() async {
    if (_entered <= 0) {
      toast(context, 'Sahi amount daalein', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.post('/tenants/${_t['_id']}/payments', {
        'amount': '$_entered',
        'date': apiDate(_date),
        'mode': _mode,
        'note': _note.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        toast(context, '$e', error: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _billFor;
    return Scaffold(
      appBar: AppBar(title: const Text('Record Payment')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          SoftCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bill for', style: TextStyle(color: kGrey, fontSize: 12)),
                      Text(b != null ? fmtMonth(b['billDate']) : '${_t['name']}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      if (b == null) const Text('Koi pending bill nahi', style: TextStyle(color: kGrey, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(rupee(b != null ? b['total'] : _balance), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    if (b != null) StatusPill('${b['status'] ?? 'pending'}') else Pill(_balance > 0 ? 'Pending' : 'Clear', _balance > 0 ? kRed : kGreen),
                  ],
                ),
              ],
            ),
          ),
          if (_balance > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 14, left: 2),
              child: Text('Kul baaki (sab bills milakar): ${rupee(_balance)}', style: const TextStyle(color: kGrey, fontSize: 12.5)),
            ),
          labeled(
            'Payment Amount',
            required: true,
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: '10000', prefixText: '₹ '),
            ),
          ),
          labeled(
            'Payment Date',
            required: true,
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _pick,
              child: InputDecorator(
                decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_month_rounded, size: 20)),
                child: Text(fmtDate(_date)),
              ),
            ),
          ),
          labeled('Payment Mode', dropdownField(_mode, kPayModes, (v) => setState(() => _mode = v ?? _mode))),
          labeled('Notes (Optional)', TextField(controller: _note, decoration: const InputDecoration(hintText: 'Partial payment received'))),
          const SizedBox(height: 2),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Save ho raha hai...' : 'Record Payment')),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: (_remaining > 0 ? kRed : kGreen).withAlpha(20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: (_remaining > 0 ? kRed : kGreen).withAlpha(70)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Remaining Amount',
                      style: TextStyle(color: _remaining > 0 ? kRed : kGreen, fontWeight: FontWeight.w600)),
                ),
                Text(rupee(_remaining), style: TextStyle(color: _remaining > 0 ? kRed : kGreen, fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
