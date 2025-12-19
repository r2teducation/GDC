import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaymentWidget extends StatefulWidget {
  const PaymentWidget({super.key});

  @override
  State<PaymentWidget> createState() => _PaymentWidgetState();
}

class _PaymentWidgetState extends State<PaymentWidget> {
  final _db = FirebaseFirestore.instance;

  // ✅ ADD THESE (Medicine search)
  final TextEditingController _medicineSearchCtrl = TextEditingController();
  String _medicineSearch = '';

  // ---------------- Patient dropdown ----------------
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loadingPatients = true;
  List<_PatientOption> _patientOptions = [];
  String? _selectedPatientId;

  // ---------------- Payment fields ----------------
  String _paymentFor = 'Treatment'; // Treatment | Medicine
  String _paymentMode = 'Cash'; // Cash | UPI
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _detailsCtrl = TextEditingController();

  bool _saving = false;

  // ---------------- Medicine stock & cart ----------------
  bool _loadingMedicines = false;
  List<Map<String, dynamic>> _medicineStock = [];
  Map<String, int> _selectedQty = {};
  List<Map<String, dynamic>> _medicineCart = [];

  @override
  void initState() {
    super.initState();
    _loadPatients();

    _medicineSearchCtrl.addListener(() {
      setState(() {
        _medicineSearch = _medicineSearchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _medicineSearchCtrl.dispose();
    _amountCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  // ======================================================
  // Load patients
  // ======================================================
  Future<void> _loadPatients() async {
    try {
      final snap = await _db.collection('patients').orderBy('patientId').get();
      final List<_PatientOption> opts = [];
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['isActive'] == false) continue;
        final id = (data['patientId'] ?? doc.id).toString();
        final name =
            (data['fullName'] ?? '${data['firstName']} ${data['lastName']}')
                .toString()
                .trim();
        opts.add(_PatientOption(id: id, label: '$id  $name'));
      }
      setState(() {
        _patientOptions = opts;
        _loadingPatients = false;
      });
    } catch (_) {
      setState(() => _loadingPatients = false);
    }
  }

  // ======================================================
  // Load medicines
  // ======================================================
  Future<void> _loadMedicines() async {
    setState(() => _loadingMedicines = true);

    final snap = await _db.collection('medicines').get();
    _medicineStock = snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'medicineName': data['medicineName'],
        'availableQty': data['quantityPurchased'],
      };
    }).toList();

    setState(() => _loadingMedicines = false);
  }

