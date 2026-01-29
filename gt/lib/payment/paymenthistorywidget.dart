import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class PaymentHistoryWidget extends StatefulWidget {
  const PaymentHistoryWidget({super.key});

  @override
  State<PaymentHistoryWidget> createState() => _PaymentHistoryWidgetState();
}

class _PaymentHistoryWidgetState extends State<PaymentHistoryWidget> {
  final _db = FirebaseFirestore.instance;

  static const Color _bgColor = Color(0xFFF6F7F9);
  static const double _headerFooterRatio = 0.08;
  static const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(24, 24, 24, 32);

  bool _loadingPatients = true;
  bool _loadingPayments = false;

  List<_PatientOption> _patientOptions = [];
  String? _selectedPatientId;

  List<Map<String, dynamic>> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  // ======================================================
  // LOAD PATIENTS
  // ======================================================
  Future<void> _loadPatients() async {
    final snap = await _db.collection('patients').orderBy('patientId').get();

    final List<_PatientOption> opts = [];

    for (final doc in snap.docs) {
      final d = doc.data();
      if (d['isActive'] == false) continue;

      final id = (d['patientId'] ?? doc.id).toString();
      final name =
          (d['fullName'] ?? '${d['firstName'] ?? ''} ${d['lastName'] ?? ''}')
              .toString()
              .trim();

      opts.add(_PatientOption(id: id, label: '$id  $name'));
    }

    setState(() {
      _patientOptions = opts;
      _loadingPatients = false;
    });
  }

  // ======================================================
  // LOAD PAYMENTS
  // ======================================================
  Future<void> _loadPayments(String pid) async {
    setState(() {
      _loadingPayments = true;
      _payments.clear();
    });

    final snap = await _db
        .collection('payments')
        .where('patientId', isEqualTo: pid)
        .orderBy('paidAt', descending: true)
        .get();

    setState(() {
      _payments = snap.docs.map((e) => e.data()).toList();
      _loadingPayments = false;
    });
  }

  // ======================================================
  // BUILD
  // ======================================================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: size.height * _headerFooterRatio,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Payment History',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return SingleChildScrollView(
      padding: _bodyPadding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Patient Search',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _loadingPatients
                ? const LinearProgressIndicator()
                : DropdownSearch<_PatientOption>(
                    items: _patientOptions,
                    itemAsString: (e) => e.label,
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: _dec('Select patient'),
                    ),
                    onChanged: (v) {
                      if (v == null) return;
                      _selectedPatientId = v.id;
                      _loadPayments(v.id);
                    },
                  ),
            const SizedBox(height: 24),
            if (_loadingPayments)
              const LinearProgressIndicator()
            else if (_payments.isEmpty)
              const Text('No payment history found')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _payments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _paymentTile(_payments[i]),
              ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // PAYMENT TILE
  // ======================================================
  Widget _paymentTile(Map<String, dynamic> p) {
    final ts = p['paidAt'] as Timestamp?;
    final date = ts?.toDate();

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Payment ID', p['paymentId']),
              _kv(
                  'Paid At',
                  date == null
                      ? '--'
                      : DateFormat('dd-MMM-yyyy hh:mm a').format(date)),
              _kv('Paid Amount', '${p['amount']}'),
              _kv('Payment Details', p['details']),
              _kv('Payment For', p['paymentFor']),
              _kv('Payment Mode', p['paymentMode']),
            ],
          ),
        ),

        // ✏️ EDIT ICON
        Positioned(
          top: 6,
          right: 6,
          child: IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () => _openEditPaymentDialog(p),
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
                width: 140,
                child: Text(k,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            const Text(' : '),
            Expanded(child: Text(v)),
          ],
        ),
      );

  // ======================================================
  // EDIT PAYMENT DIALOG
  // ======================================================
  Future<void> _openEditPaymentDialog(Map<String, dynamic> p) async {
    final amountCtrl = TextEditingController(text: '${p['amount']}');
    final detailsCtrl = TextEditingController(text: p['details']);

    String paymentFor = p['paymentFor'];
    String paymentMode = p['paymentMode'];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) {
            return Dialog(
                backgroundColor: Colors.white,
                surfaceTintColor:
                    Colors.transparent, // 🔥 important (removes lavender)
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420, // 👈 PERFECT cute width
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Edit Payment',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w800)),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _dialogField(
                          controller: amountCtrl,
                          label: 'Paid Amount',
                          keyboardType: TextInputType.number,
                          formatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}'))
                          ],
                        ),
                        const SizedBox(height: 14),
                        _dialogField(
                          controller: detailsCtrl,
                          label: 'Payment Details',
                        ),
                        const SizedBox(height: 14),
                        const Text('Payment For',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Row(
                          children: ['Treatment', 'Medicine']
                              .map(
                                (e) => Expanded(
                                  child: RadioListTile<String>(
                                    value: e,
                                    groupValue: paymentFor,
                                    onChanged: (v) =>
                                        setD(() => paymentFor = v!),
                                    title: Text(e),
                                    dense: true,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        const Text('Payment Mode',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        Row(
                          children: ['Cash', 'UPI']
                              .map(
                                (e) => Expanded(
                                  child: RadioListTile<String>(
                                    value: e,
                                    groupValue: paymentMode,
                                    onChanged: (v) =>
                                        setD(() => paymentMode = v!),
                                    title: Text(e),
                                    dense: true,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 22),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF111827),
                              foregroundColor: Colors.white, // 🔥 THIS
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 26, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              final snap = await _db
                                  .collection('payments')
                                  .where('paymentId', isEqualTo: p['paymentId'])
                                  .limit(1)
                                  .get();

                              if (snap.docs.isEmpty) return;

                              await snap.docs.first.reference.update({
                                'amount': double.parse(amountCtrl.text),
                                'details': detailsCtrl.text.trim(),
                                'paymentFor': paymentFor,
                                'paymentMode': paymentMode,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

                              Navigator.pop(ctx);
                              _loadPayments(_selectedPatientId!);
                            },
                            child: const Text('Done'),
                          ),
                        )
                      ],
                    ),
                  ),
                ));
          },
        );
      },
    );
  }

  InputDecoration _dec(String hint) => InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      );

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ======================================================
class _PatientOption {
  final String id;
  final String label;
  _PatientOption({required this.id, required this.label});
}
