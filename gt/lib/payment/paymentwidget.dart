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

  // ------------------------------
  // Layout constants (FROM TEMPLATE)
  // ------------------------------
  static const Color _bgColor = Color(0xFFF6F7F9);
  static const double _headerFooterRatio = 0.08;
  static const EdgeInsets _bodyPadding =
      EdgeInsets.fromLTRB(24, 24, 24, 32);

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
    try {
      final snap = await _db.collection('patients').orderBy('patientId').get();
      final List<_PatientOption> opts = [];
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['isActive'] == false) continue;
        final id = (data['patientId'] ?? doc.id).toString();
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
    } catch (_) {
      setState(() => _loadingPatients = false);
    }
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
        'paidAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Payment recorded')),
      );

      _amountCtrl.clear();
      _detailsCtrl.clear();
      setState(() => _selectedPatientId = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('❌ Failed: $e')));
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
            'Make Payment',
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
  // SCROLLABLE BODY
  // ======================================================
  Widget _buildScrollableBody() {
    return Expanded(
      child: SingleChildScrollView(
        padding: _bodyPadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

                      dropdownStyleData: DropdownStyleData(
                        maxHeight: 280,
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                          thumbVisibility:
                              MaterialStateProperty.all(true),
                        ),
                      ),

                      menuItemStyleData: const MenuItemStyleData(
                        height: 44,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16),
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
                              prefixIcon:
                                  const Icon(Icons.search, size: 18),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(12),
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
                          onChanged: (v) =>
                              setState(() => _paymentFor = v),
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
                          onChanged: (v) =>
                              setState(() => _paymentMode = v),
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
                decoration: _dec('Enter amount'),
                onChanged: (_) => setState(() {}),
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
              label: 'Close',
              background: const Color(0xFFE5E7EB),
              foreground: const Color(0xFF111827),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  Widget _radio({
    required String group,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Expanded(
      child: RadioListTile<String>(
        value: value,
        groupValue: group,
        onChanged: (v) => onChanged(v!),
        title: Text(value),
        dense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _patientRow(_PatientOption p) {
    final parts = p.label.split(RegExp(r'\s{2,}'));
    return Row(
      children: [
        Text(parts.first,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(parts.last,
              overflow: TextOverflow.ellipsis),
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