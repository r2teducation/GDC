import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PharmacyWidget extends StatefulWidget {
  const PharmacyWidget({super.key});

  @override
  State<PharmacyWidget> createState() => _PharmacyWidgetState();
}

class _PharmacyWidgetState extends State<PharmacyWidget> {
  final _db = FirebaseFirestore.instance;

  // ---------------- Patient dropdown ----------------
  final TextEditingController _searchCtrl = TextEditingController();
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
    _searchCtrl.dispose();
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
  // Load medicine cart from treatments
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
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pharmacy Payment',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 24),
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
                const SizedBox(height: 16),
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
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
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
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _canPay ? _onPay : null,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Pay'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ======================================================
  // Widgets
  // ======================================================
  Widget _patientDropdown1() {
    if (_loadingPatients) return const LinearProgressIndicator();

    return DropdownButtonFormField2<String>(
      value: _selectedPatientId,
      decoration: _dec('Select patient'),
      items: _patientOptions
          .map((p) => DropdownMenuItem(value: p.id, child: Text(p.label)))
          .toList(),
      onChanged: (v) {
        setState(() => _selectedPatientId = v);
        if (v != null) _loadCart(v);
      },
      dropdownSearchData: DropdownSearchData(
        searchController: _searchCtrl,
        searchInnerWidgetHeight: 52,
        searchInnerWidget: Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _searchCtrl,
            decoration: _dec('Search'),
          ),
        ),
      ),
      onMenuStateChange: (open) {
        if (!open) _searchCtrl.clear();
      },
    );
  }

  Widget _patientDropdown() {
    if (_loadingPatients) return const LinearProgressIndicator();

    Widget _patientRow(_PatientOption p) {
      final parts = p.label.split(RegExp(r'\s{2,}'));
      return Row(
        children: [
          Text(parts.first,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(child: Text(parts.last, overflow: TextOverflow.ellipsis)),
        ],
      );
    }

    return DropdownButtonFormField2<String>(
      isExpanded: true,
      value: _selectedPatientId,
      decoration: _dec("Select patient"),
      items: _patientOptions
          .map(
            (p) => DropdownMenuItem<String>(
              value: p.id,
              child: _patientRow(p),
            ),
          )
          .toList(),
      onChanged: (v) {
        setState(() => _selectedPatientId = v);
        if (v != null) _loadCart(v);
      },

      // 🔥 MATCHES PatientDetailsWidget LOOK
      dropdownStyleData: DropdownStyleData(
        maxHeight: 280,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        scrollbarTheme: ScrollbarThemeData(
          radius: const Radius.circular(12),
          thickness: MaterialStateProperty.all(4),
          thumbVisibility: MaterialStateProperty.all(true),
        ),
      ),

      // ✅ COMPACT & CLEAN ROWS
      menuItemStyleData: const MenuItemStyleData(
        height: 44,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),

      // 🔍 SEARCH (SAME AS REFERENCE)
      dropdownSearchData: DropdownSearchData(
        searchController: _searchCtrl,
        searchInnerWidgetHeight: 52,
        searchInnerWidget: Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search by ID / Name',
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        searchMatchFn: (item, searchValue) {
          final value = item.value ?? '';
          final opt = _patientOptions.firstWhere(
            (p) => p.id == value,
            orElse: () => _PatientOption(id: value, label: value),
          );
          return opt.label.toLowerCase().contains(searchValue.toLowerCase());
        },
      ),

      onMenuStateChange: (isOpen) {
        if (!isOpen) _searchCtrl.clear();
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

  // ======================================================
  // UI helpers
  // ======================================================
  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  InputDecoration _dec(String h) => InputDecoration(
        hintText: h,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16)
          ],
        ),
        child: child,
      );

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
