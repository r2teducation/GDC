import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gt/patient/patienteditwidget.dart';

class PatientDetailsWidget extends StatefulWidget {
  const PatientDetailsWidget({super.key});

  @override
  State<PatientDetailsWidget> createState() => _PatientDetailsWidgetState();
}

class _PatientDetailsWidgetState extends State<PatientDetailsWidget> {
  final _db = FirebaseFirestore.instance;

  bool _loadingPatients = true;
  List<_PatientOption> _patientOptions = [];
  String? _selectedPatientId;

  // loaded patient details
  Map<String, dynamic>? _patientData;
  bool _loadingDetails = false;

  @override
  void initState() {
    super.initState();
    _loadPatientsForDropdown();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadPatientsForDropdown() async {
    setState(() {
      _patientOptions = [];
    });
    try {
      final snap = await _db.collection('patients').orderBy('patientId').get();
      final List<_PatientOption> opts = [];
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['isActive'] == false) continue;
        final id = (data['patientId'] ?? doc.id).toString();
        final firstName = data['firstName'] ?? '';
        final lastName = data['lastName'] ?? '';

        final fullName = lastName.isEmpty ? firstName : '$firstName $lastName';
        final label = '$id  $fullName';
        opts.add(_PatientOption(id: id, label: label));
      }
      setState(() {
        _patientOptions = opts;
        _loadingPatients = false;
      });
    } catch (e) {
      setState(() => _loadingPatients = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load patients: $e')));
    }
  }

  void _onPatientSelected(String? val) {
    setState(() {
      _selectedPatientId = val;
      _patientData = null;
    });
    if (val != null) _loadPatientDetails(val);
  }

  Future<void> _loadPatientDetails(String patientId) async {
    setState(() {
      _loadingDetails = true;
      _patientData = null;
    });
    try {
      final doc = await _db.collection('patients').doc(patientId).get();
      if (!doc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Patient record not found')));
        setState(() {
          _patientData = null;
        });
        return;
      }
      final data = doc.data()!;
      setState(() {
        _patientData = data;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load details: $e')));
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  Widget _row(String label, String? value, {String? doctorName}) {
    String displayValue = value ?? '--';

    // ✅ NORMALIZED LABEL CHECK
    final normalizedLabel = label.toLowerCase().replaceAll(':', '').trim();

    if (normalizedLabel == 'referred by') {
      final referredText = _decodeReferredBy(value);

      if (value == 'D' && (doctorName ?? '').trim().isNotEmpty) {
        displayValue = '$referredText (${doctorName!.trim()})';
      } else {
        displayValue = referredText;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------
  // UI helpers
  // -----------------------
  Widget _buildDetailsCard() {
    if (_loadingDetails) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: LinearProgressIndicator(),
      );
    }
    if (_patientData == null) {
      return const Text("No patient selected.");
    }

    final id = (_patientData!['patientId'] ?? _selectedPatientId) ?? '';
    final firstName = (_patientData!['firstName'] ?? '');
    final lastName = (_patientData!['lastName'] ?? '');
    final gender = (_patientData!['gender'] ?? '');
    final age = (_patientData!['age']?.toString() ?? '');
    final mobile = (_patientData!['mobile'] ?? '');
    final referredBy = (_patientData!['referredBy'] ?? '');
    final doctorName = (_patientData!['doctorName'] ?? '').toString().trim();
    final consultationFee = _patientData!['consultationFee'];
    final address = (_patientData!['address'] ?? '');

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _row("Patient ID :", id),
            _row("First Name :", firstName),
            _row("Last Name :", lastName),
            _row("Gender :", gender),
            _row("Age :", age),
            _row("Mobile Number :", mobile),
            _row("Referred By :", referredBy, doctorName: doctorName),
            _row("Consultation Fee :", _formatConsultationFee(consultationFee)),
            _row("Address :", address),
            const SizedBox(height: 8),
          ],
        ),
      ],
    );
  }

  InputDecoration _dec(String hint) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  String _formatConsultationFee(dynamic value) {
    final amount = (value as num?)?.toDouble() ?? 0.0;

    if (amount == 0.0) return 'Free';

    return amount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Column(
          children: [
            // ============== HEADER ==============
            SizedBox(
              height: size.height * 0.08,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Patient Details",
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            ),

            // ============== BODY (SCROLLABLE) ==============
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildView(),
                  ],
                ),
              ),
            ),

            // ============== SOFT DIVIDER ==============
            const Divider(
              height: 1,
              thickness: 0.6,
              color: Color(0xFFEDEFF2),
            ),

            // ============== FOOTER (8%) ==============
            SizedBox(
              height: size.height * 0.08,
              child: Padding(
                padding: const EdgeInsets.only(left: 24, right: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () async {
                        if (_selectedPatientId == null) return;

                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PatientEditWidget(
                              patientId: _selectedPatientId!,
                            ),
                          ),
                        );

                        if (updated == true) {
                          await _loadPatientsForDropdown(); // 🔥 refresh names
                          await _loadPatientDetails(_selectedPatientId!);
                        }
                      },
                      borderRadius: BorderRadius.circular(999),
                      splashColor: Colors.black12,
                      highlightColor: Colors.transparent,
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 26),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Edit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _decodeReferredBy(String? code) {
    switch (code) {
      case 'D':
        return 'Doctor';
      case 'P':
        return 'Patient';
      case 'O':
        return 'Online';
      case 'S':
        return 'Self';
      case 'X':
        return 'Other';
      default:
        return '--';
    }
  }

  Widget _buildView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text("Patient Search",
              style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ),
        if (_loadingPatients)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator())
        else
          DropdownSearch<_PatientOption>(
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
                  borderRadius: BorderRadius.zero,
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
              _onPatientSelected(val.id);
            },
          ),
        const SizedBox(height: 24),
        _buildDetailsCard(),
      ],
    );
  }
}

/// Simple option holder
class _PatientOption {
  final String id;
  final String label;
  _PatientOption({required this.id, required this.label});
}

/// Shared helpers (copy into same file or keep external)
class MobileNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(' ', '');
    if (digits.length > 10) digits = digits.substring(0, 10);
    String formatted = '';
    for (int i = 0; i < digits.length; i++) {
      formatted += digits[i];
      if (i == 4 && digits.length > 5) formatted += ' ';
    }
    return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length));
  }
}

class SingleSpaceNameFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    if (text.startsWith(' ')) text = text.trimLeft();
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
