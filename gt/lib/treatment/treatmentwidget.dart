import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TreatmentWidget extends StatefulWidget {
  const TreatmentWidget({super.key});

  @override
  State<TreatmentWidget> createState() => _TreatmentWidgetState();
}

class _TreatmentWidgetState extends State<TreatmentWidget> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;

  // ---------------- Date ----------------
  DateTime _selectedDate = DateTime.now();
  final DateFormat _displayDate = DateFormat('yyyy-MM-dd');

  // ---------------- Patient dropdown ----------------
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loadingPatients = true;
  List<_PatientOption> _patientOptions = [];
  String? _selectedPatientId;

  // ---------------- Problems ----------------
  final List<_ProblemRow> _problems = [];

  // ---------------- Doctor Notes ----------------
  final TextEditingController _doctorNotesCtrl = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPatientsForDropdown();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _doctorNotesCtrl.dispose();
    super.dispose();
  }

  // ======================================================
  // Load patients
  // ======================================================
  Future<void> _loadPatientsForDropdown() async {
    setState(() => _loadingPatients = true);
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
    } catch (e) {
      setState(() => _loadingPatients = false);
    }
  }

  void _onPatientSelected(String? v) {
    setState(() => _selectedPatientId = v);
  }

  // ======================================================
  // Date picker
  // ======================================================
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ======================================================
  // Add Problem Dialog (WORKING VERSION)
  // ======================================================
  void _openAddProblemDialog() {
    final Set<int> selectedTeeth = {};
    String? problemType;
    final TextEditingController notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          Widget toothBox(int number) {
            final selected = selectedTeeth.contains(number);
            return InkWell(
              onTap: () {
                setStateDialog(() {
                  selected
                      ? selectedTeeth.remove(number)
                      : selectedTeeth.add(number);
                });
              },
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF0EA5A4) : Colors.white,
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.black,
                  ),
                ),
              ),
            );
          }

          Widget quadrant(String title, List<int> teeth) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 6),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 8,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  physics: const NeverScrollableScrollPhysics(),
                  children: teeth.map(toothBox).toList(),
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Add Problem'),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: quadrant('Upper Left',
                                [18, 17, 16, 15, 14, 13, 12, 11])),
                        const SizedBox(width: 16),
                        Expanded(
                            child: quadrant('Upper Right',
                                [21, 22, 23, 24, 25, 26, 27, 28])),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: quadrant('Lower Left',
                                [48, 47, 46, 45, 44, 43, 42, 41])),
                        const SizedBox(width: 16),
                        Expanded(
                            child: quadrant('Lower Right',
                                [31, 32, 33, 34, 35, 36, 37, 38])),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField2<String>(
                      decoration: _dec('Type of problem'),
                      items: const [
                        'Root Canal',
                        'Implants',
                        'Crowns/Bridges',
                        'Braces',
                        'Dentures'
                      ]
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => problemType = v,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: _dec('Notes'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
              ElevatedButton(
                onPressed: () {
                  if (selectedTeeth.isEmpty || problemType == null) return;
                  setState(() {
                    _problems.add(_ProblemRow(
                      teeth: selectedTeeth.toList()..sort(),
                      type: problemType!,
                      notes: notesCtrl.text.trim(),
                    ));
                  });
                  Navigator.pop(context);
                },
                child: const Text('Add'),
              ),
            ],
          );
        });
      },
    );
  }

  // ======================================================
  // Save
  // ======================================================
  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedPatientId == null || _selectedPatientId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await _db.collection('treatments').add({
        'patientId': _selectedPatientId,
        'treatmentDate': Timestamp.fromDate(_selectedDate),
        'doctorNotes': _doctorNotesCtrl.text.trim(),
        'problems': _problems
            .map((p) => {
                  'teeth': p.teeth,
                  'type': p.type,
                  'notes': p.notes,
                })
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Treatment saved successfully')),
      );

      _clearForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearForm() {
    setState(() {
      _selectedPatientId = null;
      _selectedDate = DateTime.now();
      _doctorNotesCtrl.clear();
      _problems.clear();
    });
  }

  // ======================================================
  // UI helpers
  // ======================================================
  InputDecoration _dec(String hint) => InputDecoration(
        isDense: true,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFF111827))),
      );

  Widget _buildPatientOptionRow(_PatientOption p) {
    final parts = p.label.split(RegExp(r'\s{2,}'));
    return Row(
      children: [
        Text(parts.first, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(parts.length > 1 ? parts.last : '',
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  // ======================================================
  // Build
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Treatment',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),

          const SizedBox(height: 16),

          // Patient search + date
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField2<String>(
                  isExpanded: true,
                  value: _selectedPatientId,
                  decoration: _dec("Select patient"),
                  items: _patientOptions
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p.id,
                          child: _buildPatientOptionRow(p),
                        ),
                      )
                      .toList(),
                  onChanged: _onPatientSelected,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return "Please select a patient";
                    }
                    return null;
                  },

                  // ✅ THIS MAKES THE DROPDOWN LOOK CLEAN & CURVED
                  dropdownStyleData: DropdownStyleData(
                    maxHeight: 280,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
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

                  // ✅ COMPACT ROW HEIGHT (VERY IMPORTANT)
                  menuItemStyleData: const MenuItemStyleData(
                    height: 44,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),

                  // ✅ SEARCH BOX INSIDE DROPDOWN
                  dropdownSearchData: DropdownSearchData(
                    searchController: _searchCtrl,
                    searchInnerWidgetHeight: 56,
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
                              horizontal: 12, vertical: 12),
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
                      return opt.label
                          .toLowerCase()
                          .contains(searchValue.toLowerCase());
                    },
                  ),

                  onMenuStateChange: (isOpen) {
                    if (!isOpen) _searchCtrl.clear();
                  },
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _pickDate,
                child: Text(_displayDate.format(_selectedDate)),
              ),
            ],
          ),

          

          _sectionHeader('Chief Complaint'),
          for (int i = 0; i < _problems.length; i++)
            Card(
              child: ListTile(
                title: Text('Teeth: ${_problems[i].teeth.join(', ')}'),
                subtitle: Text('${_problems[i].type}\n${_problems[i].notes}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => _problems.removeAt(i)),
                ),
              ),
            ),
          ElevatedButton.icon(
            onPressed: _openAddProblemDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Problem'),
          ),

          _sectionHeader('Doctor Notes'),
          TextFormField(
            controller: _doctorNotesCtrl,
            maxLines: 5,
            decoration: _dec('Doctor notes'),
          ),

          const SizedBox(height: 24),

          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(onPressed: _clearForm, child: const Text('Reset')),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _saving ? null : _onSave,
              child: const Text('Save Treatment'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      );
}

// ======================================================
class _ProblemRow {
  final List<int> teeth;
  final String type;
  final String notes;

  _ProblemRow({required this.teeth, required this.type, required this.notes});
}

class _PatientOption {
  final String id;
  final String label;
  _PatientOption({required this.id, required this.label});
}
