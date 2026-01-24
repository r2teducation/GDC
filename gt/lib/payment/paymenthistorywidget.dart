import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:gt/homelayout.dart';
import 'package:intl/intl.dart';

class PaymentHistoryWidget extends StatefulWidget {
  const PaymentHistoryWidget({super.key});

  @override
  State<PaymentHistoryWidget> createState() => _PaymentHistoryWidgetState();
}

class _PaymentHistoryWidgetState extends State<PaymentHistoryWidget> {
  final _db = FirebaseFirestore.instance;

  // ------------------------------
  // STANDARD TEMPLATE CONSTANTS
  // ------------------------------
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

  @override
  void dispose() {
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
  // Load payments
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
            _buildBody(),
            const SizedBox(height: 10),
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
            'Payment History',
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
  Widget _buildBody() {
    return Expanded(
      child: SingleChildScrollView(
        padding: _bodyPadding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('Patient Search'),
                _loadingPatients
                    ? const LinearProgressIndicator()
                    : DropdownSearch<_PatientOption>(
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
                              borderRadius:
                                  BorderRadius.zero, // ✅ sharp ERP menu
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
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
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
                          _loadPayments(val.id); // 🔥 important
                        },
                      ),
                const SizedBox(height: 24),
                if (_loadingPayments)
                  const LinearProgressIndicator()
                else if (_payments.isEmpty)
                  const Text(
                    'No payment history found.',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _payments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _paymentTile(_payments[i]),
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
  // PAYMENT TILE
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
              width: 140,
              child:
                  Text(k, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Text(' : '),
            Expanded(child: Text(v)),
          ],
        ),
      );

  // ======================================================
  // HELPERS
  // ======================================================
  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        isDense: true,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      );

  Widget _patientRow(_PatientOption p) {
    final parts = p.label.split(RegExp(r'\s{2,}'));
    return Row(
      children: [
        Text(parts.first, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            parts.length > 1 ? parts.last : '',
            overflow: TextOverflow.ellipsis,
          ),
        ),
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