  bool get _canPay {
    final amt = double.tryParse(_amountCtrl.text) ?? 0;
    return _selectedPatientId != null && amt > 0 && !_saving;
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
        'medicineCart': _paymentFor == 'Medicine' ? _medicineCart : null,
        'paidAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('✅ Payment recorded')));

      _amountCtrl.clear();
      _detailsCtrl.clear();
      _medicineCart.clear();
      _selectedQty.clear();
      setState(() => _selectedPatientId = null);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('❌ Failed: $e')));
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
          constraints: const BoxConstraints(maxWidth: 920),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Make Payment',
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 24),

                // ---------------- Patient dropdown ----------------
                _label('Select Patient'),
                _loadingPatients
                    ? const LinearProgressIndicator()
                    : DropdownButtonFormField2<String>(
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
                        onChanged: (v) =>
                            setState(() => _selectedPatientId = v),

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
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
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
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
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
                              orElse: () =>
                                  _PatientOption(id: value, label: value),
                            );
                            return opt.label
                                .toLowerCase()
                                .contains(searchValue.toLowerCase());
                          },
                        ),

                        onMenuStateChange: (isOpen) {
                          if (!isOpen) _searchCtrl.clear();
                        },
                      ),

                const SizedBox(height: 20),

                _label('Payment For'),
                Row(
                  children: ['Treatment', 'Medicine']
                      .map((e) => _radio(
                            group: _paymentFor,
                            value: e,
                            onChanged: (v) {
                              setState(() => _paymentFor = v);
                              if (v == 'Medicine') _loadMedicines();
                            },
                          ))
                      .toList(),
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

                if (_paymentFor == 'Medicine') ...[
                  _buildMedicineStock(),
                  const SizedBox(height: 20),
                  _buildMedicineCart(),
                ],

                _label('Payment Amount'),
                TextFormField(
                  controller: _amountCtrl,
                  enabled: _paymentFor != 'Medicine',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  decoration: _dec('Enter amount'),
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
                        ? const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)
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
  // Medicine UI
  // ======================================================
  Widget _buildMedicineStock() {
  if (_loadingMedicines) {
    return const LinearProgressIndicator();
  }

  final filtered = _medicineStock.where((m) {
    final name = (m['medicineName'] ?? '').toString().toLowerCase();
    return _medicineSearch.isEmpty || name.contains(_medicineSearch);
  }).toList();

  // Height calculation:
  // Each row ≈ 64px, show max 3 rows
  final double rowHeight = 64;
  final double maxHeight = rowHeight * 3;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('Medicine Stock'),
      const SizedBox(height: 8),

      // 🔍 Search bar
      TextField(
        controller: _medicineSearchCtrl,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, size: 18),
          hintText: 'Search by medicine name',
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),

      const SizedBox(height: 16),

      // 🧾 Table header (NON-SCROLLABLE)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE6E6E6)),
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 40,
              child: Text('S.No', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: Text('Medicine Name',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            SizedBox(
              width: 120,
              child: Text('Availability',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            SizedBox(
              width: 140,
              child: Text('Quantity',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            SizedBox(width: 80),
          ],
        ),
      ),

      const SizedBox(height: 8),

      // 📋 SCROLLABLE ROWS (MAX 3 VISIBLE)
      SizedBox(
        height: filtered.length > 3 ? maxHeight : filtered.length * rowHeight,
        child: Scrollbar(
          thumbVisibility: true,
          radius: const Radius.circular(8),
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final m = filtered[index];
              final id = m['id'];
              final available = m['availableQty'] ?? 0;
              final qty = _selectedQty[id] ?? 0;

              return Container(
                height: rowHeight,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 40, child: Text('${index + 1}')),
                    Expanded(child: Text(m['medicineName'])),
                    SizedBox(width: 120, child: Text('$available')),

                    // ➖ ➕ Quantity
                    SizedBox(
                      width: 140,
                      child: Row(
                        children: [
                          IconButton(
                            icon:
                                const Icon(Icons.remove, size: 18),
                            onPressed: qty > 0
                                ? () => setState(
                                    () => _selectedQty[id] = qty - 1)
                                : null,
                          ),
                          Text('$qty'),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: qty < available
                                ? () => setState(
                                    () => _selectedQty[id] = qty + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),

                    // ➕ Add button
                    SizedBox(
                      width: 80,
                      child: TextButton(
                        onPressed:
                            qty > 0 ? () => _addToCart(m) : null,
                        child: const Text('Add'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}

  void _addToCart(Map<String, dynamic> m) {
    final qty = _selectedQty[m['id']] ?? 0;
    if (qty == 0) return;

    _medicineCart.removeWhere((e) => e['medicineId'] == m['id']);
    _medicineCart.add({
      'medicineId': m['id'],
      'medicineName': m['medicineName'],
      'quantity': qty,
      'price': null,
    });
    setState(() {});
  }

  Widget _buildMedicineCart() {
    if (_medicineCart.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Medicine Cart'),
        ..._medicineCart.map((c) => ListTile(
              title: Text(c['medicineName']),
              subtitle: Text('Qty: ${c['quantity']}'),
              trailing: SizedBox(
                width: 100,
                child: TextField(
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: 'Price'),
                  onChanged: (v) => c['price'] = double.tryParse(v),
                ),
              ),
            )),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _calculateTotal,
            child: const Text('Total'),
          ),
        ),
      ],
    );
  }

  void _calculateTotal() {
    double total = 0;
    for (final c in _medicineCart) {
      if (c['price'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter price for all medicines')));
        return;
      }
      total += c['price'] * c['quantity'];
    }
    _amountCtrl.text = total.toStringAsFixed(2);
  }

  // ======================================================
  // UI helpers
  // ======================================================
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFF374151))),
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  Widget _radio(
      {required String group,
      required String value,
      required ValueChanged<String> onChanged}) {
    return Expanded(
      child: RadioListTile<String>(
        value: value,
        groupValue: group,
        onChanged: (v) => onChanged(v!),
        title: Text(value),
        dense: true,
      ),
    );
  }

  Widget _patientRow(_PatientOption p) {
    final parts = p.label.split(RegExp(r'\s{2,}'));
    return Row(children: [
      Text(parts.first, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(width: 12),
      Expanded(child: Text(parts.last, overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _searchBox() => Padding(
        padding: const EdgeInsets.all(8),
        child: TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Search by ID / Name',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      );
}

// ======================================================
class _PatientOption {
  final String id;
  final String label;
  _PatientOption({required this.id, required this.label});
}
