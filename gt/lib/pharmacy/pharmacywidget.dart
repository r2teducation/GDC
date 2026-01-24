import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gt/homelayout.dart';

class PharmacyWidget extends StatefulWidget {
  const PharmacyWidget({super.key});

  @override
  State<PharmacyWidget> createState() => _PharmacyWidgetState();
}

class _PharmacyWidgetState extends State<PharmacyWidget> {
  final _db = FirebaseFirestore.instance;

  // ------------------------------
  // Layout constants (STANDARD)
  // ------------------------------
  static const Color _bgColor = Color(0xFFF6F7F9);
  static const double _headerFooterRatio = 0.08;
  static const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(24, 24, 24, 32);

  bool _loadingPatients = true;
  List<_PatientOption> _patientOptions = [];
  String? _selectedPatientId;

  // ---------------- Cart ----------------
  bool _loadingCart = false;
  String? _treatmentDocId;
  List<_MedicineCartItem> _cart = [];

  // ---------------- Payment ----------------
  final String _paymentFor = 'Medicine';
  String _paymentMode = 'Cash';
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _detailsCtrl = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  // ======================================================
  // Load patients
  // ======================================================
  Future<void> _loadPatients() async {
    final snap = await _db.collection('patients').orderBy('patientId').get();
    final opts = <_PatientOption>[];

    for (final d in snap.docs) {
      final data = d.data();
      if (data['isActive'] == false) continue;

      final id = (data['patientId'] ?? d.id).toString();
      final name = (data['fullName'] ??
              '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
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
  // Load medicine cart
  // ======================================================
  Future<void> _loadCart(String patientId) async {
    setState(() {
      _loadingCart = true;
      _cart.clear();
      _treatmentDocId = null;
    });

    final snap = await _db
        .collection('treatments')
        .where('patientId', isEqualTo: patientId)
        .where('cartFulfilled', isEqualTo: false)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      setState(() => _loadingCart = false);
      return;
    }

    final doc = snap.docs.first;
    _treatmentDocId = doc.id;

    final List items = doc['prescribedMedicinesCart'] ?? [];

    setState(() {
      _cart = items
          .map((e) => _MedicineCartItem(
                medicineId: e['medicineId'],
                medicineName: e['medicineName'],
                quantity: e['quantity'],
              ))
          .toList();
      _loadingCart = false;
    });
  }

  bool get _canPay {
    final amt = double.tryParse(_amountCtrl.text) ?? 0;
    return _selectedPatientId != null &&
        amt > 0 &&
        _cart.isNotEmpty &&
        !_saving;
  }

  // ======================================================
  // TOTAL
  // ======================================================
  void _calculateTotal() {
    double total = 0;
    for (final c in _cart) {
      total += c.quantity * (c.price ?? 0);
    }
    _amountCtrl.text = total.toStringAsFixed(2);
    setState(() {});
  }

  // ======================================================
  // Save payment
  // ======================================================
  Future<void> _onPay() async {
    if (!_canPay) return;
    setState(() => _saving = true);

    try {
      await _db.collection('payments').add({
        'patientId': _selectedPatientId,
        'paymentFor': _paymentFor,
        'paymentMode': _paymentMode,
        'amount': double.parse(_amountCtrl.text),
        'details': _detailsCtrl.text.trim(),
        'paidAt': FieldValue.serverTimestamp(),
      });

      if (_treatmentDocId != null) {
        await _db.collection('treatments').doc(_treatmentDocId).update({
          'cartFulfilled': true,
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✅ Medicines Amount Received Successfully')),
      );

      _amountCtrl.clear();
      _detailsCtrl.clear();
      setState(() {
        _selectedPatientId = null;
        _cart.clear();
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ======================================================
  // BUILD
  // ======================================================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bgColor.withOpacity(0.98),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(size),
            _buildScrollableBody(),
            _softDivider(),
            _buildFooter(size),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // HEADER
  // ======================================================
  Widget _buildHeader(Size size) {
    return SizedBox(
      height: size.height * _headerFooterRatio,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Pharmacy Payment',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ),
    );
  }

  // ======================================================
  // BODY
  // ======================================================
  Widget _buildScrollableBody() {
    return Expanded(
      child: SingleChildScrollView(
        padding: _bodyPadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Select Patient'),
              _patientDropdown(),
              const SizedBox(height: 20),
              _label('Medicine Cart'),
              _loadingCart ? const LinearProgressIndicator() : _cartTable(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: _calculateTotal,
                  child: const Text('Total'),
                ),
              ),
              const SizedBox(height: 20),
              _label('Payment Mode'),
              Row(
                children: ['Cash', 'UPI']
                    .map((e) => _radio(
                          group: _paymentMode,
                          value: e,
                          onChanged: (v) => setState(() => _paymentMode = v),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              _label('Payment Amount'),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: _dec('Auto calculated'),
              ),
              const SizedBox(height: 16),
              _label('Payment Details'),
              TextFormField(
                controller: _detailsCtrl,
                maxLines: 2,
                decoration: _dec('Txn no / notes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ======================================================
  // FOOTER
  // ======================================================
  Widget _buildFooter(Size size) {
    return SizedBox(
      height: size.height * _headerFooterRatio,
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _pillButton(
              label: 'Pay',
              background: const Color(0xFF111827),
              foreground: Colors.white,
              onPressed: _canPay ? _onPay : () {},
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // HELPERS
  // ======================================================
  static Divider _softDivider() => const Divider(
        height: 1,
        thickness: 0.6,
        color: Color(0xFFEDEFF2),
      );

  static Widget _pillButton({
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      splashColor: Colors.black12,
      highlightColor: Colors.transparent,
      onTap: onPressed,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          t,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );

  InputDecoration _dec(String h) => InputDecoration(
        hintText: h,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      );

  Widget _radio({
    required String group,
    required String value,
    required ValueChanged<String> onChanged,
  }) =>
      Expanded(
        child: RadioListTile(
          value: value,
          groupValue: group,
          onChanged: (v) => onChanged(v!),
          title: Text(value),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      );

  Widget _patientDropdown() {
    if (_loadingPatients) {
      return const LinearProgressIndicator();
    }

    return DropdownSearch<_PatientOption>(
      items: _patientOptions,
      selectedItem: _selectedPatientId == null
          ? null
          : _patientOptions.firstWhere(
              (p) => p.id == _selectedPatientId,
            ),
      itemAsString: (item) => item.label,
      popupProps: PopupProps.menu(
        showSearchBox: true,
        constraints: const BoxConstraints(maxHeight: 280),
        containerBuilder: (context, popupWidget) {
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.zero, // ✅ sharp ERP style
            elevation: 6,
            child: popupWidget,
          );
        },
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            hintText: 'Search by ID / Name',
            prefixIcon: const Icon(Icons.search, size: 18),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: _dec("Select patient"),
      ),
      onChanged: (val) {
        if (val == null) return;

        setState(() => _selectedPatientId = val.id);
        _loadCart(val.id); // 🔥 critical
      },
    );
  }

  Widget _cartTable() {
    if (_cart.isEmpty) {
      return const Text('No pending medicines');
    }

    return Column(
      children: [
        _tableHeader(),
        ..._cart.asMap().entries.map((e) {
          final i = e.key;
          final c = e.value;

          return _tableRow(
            i + 1,
            c,
            () => setState(() => c.quantity--),
            () => setState(() => c.quantity++),
            (v) => setState(() => c.price = double.tryParse(v)),
          );
        }),
      ],
    );
  }

  Widget _tableHeader() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            SizedBox(width: 40, child: Text('S.No')),
            Expanded(child: Text('Medicine Name')),
            SizedBox(width: 140, child: Text('Quantity')),
            SizedBox(width: 120, child: Text('Price')),
          ],
        ),
      );

  Widget _tableRow(
    int sno,
    _MedicineCartItem c,
    VoidCallback dec,
    VoidCallback inc,
    ValueChanged<String> onPrice,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 40, child: Text('$sno')),
          Expanded(child: Text(c.medicineName)),
          SizedBox(
            width: 140,
            child: Row(
              children: [
                IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: c.quantity > 1 ? dec : null),
                Text('${c.quantity}'),
                IconButton(
                    icon: const Icon(Icons.add, size: 18), onPressed: inc),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: TextField(
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              onChanged: onPrice,
              decoration: _dec('₹'),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================
class _MedicineCartItem {
  final String medicineId;
  final String medicineName;
  int quantity;
  double? price;

  _MedicineCartItem({
    required this.medicineId,
    required this.medicineName,
    required this.quantity,
  });
}

class _PatientOption {
  final String id;
  final String label;
  _PatientOption({required this.id, required this.label});
}
