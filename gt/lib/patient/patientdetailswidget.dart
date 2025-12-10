import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load patients: $e')));
    }
  }

  void _onPatientSelected(String? val) {
    setState(() => _selectedPatientId = val);
    // later you will implement load/details/update/delete
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Container(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: Offset(0, 4))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Patient Details", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                const SizedBox(height: 24),

                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text("Patient Search", style: TextStyle(color: Color(0xFF111827), fontSize: 14, fontWeight: FontWeight.w600)),
                ),

                if (_loadingPatients)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator())
                else
                  DropdownButtonFormField2<String>(
                    isExpanded: true,
                    // now use nullable selected id directly
                    value: _selectedPatientId,
                    decoration: _dec("Select patient"),
                    // only actual patient items — no "New Patient" entry
                    items: _patientOptions
                        .map((p) => DropdownMenuItem<String>(value: p.id, child: _buildPatientOptionRow(p)))
                        .toList(),
                    onChanged: (v) {
                      _onPatientSelected(v);
                    },
                    dropdownStyleData: DropdownStyleData(
                      maxHeight: 280,
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
                    ),
                    menuItemStyleData: const MenuItemStyleData(height: 44, padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      searchMatchFn: (item, searchValue) {
                        final value = item.value ?? '';
                        final opt = _patientOptions.firstWhere((p) => p.id == value, orElse: () => _PatientOption(id: value, label: value));
                        return opt.label.toLowerCase().contains(searchValue.toLowerCase());
                      },
                    ),
                    onMenuStateChange: (isOpen) {
                      if (!isOpen) _searchCtrl.clear();
                    },
                  ),

                const SizedBox(height: 24),

                if (_selectedPatientId != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Selected Patient:", style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(_patientOptions.firstWhere((p) => p.id == _selectedPatientId, orElse: () => _PatientOption(id: _selectedPatientId!, label: _selectedPatientId!)).label),
                      // later you'll add details / edit / delete UI here
                    ],
                  )
                else
                  const Text("No patient selected."),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PatientOption {
  final String id;
  final String label;
  _PatientOption({required this.id, required this.label});
}