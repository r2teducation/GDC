import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaymentHistoryWidget extends StatefulWidget {
  const PaymentHistoryWidget({super.key});

  @override
  State<PaymentHistoryWidget> createState() => _PaymentHistoryWidgetState();
}

class _PaymentHistoryWidgetState extends State<PaymentHistoryWidget> {
  final _db = FirebaseFirestore.instance;
  final TextEditingController _searchCtrl = TextEditingController();

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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ======================================================
  // Load patients for dropdown
  // ======================================================
  Future<void> _loadPatients() async {
    try {
      final snap = await _db.collection('patients').orderBy('patientId').get();
      final List<_PatientOption> opts = [];
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['isActive'] == false) continue;
        final id = (data['patientId'] ?? doc.id).toString();
        final fullName = (data['fullName'] ??
                '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
            .toString()
            .trim();
        final label = fullName.isNotEmpty ? '$id  $fullName' : id;
        opts.add(_PatientOption(id: id, label: label));
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
  // Load payment history
  // ======================================================
  Future<void> _loadPayments(String patientId) async {
    setState(() {
      _loadingPayments = true;
      _payments = [];
    });

    try {
      final snap = await _db
          .collection('payments')
          .where('patientId', isEqualTo: patientId)
          .orderBy('paidAt', descending: true)
          .get();

      setState(() {
        _payments = snap.docs.map((d) => d.data()).toList();
      });
    } catch (_) {
      _payments = [];
    } finally {
      if (mounted) setState(() => _loadingPayments = false);
    }
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment History',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),

        // ---------------- Patient dropdown ----------------
        if (_loadingPatients)
          const LinearProgressIndicator()
        else
          DropdownButtonFormField2<String>(
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
              if (v != null) _loadPayments(v);
            },

            // 🔥 SAME STYLE AS REFERENCE
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
            menuItemStyleData: const MenuItemStyleData(
              height: 44,
              padding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
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

        const SizedBox(height: 16),

        // ---------------- Payments list ----------------
        if (_loadingPayments)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LinearProgressIndicator(),
          )
        else if (_payments.isEmpty)
          const Text(
            'No payment history found.',
            style: TextStyle(color: Colors.grey),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _payments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _paymentTile(_payments[i]),
          ),
      ],
    );
  }

  // ======================================================
  // Payment tile
  // ======================================================
  Widget _paymentTile(Map<String, dynamic> p) {
    final ts = p['paidAt'] as Timestamp?;
    final date = ts?.toDate();
    final dateStr = date != null
        ? DateFormat('EEEE dd-MMM-yyyy h:mm a').format(date)
        : '--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv('Paid At', dateStr),
          _kv('Paid Amount', p['amount']?.toString() ?? '--'),
          _kv('Payment Details', p['details'] ?? '--'),
          _kv('Payment For', p['paymentFor'] ?? '--'),
          _kv('Payment Mode', p['paymentMode'] ?? '--'),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(k,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600)),
            ),
            const Text(' : '),
            Expanded(child: Text(v)),
          ],
        ),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        isDense: true,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16)),
      );

  Widget _patientRow(_PatientOption p) {
    final parts = p.label.split(RegExp(r'\s{2,}'));
    return Row(
      children: [
        Text(parts.first,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(
                parts.length > 1 ? parts.last : '',
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

// ======================================================
class _PatientOption {
  final String id;
  final String label;
  _PatientOption({required this.id, required this.label});
}