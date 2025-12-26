import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gt/patient/patienteditwidget.dart';

class PatientDetailsWidget extends StatefulWidget {
  const PatientDetailsWidget({super.key});

  @override
  State<PatientDetailsWidget> createState() => _PatientDetailsWidgetState();
}

class _PatientDetailsWidgetState extends State<PatientDetailsWidget> {
  final TextEditingController _searchCtrl = TextEditingController();
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
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPatientsForDropdown() async {
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
        final label = fullName.isNotEmpty ? '$id  $fullName' : id.toString();
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

  /// Build each row label: value
  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label",
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Color(0xFF374151)),
            ),
          ),
          Expanded(
            child:
                Text(value, style: const TextStyle(color: Color(0xFF111827))),
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
            _row("Referred By :", referredBy),
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
          DropdownButtonFormField2<String>(
            isExpanded: true,
            value: _selectedPatientId,
            decoration: _dec("Select patient"),
            items: _patientOptions
                .map((p) => DropdownMenuItem<String>(
                    value: p.id, child: _buildPatientOptionRow(p)))
                .toList(),
            onChanged: (v) {
              _onPatientSelected(v);
            },
            dropdownStyleData: DropdownStyleData(
              maxHeight: 280,
              decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16)),
            ),
            menuItemStyleData: const MenuItemStyleData(
                height: 44,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
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
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              searchMatchFn: (item, searchValue) {
                final value = item.value ?? '';
                final opt = _patientOptions.firstWhere((p) => p.id == value,
                    orElse: () => _PatientOption(id: value, label: value));
                return opt.label
                    .toLowerCase()
                    .contains(searchValue.toLowerCase());
              },
            ),
            onMenuStateChange: (isOpen) {
              if (!isOpen) _searchCtrl.clear();
            },
          ),
        const SizedBox(height: 24),
        _buildDetailsCard(),
      ],
    );
  }

  Widget _buildPatientOptionRow(_PatientOption p) {
    final parts = p.label.split(RegExp(r'\s{2,}'));
    final idPart = parts.isNotEmpty ? parts.first : p.id;
    final namePart = parts.length > 1 ? parts.sublist(1).join('  ') : '';
    return Row(
      children: [
        Text(idPart, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(child: Text(namePart, overflow: TextOverflow.ellipsis)),
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
