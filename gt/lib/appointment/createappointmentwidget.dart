import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateAppointmentWidget extends StatefulWidget {
  final DateTime date;

  const CreateAppointmentWidget({
    super.key,
    required this.date,
  });

  @override
  State<CreateAppointmentWidget> createState() =>
      _CreateAppointmentWidgetState();
}

class _CreateAppointmentWidgetState extends State<CreateAppointmentWidget> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<Set<String>> _loadOccupiedSlots(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final occupied = <String>{};

    // ───── Appointments ─────
    final apptSnap = await _db
        .collection('appointments')
        .where('appointmentDateTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('appointmentDateTime', isLessThan: Timestamp.fromDate(end))
        .get();

    for (final d in apptSnap.docs) {
      final ts = d['appointmentDateTime'];
      if (ts is Timestamp) {
        final dt = ts.toDate();
        occupied.add(
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
        );
      }
    }

    // ───── Doctor Busy ─────
    final busySnap = await _db
        .collection('doctor_unavailability')
        .where('unavailableDateTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('unavailableDateTime', isLessThan: Timestamp.fromDate(end))
        .get();

    for (final d in busySnap.docs) {
      final ts = d['unavailableDateTime'];
      if (ts is Timestamp) {
        final dt = ts.toDate();
        occupied.add(
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
        );
      }
    }

    return occupied;
  }

  // ───────── BASIC STATE ─────────
  String? selectedPatientId;
  TimeOfDay? selectedTime;
  String appointmentType = 'N';
  final TextEditingController notesCtrl = TextEditingController();

  // ───────── PATIENT DROPDOWN ─────────
  bool _loadingPatients = true;
  List<_PatientOption> _patientOptions = [];
  final TextEditingController _createSearchCtrl = TextEditingController();

  // ───────── TIME SLOT CONFIG ─────────
  final int _slotStartHour = 9;
  final int _slotEndHour = 17;
  final int _slotMinutesStep = 30;

  // ───────── VITALS ─────────
  final bpSysCtrl = TextEditingController();
  final bpDiaCtrl = TextEditingController();
  double heartRate = 72;
  double breathingRate = 16;
  final heightCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  final fbsCtrl = TextEditingController();
  final rbsCtrl = TextEditingController();

  // ───────── HEALTH ─────────
  final Map<String, bool> healthConditions = {
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

  bool drugAllergy = false;
  bool foodAllergy = false;
  bool latexAllergy = false;
  final allergyNotesCtrl = TextEditingController();

  final surgeryCtrl = TextEditingController();

  final Map<String, bool> dentalHistory = {
    'Root Canal': false,
    'Implants': false,
    'Crowns / Bridges': false,
    'Braces': false,
    'Dentures': false,
  };
  final dentalNotesCtrl = TextEditingController();

  bool consentGiven = false;
  final consentSignatureCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _createSearchCtrl.dispose();
    super.dispose();
  }

  // ───────────────── LOAD PATIENTS ─────────────────
  Future<void> _loadPatients() async {
    final snap = await _db.collection('patients').orderBy('patientId').get();
    final opts = <_PatientOption>[];

    for (final d in snap.docs) {
      final id = (d['patientId'] ?? d.id).toString();
      final name = (d['fullName'] ?? id).toString();
      opts.add(_PatientOption(id: id, label: '$id  $name'));
    }

    setState(() {
      _patientOptions = opts;
      _loadingPatients = false;
    });
  }

  // ───────────────── TIME SLOTS ─────────────────
  List<TimeOfDay> _generateTimeSlots() {
    final slots = <TimeOfDay>[];
    for (int h = _slotStartHour; h <= _slotEndHour; h++) {
      for (int m = 0; m < 60; m += _slotMinutesStep) {
        slots.add(TimeOfDay(hour: h, minute: m));
      }
    }
    return slots;
  }

  Future<void> _pickTime() async {
    final occupied = await _loadOccupiedSlots(widget.date);
    final slots = _generateTimeSlots();

    final picked = await showDialog<TimeOfDay>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Select time — ${DateFormat('d MMM yyyy').format(widget.date)}',
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slots.map((s) {
              final key = _hhmm(s);
              final taken = occupied.contains(key);

              return SizedBox(
                width: 110,
                child: ElevatedButton(
                  onPressed: taken ? null : () => Navigator.pop(ctx, s),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        taken ? Colors.grey.shade300 : Colors.white,
                    foregroundColor:
                        taken ? Colors.grey.shade600 : Colors.black87,
                    elevation: taken ? 0 : 2,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    s.format(ctx),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  // ───────────────── CREATE ─────────────────
  Future<void> _onCreate() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedPatientId == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select patient & time')),
      );
      return;
    }

    final appointmentDateTime = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    await _db.collection('appointments').add({
      'patientId': selectedPatientId,
      'appointmentDateTime': Timestamp.fromDate(appointmentDateTime),
      'appointmentType': appointmentType,
      'notes': notesCtrl.text.trim(),
      'vitals': {
        'bpSystolic': bpSysCtrl.text,
        'bpDiastolic': bpDiaCtrl.text,
        'heartRate': heartRate,
        'breathingRate': breathingRate,
        'heightCm': heightCtrl.text,
        'weightKg': weightCtrl.text,
        'fbs': fbsCtrl.text,
        'rbs': rbsCtrl.text,
      },
      'healthConditions': healthConditions,
      'allergies': {
        'drug': drugAllergy,
        'food': foodAllergy,
        'latex': latexAllergy,
        'notes': allergyNotesCtrl.text,
      },
      'surgicalHistory': surgeryCtrl.text,
      'dentalHistory': {
        'conditions': dentalHistory,
        'notes': dentalNotesCtrl.text,
      },
      'consent': {
        'given': consentGiven,
        'signatureRef': consentSignatureCtrl.text,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    Navigator.pop(context, true);
  }

  // ───────────────── UI HELPERS ─────────────────
  InputDecoration _input(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  // ───────────────── BUILD ─────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Column(
          children: [
            // ================= HEADER (INVERTED – SAME AS DAY DIALOG) =================
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
              decoration: const BoxDecoration(
                color: Colors.black,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Create Appointment — ${DateFormat('EEEE, d MMM yyyy').format(widget.date)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                    splashRadius: 20,
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _loadingPatients
                          ? const LinearProgressIndicator()
                          : DropdownButtonFormField2<String>(
                              isExpanded: true,
                              value: selectedPatientId,
                              decoration: _input('Select patient'),

                              items: _patientOptions
                                  .map(
                                    (p) => DropdownMenuItem<String>(
                                      value: p.id,
                                      child: _buildPatientOptionRow(p),
                                    ),
                                  )
                                  .toList(),

                              onChanged: (v) {
                                setState(() {
                                  selectedPatientId = v;
                                });
                              },

                              // ===== SAME DROPDOWN LOOK & FEEL =====
                              dropdownStyleData: DropdownStyleData(
                                maxHeight: 280,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
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
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                              ),

                              // ===== SEARCH (IDENTICAL BEHAVIOR) =====
                              dropdownSearchData: DropdownSearchData(
                                searchController: _createSearchCtrl,
                                searchInnerWidgetHeight: 52,
                                searchInnerWidget: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TextField(
                                    controller: _createSearchCtrl,
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
                                if (!isOpen) _createSearchCtrl.clear();
                              },
                            ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _pickTime,
                        child: Text(selectedTime == null
                            ? 'Choose Time'
                            : selectedTime!.format(context)),
                      ),
                      Row(
                        children: [
                          Radio(
                              value: 'N',
                              groupValue: appointmentType,
                              onChanged: (v) =>
                                  setState(() => appointmentType = v!)),
                          const Text('New'),
                          Radio(
                              value: 'F',
                              groupValue: appointmentType,
                              onChanged: (v) =>
                                  setState(() => appointmentType = v!)),
                          const Text('Follow Up'),
                        ],
                      ),
                      _section('Section 1 — Vitals'),
                      _two(bpSysCtrl, 'Systolic', bpDiaCtrl, 'Diastolic'),
                      const SizedBox(height: 12),
                      _slider('Heart Rate', heartRate, 40, 150,
                          (v) => setState(() => heartRate = v)),
                      _slider('Breathing Rate', breathingRate, 10, 40,
                          (v) => setState(() => breathingRate = v)),
                      _three(heightCtrl, 'Height (cm)', weightCtrl,
                          'Weight (kg)', 'BMI'),
                      const SizedBox(height: 12),
                      _two(fbsCtrl, 'FBS', rbsCtrl, 'RBS'),
                      _section('Section 2 — Health Conditions'),
                      _checkboxGrid(healthConditions),
                      _section('Section 3 — Allergies'),
                      CheckboxListTile(
                        value: drugAllergy,
                        onChanged: (v) => setState(() => drugAllergy = v!),
                        title: const Text('Drug Allergy'),
                      ),
                      CheckboxListTile(
                        value: foodAllergy,
                        onChanged: (v) => setState(() => foodAllergy = v!),
                        title: const Text('Food Allergy'),
                      ),
                      CheckboxListTile(
                        value: latexAllergy,
                        onChanged: (v) => setState(() => latexAllergy = v!),
                        title: const Text('Latex Allergy'),
                      ),
                      TextField(
                        controller: allergyNotesCtrl,
                        decoration: _input('Other allergies'),
                      ),
                      _section('Section 4 — Past Surgical History'),
                      TextField(
                        controller: surgeryCtrl,
                        maxLines: 3,
                        decoration: _input('Describe surgeries'),
                      ),
                      _section('Section 6 — Dental History'),
                      _checkboxGrid(dentalHistory),
                      TextField(
                        controller: dentalNotesCtrl,
                        decoration: _input('Dental complications'),
                      ),
                      _section('Section 9 — Patient Consent'),
                      CheckboxListTile(
                        value: consentGiven,
                        onChanged: (v) => setState(() => consentGiven = v!),
                        title: const Text('Patient declaration / consent'),
                      ),
                      TextField(
                        controller: consentSignatureCtrl,
                        decoration: _input('Patient signature / scanned ref'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                          controller: notesCtrl, decoration: _input('Notes')),
                    ],
                  ),
                ),
              ),
            ),
            // ───────────────── FOOTER (8%) ─────────────────
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.08,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 32, // 👈 slight inward offset (less rigid)
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _pillButton(
                      label: 'Save',
                      background: const Color(0xFF111827),
                      foreground: Colors.white,
                      onPressed: _onCreate,
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

  // ───────────────── PILL BUTTON (INK STYLE) ─────────────────
  static Widget _pillButton({
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      splashColor: Colors.black12, // ink splash, not glow
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

  Widget _two(TextEditingController a, String alabel, TextEditingController b,
          String blabel) =>
      Row(children: [
        Expanded(child: TextField(controller: a, decoration: _input(alabel))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: b, decoration: _input(blabel))),
      ]);

  Widget _three(TextEditingController a, String alabel, TextEditingController b,
          String blabel, String c) =>
      Row(children: [
        Expanded(child: TextField(controller: a, decoration: _input(alabel))),
        const SizedBox(width: 12),
        Expanded(child: TextField(controller: b, decoration: _input(blabel))),
        const SizedBox(width: 12),
        Expanded(child: TextField(decoration: _input(c))),
      ]);

  Widget _slider(String label, double value, double min, double max,
          ValueChanged<double> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label — ${value.toInt()}'),
          Slider(value: value, min: min, max: max, onChanged: onChanged),
        ],
      );
  Widget _checkboxGrid(Map<String, bool> items) {
    return Wrap(
      spacing: 24,
      runSpacing: 8,
      children: items.keys.map((k) {
        return SizedBox(
          width: 220,
          child: CheckboxListTile(
            value: items[k],
            onChanged: (v) {
              setState(() {
                items[k] = v ?? false;
              });
            },
            title: Text(k),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
        );
      }).toList(),
    );
  }
}

// ───────── MODEL ─────────
class _PatientOption {
  final String id;
  final String label;
  _PatientOption({required this.id, required this.label});
}
