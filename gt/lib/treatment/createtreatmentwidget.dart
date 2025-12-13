// lib/treatment/createtreatmentwidget.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// CreateTreatmentWidget
///
/// A grouped, sectioned form for entering a treatment/visit record.
/// Fields and layout are based on the uploaded health form (vitals, conditions,
/// allergies, past surgeries, medications, dental history, doctor notes, consent).
class CreateTreatmentWidget extends StatefulWidget {
  const CreateTreatmentWidget({super.key});

  @override
  State<CreateTreatmentWidget> createState() => _CreateTreatmentWidgetState();
}

class _CreateTreatmentWidgetState extends State<CreateTreatmentWidget> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;

  // Basic metadata
  DateTime _selectedDate = DateTime.now();
  final DateFormat _displayDate = DateFormat('yyyy-MM-dd');

  // --- Patient dropdown state (replaces the simple text patientId field) ---
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loadingPatients = true;
  List<_PatientOption> _patientOptions = [];
  String? _selectedPatientId;

  // --------- Vitals ---------
  final TextEditingController _bpSystolicCtrl = TextEditingController();
  final TextEditingController _bpDiastolicCtrl = TextEditingController();
  double _heartRate = 72; // bpm (slider)
  double _breathingRate = 16; // breaths per min (slider)
  final TextEditingController _heightCmCtrl = TextEditingController();
  final TextEditingController _weightKgCtrl = TextEditingController();
  final TextEditingController _bmiCtrl = TextEditingController(); // read-only
  final TextEditingController _fbsCtrl = TextEditingController();
  final TextEditingController _rbsCtrl = TextEditingController();

  // --------- Health Conditions (checkboxes) ---------
  final Map<String, bool> _conditions = {
    'Diabetes': false,
    'Hypertension': false,
    'Heart Disease': false,
    'Asthma': false,
    'Kidney Disease': false,
    'Liver Disease': false,
    'Thyroid Disorder': false,
    'Bleeding Disorders': false,
    'Neurological Issues': false,
  };

  // --------- Allergies ---------
  bool _drugAllergy = false;
  bool _foodAllergy = false;
  bool _latexAllergy = false;
  final TextEditingController _otherAllergiesCtrl = TextEditingController();

  // --------- Past Surgical History ---------
  final TextEditingController _pastSurgeryCtrl = TextEditingController();

  // --------- Medications (dynamic list) ---------
  final List<_MedRow> _meds = [];
  // --------- Problems (NEW Section 7) ---------
  final List<_ProblemRow> _problems = [];

  // --------- Dental History ---------
  final Map<String, bool> _dental = {
    'Root Canal': false,
    'Implants': false,
    'Crowns / Bridges': false,
    'Braces': false,
    'Dentures': false,
  };
  final TextEditingController _dentalComplicationsCtrl =
      TextEditingController();

  // --------- Doctor Notes & Consent ---------
  final TextEditingController _doctorNotesCtrl = TextEditingController();
  bool _patientConsent = false;
  final TextEditingController _patientSignatureCtrl =
      TextEditingController(); // placeholder for signature name

  // Loading state
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _heightCmCtrl.addListener(_recalcBmi);
    _weightKgCtrl.addListener(_recalcBmi);
    _loadPatientsForDropdown();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _bpSystolicCtrl.dispose();
    _bpDiastolicCtrl.dispose();
    _heightCmCtrl.dispose();
    _weightKgCtrl.dispose();
    _bmiCtrl.dispose();
    _fbsCtrl.dispose();
    _rbsCtrl.dispose();
    _otherAllergiesCtrl.dispose();
    _pastSurgeryCtrl.dispose();
    for (final m in _meds) {
      m.dispose();
    }
    _dentalComplicationsCtrl.dispose();
    _doctorNotesCtrl.dispose();
    _patientSignatureCtrl.dispose();
    super.dispose();
  }

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
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF0EA5A4) : Colors.white,
                  border: Border.all(color: Colors.grey),
                ),
                child: Text(
                  number.toString(),
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
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
                    style: const TextStyle(fontWeight: FontWeight.w700)),
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
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    quadrant('Upper Left', [18, 17, 16, 15, 14, 13, 12, 11]),
                    const SizedBox(height: 12),
                    quadrant('Upper Right', [21, 22, 23, 24, 25, 26, 27, 28]),
                    const SizedBox(height: 12),
                    quadrant('Lower Left', [48, 47, 46, 45, 44, 43, 42, 41]),
                    const SizedBox(height: 12),
                    quadrant('Lower Right', [31, 32, 33, 34, 35, 36, 37, 38]),
                    const SizedBox(height: 12),
                    Text('Selected Teeth: ${selectedTeeth.join(', ')}'),
                    const SizedBox(height: 12),
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
                child: const Text('Close'),
              ),
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

  // ---------------------------
  // Patient dropdown: load options
  // ---------------------------
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load patients: $e')));
    }
  }

  void _onPatientSelected(String? val) {
    setState(() {
      _selectedPatientId = val;
    });
  }

  // --------------------------- end patient dropdown ---------------------------

  void _recalcBmi() {
    final hText = _heightCmCtrl.text.trim();
    final wText = _weightKgCtrl.text.trim();
    final h = double.tryParse(hText);
    final w = double.tryParse(wText);
    if (h != null && h > 0 && w != null && w > 0) {
      final hMeters = h / 100.0;
      final bmi = w / (hMeters * hMeters);
      _bmiCtrl.text = bmi.toStringAsFixed(1);
    } else {
      _bmiCtrl.text = '';
    }
  }

  // Add a medication row
  void _addMedication() {
    setState(() {
      _meds.add(_MedRow());
    });
  }

  // Remove med
  void _removeMedication(int idx) {
    setState(() {
      _meds[idx].dispose();
      _meds.removeAt(idx);
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  String? _required(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }

  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPatientId == null || _selectedPatientId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient')),
      );
      return;
    }
    if (!_patientConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Patient consent is required to save the record')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      // Build payload
      final Map<String, dynamic> payload = {
        'patientId': _selectedPatientId!.trim(),
        'treatmentDate': Timestamp.fromDate(DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day)),
        'vitals': {
          'bpSystolic': _toIntOrNull(_bpSystolicCtrl.text),
          'bpDiastolic': _toIntOrNull(_bpDiastolicCtrl.text),
          'heartRate': _heartRate.round(),
          'breathingRate': _breathingRate.round(),
          'heightCm': _toDoubleOrNull(_heightCmCtrl.text),
          'weightKg': _toDoubleOrNull(_weightKgCtrl.text),
          'bmi': _toDoubleOrNull(_bmiCtrl.text),
          'fbs': _toDoubleOrNull(_fbsCtrl.text),
          'rbs': _toDoubleOrNull(_rbsCtrl.text),
        },
        'conditions': {
          for (final e in _conditions.entries) e.key: e.value,
        },
        'allergies': {
          'drug': _drugAllergy,
          'food': _foodAllergy,
          'latex': _latexAllergy,
          'other': _otherAllergiesCtrl.text.trim(),
        },
        'pastSurgery': _pastSurgeryCtrl.text.trim(),
        'medications': [
          for (final m in _meds)
            {
              'name': m.nameCtrl.text.trim(),
              'dose': m.doseCtrl.text.trim(),
              'frequency': m.freqCtrl.text.trim(),
            }
        ],
        'problems': [
          for (final p in _problems)
            {
              'teeth': p.teeth,
              'type': p.type,
              'notes': p.notes,
            }
        ],
        'dentalHistory': {
          for (final e in _dental.entries) e.key: e.value,
          'complications': _dentalComplicationsCtrl.text.trim(),
        },
        'doctorNotes': _doctorNotesCtrl.text.trim(),
        'consent': {
          'patientConsent': _patientConsent,
          'patientSignature': _patientSignatureCtrl.text.trim(),
          'consentAt': FieldValue.serverTimestamp(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save to 'treatments' collection
      await _db.collection('treatments').add(payload);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treatment record created')),
      );

      // Optionally clear form for new entry
      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearForm() {
    setState(() {
      _selectedPatientId = null;
      _bpSystolicCtrl.clear();
      _bpDiastolicCtrl.clear();
      _heartRate = 72;
      _breathingRate = 16;
      _heightCmCtrl.clear();
      _weightKgCtrl.clear();
      _bmiCtrl.clear();
      _fbsCtrl.clear();
      _rbsCtrl.clear();
      _conditions.updateAll((key, value) => false);
      _drugAllergy = false;
      _foodAllergy = false;
      _latexAllergy = false;
      _otherAllergiesCtrl.clear();
      _pastSurgeryCtrl.clear();
      for (final m in _meds) m.dispose();
      _meds.clear();
      _dental.updateAll((key, value) => false);
      _dentalComplicationsCtrl.clear();
      _doctorNotesCtrl.clear();
      _patientConsent = false;
      _patientSignatureCtrl.clear();
      _selectedDate = DateTime.now();
    });
  }

  int? _toIntOrNull(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  double? _toDoubleOrNull(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  InputDecoration _dec(String hint) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Create Treatment',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),

                  // top row: patient dropdown and date
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text("Patient Search",
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827))),
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
                                          value: p.id,
                                          child: _buildPatientOptionRow(p),
                                        ))
                                    .toList(),
                                onChanged: (v) => _onPatientSelected(v),
                                validator: (v) {
                                  if (v == null || v.isEmpty)
                                    return "Please select a patient";
                                  return null;
                                },
                                dropdownStyleData: DropdownStyleData(
                                  maxHeight: 280,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                menuItemStyleData:
                                    const MenuItemStyleData(height: 44),
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
                                                BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                  searchMatchFn: (item, searchValue) {
                                    final value = item.value ?? '';
                                    final opt = _patientOptions.firstWhere(
                                        (p) => p.id == value,
                                        orElse: () => _PatientOption(
                                            id: value, label: value));
                                    return opt.label
                                        .toLowerCase()
                                        .contains(searchValue.toLowerCase());
                                  },
                                ),
                                onMenuStateChange: (isOpen) {
                                  if (!isOpen) _searchCtrl.clear();
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 200,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Date'),
                            OutlinedButton(
                              onPressed: _pickDate,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                backgroundColor: const Color(0xFFF8FAFC),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_displayDate.format(_selectedDate)),
                                  const Icon(Icons.calendar_today, size: 18),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ////////////////////////
                  // Vitals (section)
                  // ////////////////////////
                  _sectionHeader('Section 1 — Vitals (Measurements)'),
                  const SizedBox(height: 8),
                  // BP row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Blood Pressure — Systolic'),
                            TextFormField(
                              controller: _bpSystolicCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3)
                              ],
                              decoration: _dec('e.g. 120'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Blood Pressure — Diastolic'),
                            TextFormField(
                              controller: _bpDiastolicCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3)
                              ],
                              decoration: _dec('e.g. 80'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // heart rate & breathing sliders
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Heart Rate (bpm) — ${_heartRate.round()}'),
                            Slider(
                              value: _heartRate,
                              min: 30,
                              max: 200,
                              divisions: 170,
                              label: '${_heartRate.round()}',
                              onChanged: (v) => setState(() => _heartRate = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 160,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Breathing Rate'),
                            Slider(
                              value: _breathingRate,
                              min: 6,
                              max: 40,
                              divisions: 34,
                              label: '${_breathingRate.round()}',
                              onChanged: (v) =>
                                  setState(() => _breathingRate = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // height / weight / bmi / sugars
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Height (cm)'),
                            TextFormField(
                              controller: _heightCmCtrl,
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}')),
                                LengthLimitingTextInputFormatter(6)
                              ],
                              decoration: _dec('e.g. 170'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Weight (kg)'),
                            TextFormField(
                              controller: _weightKgCtrl,
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}')),
                                LengthLimitingTextInputFormatter(6)
                              ],
                              decoration: _dec('e.g. 72.5'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 140,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('BMI (auto)'),
                            TextFormField(
                              controller: _bmiCtrl,
                              readOnly: true,
                              decoration: _dec('BMI'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('FBS — Fasting Blood Sugar'),
                            TextFormField(
                              controller: _fbsCtrl,
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}'))
                              ],
                              decoration: _dec('mg/dL (optional)'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('RBS — Random Blood Sugar'),
                            TextFormField(
                              controller: _rbsCtrl,
                              keyboardType: TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}'))
                              ],
                              decoration: _dec('mg/dL (optional)'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ////////////////////////
                  // Health Conditions
                  // ////////////////////////
                  _sectionHeader('Section 2 — Health Conditions'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: _conditions.keys.map((k) {
                      return SizedBox(
                        width: 220,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(k),
                          value: _conditions[k],
                          onChanged: (v) =>
                              setState(() => _conditions[k] = v ?? false),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // ////////////////////////
                  // Allergies
                  // ////////////////////////
                  _sectionHeader('Section 3 — Allergies'),
                  Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Drug Allergy'),
                          value: _drugAllergy,
                          onChanged: (v) =>
                              setState(() => _drugAllergy = v ?? false),
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Food Allergy'),
                          value: _foodAllergy,
                          onChanged: (v) =>
                              setState(() => _foodAllergy = v ?? false),
                        ),
                      ),
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Latex Allergy'),
                          value: _latexAllergy,
                          onChanged: (v) =>
                              setState(() => _latexAllergy = v ?? false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _otherAllergiesCtrl,
                    decoration: _dec('Other allergies (describe)'),
                    minLines: 1,
                    maxLines: 3,
                  ),

                  const SizedBox(height: 16),

                  // ////////////////////////
                  // Past Surgical History
                  // ////////////////////////
                  _sectionHeader('Section 4 — Past Surgical History'),
                  TextFormField(
                    controller: _pastSurgeryCtrl,
                    decoration: _dec('Describe past surgeries (if any)'),
                    minLines: 2,
                    maxLines: 4,
                  ),

                  const SizedBox(height: 16),

                  // ////////////////////////
                  // Medications
                  // ////////////////////////
                  _sectionHeader('Section 5 — Medications'),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < _meds.length; i++)
                        Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: TextFormField(
                                    controller: _meds[i].nameCtrl,
                                    decoration: _dec('Medication name'),
                                    validator: (v) {
                                      // allow empty rows? we'll require name if any field present
                                      final any = _meds[i].hasAny();
                                      if (any &&
                                          (v == null || v.trim().isEmpty))
                                        return 'Required';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _meds[i].doseCtrl,
                                    decoration: _dec('Dose'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _meds[i].freqCtrl,
                                    decoration: _dec('Frequency'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 40,
                                  child: IconButton(
                                    onPressed: () => _removeMedication(i),
                                    icon: const Icon(Icons.delete,
                                        color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _addMedication,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Medication'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0EA5A4),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Add prescribed medications (if any)'),
                        ],
                      )
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ////////////////////////
                  // Dental History
                  // ////////////////////////
                  _sectionHeader('Section 6 — Dental History'),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: _dental.keys.map((k) {
                      return SizedBox(
                        width: 220,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(k),
                          value: _dental[k],
                          onChanged: (v) =>
                              setState(() => _dental[k] = v ?? false),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _dentalComplicationsCtrl,
                    decoration:
                        _dec('Dental complications / history (describe)'),
                    minLines: 1,
                    maxLines: 4,
                  ),

                  const SizedBox(height: 16),

// ////////////////////////
// Section 7 — Problems
// ////////////////////////
                  _sectionHeader('Section 7 — Problems'),
                  const SizedBox(height: 8),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < _problems.length; i++)
                        Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text(
                              'Teeth: ${_problems[i].teeth.join(', ')}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${_problems[i].type}\n${_problems[i].notes}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent),
                              onPressed: () {
                                setState(() => _problems.removeAt(i));
                              },
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _openAddProblemDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Problems'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0EA5A4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Add dental problems (if any)'),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ////////////////////////
                  // Doctor Notes
                  // ////////////////////////
                  _sectionHeader('Section 7 — Doctor Notes'),
                  TextFormField(
                    controller: _doctorNotesCtrl,
                    decoration: _dec('Doctor\'s notes (diagnosis, plan)'),
                    minLines: 3,
                    maxLines: 8,
                  ),

                  const SizedBox(height: 16),

                  // ////////////////////////
                  // Patient Consent
                  // ////////////////////////
                  _sectionHeader('Section 8 — Patient Consent'),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Patient declaration / consent'),
                    value: _patientConsent,
                    onChanged: (v) =>
                        setState(() => _patientConsent = v ?? false),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _patientSignatureCtrl,
                          decoration: _dec(
                              'Patient signature / name (or scanned image ref)'),
                          validator: (v) {
                            if (_patientConsent &&
                                (v == null || v.trim().isEmpty)) {
                              return 'Required when consent given';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 140,
                        child: OutlinedButton(
                          onPressed: () {
                            // Placeholder: in a real app you would open a signature pad or file picker.
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Signature capture not implemented here')));
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            backgroundColor: const Color(0xFFF8FAFC),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Capture')
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ACTIONS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _saving ? null : _clearForm,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Reset'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _saving ? null : _onSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Save Treatment',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFF111827))),
      );

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

/// Helper class to keep medication row controllers grouped and disposable.
class _MedRow {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController doseCtrl = TextEditingController();
  final TextEditingController freqCtrl = TextEditingController();

  bool hasAny() {
    return nameCtrl.text.trim().isNotEmpty ||
        doseCtrl.text.trim().isNotEmpty ||
        freqCtrl.text.trim().isNotEmpty;
  }

  void dispose() {
    nameCtrl.dispose();
    doseCtrl.dispose();
    freqCtrl.dispose();
  }
}

class _ProblemRow {
  final List<int> teeth;
  final String type;
  final String notes;

  _ProblemRow({
    required this.teeth,
    required this.type,
    required this.notes,
  });
}

/// Simple option holder (local copy for dropdown)
class _PatientOption {
  final String id;
  final String label;
  _PatientOption({required this.id, required this.label});
}
