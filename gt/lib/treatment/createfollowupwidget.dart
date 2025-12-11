// lib/treatment/createfollowupwidget.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// CreateFollowUpWidget
///
/// Implements the follow-up form described in the provided requirements.
/// Auto-fills patient identity, last visit summary, critical alerts & last vitals.
/// Doctor can enter today's symptoms, assessment, treatment plan, next appointment,
/// and sign-off. Saves to Firestore 'followups' collection.
class CreateFollowUpWidget extends StatefulWidget {
  const CreateFollowUpWidget({super.key});

  @override
  State<CreateFollowUpWidget> createState() => _CreateFollowUpWidgetState();
}

class _CreateFollowUpWidgetState extends State<CreateFollowUpWidget> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;

  // --- patient search & identity
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _patientIdCtrl = TextEditingController();
  final TextEditingController _patientNameCtrl = TextEditingController();
  final TextEditingController _patientAgeCtrl = TextEditingController();
  final TextEditingController _patientGenderCtrl = TextEditingController();

  bool _searching = false;
  List<_PatientOption> _patientOptions = [];
  bool _loadingPatientsDropdown = true;

  // --- date selector (copied from CreateTreatmentWidget)
  DateTime _selectedDate = DateTime.now();
  final DateFormat _displayDate = DateFormat('yyyy-MM-dd');

  // --- last visit summary (auto-filled)
  final TextEditingController _lastVisitDateCtrl = TextEditingController();
  final TextEditingController _lastDiagnosisCtrl = TextEditingController();
  final TextEditingController _lastProcedureCtrl = TextEditingController();
  final TextEditingController _lastDoctorNotesCtrl = TextEditingController();

  // --- critical medical alerts (read-only checkboxes)
  bool _allergyFlag = false;
  bool _diabetesFlag = false;
  bool _hypertensionFlag = false;
  bool _heartFlag = false;
  bool _thyroidFlag = false;
  bool _bleedingFlag = false;

  // --- last recorded vitals (read-only)
  final TextEditingController _lastBpSysCtrl = TextEditingController();
  final TextEditingController _lastBpDiaCtrl = TextEditingController();
  final TextEditingController _lastHeartRateCtrl = TextEditingController();
  final TextEditingController _lastSugarCtrl = TextEditingController();
  final TextEditingController _lastWeightCtrl = TextEditingController();
  final TextEditingController _lastBmiCtrl = TextEditingController();

  // --- medication status (read-only multi-line)
  final TextEditingController _currentMedsCtrl = TextEditingController();
  final TextEditingController _lastPrescribedCtrl = TextEditingController();

  // --- dental history (read-only checkboxes & complications)
  bool _dhRootCanal = false;
  bool _dhImplants = false;
  bool _dhCrowns = false;
  bool _dhBraces = false;
  bool _dhDentures = false;
  final TextEditingController _dentalComplicationsCtrl =
      TextEditingController();

  // --- Today's Symptoms (inputs)
  String _painLevel = 'None'; // None / Mild / Moderate / Severe
  bool _symSwelling = false;
  bool _symSensitivity = false;
  final TextEditingController _newComplaintsCtrl = TextEditingController();

  // --- Doctor's Assessment (inputs)
  final TextEditingController _clinicalNotesCtrl = TextEditingController();
  final TextEditingController _diagnosisCtrl = TextEditingController();

  // --- Treatment Plan (inputs)
  final TextEditingController _newMedsPlanCtrl = TextEditingController();
  String? _recommendedProcedure; // dropdown value
  final TextEditingController _instructionsCtrl = TextEditingController();

  // --- Next appointment scheduling
  DateTime? _nextVisitDate;
  TimeOfDay? _nextVisitTime;
  String? _nextVisitPurpose; // e.g., Follow-up / Cleaning / Procedure

  // --- Doctor signature (auto-filled doctor name if available)
  final TextEditingController _doctorNameCtrl = TextEditingController();
  final TextEditingController _signedAtCtrl = TextEditingController();

  // UI state
  bool _saving = false;

  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDateTime = DateFormat('EEEE, d MMM yyyy  h:mm a');

  @override
  void initState() {
    super.initState();
    _loadPatientsDropdown(); // optional prefill for dropdown search
    _signedAtCtrl.text = _displayDateTime.format(DateTime.now());
    // If you have an authenticated doctor name, set it here:
    // _doctorNameCtrl.text = 'Dr. ...';
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _patientIdCtrl.dispose();
    _patientNameCtrl.dispose();
    _patientAgeCtrl.dispose();
    _patientGenderCtrl.dispose();
    _lastVisitDateCtrl.dispose();
    _lastDiagnosisCtrl.dispose();
    _lastProcedureCtrl.dispose();
    _lastDoctorNotesCtrl.dispose();
    _lastBpSysCtrl.dispose();
    _lastBpDiaCtrl.dispose();
    _lastHeartRateCtrl.dispose();
    _lastSugarCtrl.dispose();
    _lastWeightCtrl.dispose();
    _lastBmiCtrl.dispose();
    _currentMedsCtrl.dispose();
    _lastPrescribedCtrl.dispose();
    _dentalComplicationsCtrl.dispose();
    _newComplaintsCtrl.dispose();
    _clinicalNotesCtrl.dispose();
    _diagnosisCtrl.dispose();
    _newMedsPlanCtrl.dispose();
    _instructionsCtrl.dispose();
    _doctorNameCtrl.dispose();
    _signedAtCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPatientsDropdown() async {
    try {
      final snap = await _db
          .collection('patients')
          .orderBy('patientId')
          .limit(200)
          .get();
      final List<_PatientOption> opts = [];
      for (final d in snap.docs) {
        final data = d.data();
        final id = (data['patientId'] ?? d.id).toString();
        final fullName = (data['fullName'] ??
                '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
            .toString()
            .trim();
        opts.add(_PatientOption(
            id: id, label: fullName.isNotEmpty ? '$id  $fullName' : id));
      }
      setState(() {
        _patientOptions = opts;
        _loadingPatientsDropdown = false;
      });
    } catch (e) {
      setState(() => _loadingPatientsDropdown = false);
      debugPrint('Failed to load patient options: $e');
    }
  }

  // Replace your existing _searchAndFillPatient with this
  Future<void> _searchAndFillPatient(String query) async {
    // Search by patientId exact or name/mobile contains
    if (query.trim().isEmpty) return;
    setState(() => _searching = true);

    try {
      // We'll keep a DocumentSnapshot variable that can hold a single-doc fetch
      // or a query result (QueryDocumentSnapshot is a subtype of DocumentSnapshot).
      DocumentSnapshot<Map<String, dynamic>>? foundDoc;

      // 1) Try exact patientId (doc id)
      final docRef = await _db.collection('patients').doc(query.trim()).get();
      if (docRef.exists) {
        foundDoc = docRef;
      }

      // 2) If not found by id, try name range query (if you maintain fullName)
      if (foundDoc == null) {
        final q1 = await _db
            .collection('patients')
            .where('fullName', isGreaterThanOrEqualTo: query)
            .where('fullName', isLessThanOrEqualTo: '$query\uf8ff')
            .limit(1)
            .get();
        if (q1.docs.isNotEmpty) {
          foundDoc = q1.docs.first;
        }
      }

      // 3) Fallback: try mobile exact match
      if (foundDoc == null) {
        final q2 = await _db
            .collection('patients')
            .where('mobile', isEqualTo: query.replaceAll(' ', ''))
            .limit(1)
            .get();
        if (q2.docs.isNotEmpty) {
          foundDoc = q2.docs.first;
        }
      }

      if (foundDoc == null || !foundDoc.exists) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No patient found')));
        return;
      }

      // Pass the DocumentSnapshot to the filler function
      await _fillPatientDetailsFromDoc(foundDoc);
    } catch (e) {
      debugPrint('Patient search failed: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Search failed: $e')));
    } finally {
      setState(() => _searching = false);
    }
  }

  // Replace the signature of _fillPatientDetailsFromDoc to accept DocumentSnapshot
  Future<void> _fillPatientDetailsFromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? <String, dynamic>{};
    final id = (data['patientId'] ?? doc.id).toString();
    final fullName = (data['fullName'] ??
            '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
        .toString()
        .trim();
    final age = (data['age'] ?? '').toString();
    final gender = (data['gender'] ?? '').toString();

    setState(() {
      _patientIdCtrl.text = id;
      _patientNameCtrl.text = fullName;
      _patientAgeCtrl.text = age;
      _patientGenderCtrl.text = gender;
    });

    // Load last visit summary (try treatments first, then appointments)
    await _loadLastVisitSummary(id);

    // Load critical flags from patient doc (if present)
    setState(() {
      _allergyFlag = (data['hasAllergy'] ??
              (data['allergies'] != null &&
                  (data['allergies'] as dynamic).toString().isNotEmpty)) ==
          true;
      _diabetesFlag = data['diabetes'] == true;
      _hypertensionFlag = data['hypertension'] == true;
      _heartFlag = data['heartDisease'] == true;
      _thyroidFlag = data['thyroid'] == true;
      _bleedingFlag = data['bleedingDisorder'] == true;
    });

    // Load last recorded vitals & meds from treatments (if present)
    await _loadLatestVitalsAndMeds(id);

    // Load dental history if available on patient doc
    setState(() {
      _dhRootCanal = (data['dental']?['Root Canal'] ?? false) == true;
      _dhImplants = (data['dental']?['Implants'] ?? false) == true;
      _dhCrowns = (data['dental']?['Crowns / Bridges'] ?? false) == true;
      _dhBraces = (data['dental']?['Braces'] ?? false) == true;
      _dhDentures = (data['dental']?['Dentures'] ?? false) == true;
      _dentalComplicationsCtrl.text =
          (data['dental']?['complications'] ?? '').toString();
    });
  }

  Future<void> _loadLastVisitSummary(String patientId) async {
    try {
      // Check treatments collection for most recent treatment for summary
      final tSnap = await _db
          .collection('treatments')
          .where('patientId', isEqualTo: patientId)
          .orderBy('treatmentDate', descending: true)
          .limit(1)
          .get();

      if (tSnap.docs.isNotEmpty) {
        final d = tSnap.docs.first.data();
        DateTime? dt;
        final ts = d['treatmentDate'] ?? d['date'] ?? d['createdAt'];
        if (ts is Timestamp)
          dt = ts.toDate();
        else if (ts is DateTime) dt = ts;
        _lastVisitDateCtrl.text = dt != null ? _dateFmt.format(dt) : '';
        _lastDiagnosisCtrl.text =
            (d['doctorNotes'] ?? d['summary'] ?? '').toString();
        _lastProcedureCtrl.text =
            (d['procedure'] ?? d['treatment'] ?? '').toString();
        _lastDoctorNotesCtrl.text =
            (d['doctorNotes'] ?? d['notes'] ?? '').toString();
        return;
      }

      // Fallback: fetch latest appointment
      final aSnap = await _db
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .orderBy('appointmentDateTime', descending: true)
          .limit(1)
          .get();
      if (aSnap.docs.isNotEmpty) {
        final d = aSnap.docs.first.data();
        final ts = d['appointmentDateTime'];
        DateTime? dt;
        if (ts is Timestamp)
          dt = ts.toDate();
        else if (ts is DateTime) dt = ts;
        _lastVisitDateCtrl.text = dt != null ? _dateFmt.format(dt) : '';
        _lastDiagnosisCtrl.text = (d['notes'] ?? '').toString();
        _lastProcedureCtrl.text = '';
        _lastDoctorNotesCtrl.text = (d['notes'] ?? '').toString();
      }
    } catch (e) {
      debugPrint('Failed to load last visit summary: $e');
    }
  }

  Future<void> _loadLatestVitalsAndMeds(String patientId) async {
    try {
      final tSnap = await _db
          .collection('treatments')
          .where('patientId', isEqualTo: patientId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (tSnap.docs.isNotEmpty) {
        final d = tSnap.docs.first.data();
        final vit = d['vitals'] as Map<String, dynamic>? ?? {};

        setState(() {
          _lastBpSysCtrl.text = (vit['bpSystolic'] ?? '').toString();
          _lastBpDiaCtrl.text = (vit['bpDiastolic'] ?? '').toString();
          _lastHeartRateCtrl.text = (vit['heartRate'] ?? '').toString();
          _lastSugarCtrl.text = (vit['rbs'] ?? vit['fbs'] ?? '').toString();
          _lastWeightCtrl.text = (vit['weightKg'] ?? '').toString();
          _lastBmiCtrl.text = (vit['bmi'] ?? '').toString();

          final medsList = (d['medications'] as List<dynamic>?) ?? [];
          _currentMedsCtrl.text = medsList.map((m) {
            if (m is Map)
              return '${m['name'] ?? ''} ${m['dose'] ?? ''} ${m['frequency'] ?? ''}'
                  .trim();
            return m.toString();
          }).join('\n');
          _lastPrescribedCtrl.text = (d['medications'] != null &&
                  (d['medications'] as List).isNotEmpty)
              ? (d['medications'].first['name'] ?? '').toString()
              : '';
        });
      }
    } catch (e) {
      debugPrint('Failed to load vitals/meds: $e');
    }
  }

  // Pick next visit date & time
  Future<void> _pickNextVisitDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextVisitDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _nextVisitDate = picked);
    }
  }

  Future<void> _pickNextVisitTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _nextVisitTime ?? TimeOfDay(hour: 10, minute: 0),
    );
    if (t != null) setState(() => _nextVisitTime = t);
  }

  // Date picker for top row (selectedDate)
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
    if (_patientIdCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a patient first')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final Map<String, dynamic> payload = {
        'patientId': _patientIdCtrl.text.trim(),
        'patientName': _patientNameCtrl.text.trim(),
        'treatmentDate': Timestamp.fromDate(DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day)),
        'createdAt': FieldValue.serverTimestamp(),
        'lastVisitSummary': {
          'date': _lastVisitDateCtrl.text.trim(),
          'diagnosis': _lastDiagnosisCtrl.text.trim(),
          'procedure': _lastProcedureCtrl.text.trim(),
          'doctorNotes': _lastDoctorNotesCtrl.text.trim(),
        },
        'criticalAlerts': {
          'allergy': _allergyFlag,
          'diabetes': _diabetesFlag,
          'hypertension': _hypertensionFlag,
          'heartDisease': _heartFlag,
          'thyroid': _thyroidFlag,
          'bleedingDisorder': _bleedingFlag,
        },
        'lastVitals': {
          'bpSystolic': _lastBpSysCtrl.text.trim(),
          'bpDiastolic': _lastBpDiaCtrl.text.trim(),
          'heartRate': _lastHeartRateCtrl.text.trim(),
          'sugar': _lastSugarCtrl.text.trim(),
          'weight': _lastWeightCtrl.text.trim(),
          'bmi': _lastBmiCtrl.text.trim(),
        },
        'currentMedications': _currentMedsCtrl.text.trim(),
        'lastPrescribed': _lastPrescribedCtrl.text.trim(),
        'dentalHistory': {
          'rootCanal': _dhRootCanal,
          'implants': _dhImplants,
          'crowns': _dhCrowns,
          'braces': _dhBraces,
          'dentures': _dhDentures,
          'complications': _dentalComplicationsCtrl.text.trim(),
        },
        'todaySymptoms': {
          'painLevel': _painLevel,
          'swelling': _symSwelling,
          'sensitivity': _symSensitivity,
          'newComplaints': _newComplaintsCtrl.text.trim(),
        },
        'doctorAssessment': {
          'clinicalNotes': _clinicalNotesCtrl.text.trim(),
          'diagnosis': _diagnosisCtrl.text.trim(),
        },
        'treatmentPlan': {
          'newMedications': _newMedsPlanCtrl.text.trim(),
          'recommendedProcedure': _recommendedProcedure ?? '',
          'instructions': _instructionsCtrl.text.trim(),
        },
        'nextAppointment': _nextVisitDate == null
            ? null
            : {
                'date': Timestamp.fromDate(DateTime(_nextVisitDate!.year,
                    _nextVisitDate!.month, _nextVisitDate!.day)),
                'time': _nextVisitTime == null
                    ? null
                    : '${_nextVisitTime!.hour.toString().padLeft(2, '0')}:${_nextVisitTime!.minute.toString().padLeft(2, '0')}',
                'purpose': _nextVisitPurpose ?? '',
              },
        'doctorSignature': {
          'doctorName': _doctorNameCtrl.text.trim(),
          'signedAt': FieldValue.serverTimestamp(),
        },
      };

      await _db.collection('followups').add(payload);

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Follow-up saved')));
      _clearFormAfterSave();
    } catch (e) {
      debugPrint('Failed to save followup: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _clearFormAfterSave() {
    setState(() {
      // keep patient fields for convenience, clear only inputs
      _newComplaintsCtrl.clear();
      _clinicalNotesCtrl.clear();
      _diagnosisCtrl.clear();
      _newMedsPlanCtrl.clear();
      _recommendedProcedure = null;
      _instructionsCtrl.clear();
      _nextVisitDate = null;
      _nextVisitTime = null;
      _nextVisitPurpose = null;
      _doctorNameCtrl.clear();
      _signedAtCtrl.text = _displayDateTime.format(DateTime.now());
    });
  }

  // UI helpers
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

  // Small helper to format TimeOfDay
  String _timeOfDayLabel(TimeOfDay? t) {
    if (t == null) return '';
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final ampm = t.period == DayPeriod.am ? 'AM' : 'PM';
    final min = t.minute.toString().padLeft(2, '0');
    return '$h:$min $ampm';
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
                    const Text('Create Follow-up',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),

                    // --- REPLACED: Patient Search dropdown + Date selector (from CreateTreatmentWidget)
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
                              if (_loadingPatientsDropdown)
                                const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: LinearProgressIndicator())
                              else
                                DropdownButtonFormField2<String>(
                                  isExpanded: true,
                                  value: null,
                                  decoration: _dec("Select patient"),
                                  items: _patientOptions
                                      .map((p) => DropdownMenuItem<String>(
                                            value: p.id,
                                            child: _buildPatientOptionRow(p),
                                          ))
                                      .toList(),
                                  onChanged: (v) async {
                                    if (v != null) {
                                      final doc = await _db
                                          .collection('patients')
                                          .doc(v)
                                          .get();
                                      if (doc.exists) {
                                        await _fillPatientDetailsFromDoc(
                                            doc as DocumentSnapshot<
                                                Map<String, dynamic>>);
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content:
                                                    Text('Patient doc missing')));
                                      }
                                    }
                                  },
                                  dropdownStyleData:
                                      DropdownStyleData(maxHeight: 300),
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
                                          contentPadding: const EdgeInsets.symmetric(
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
                                          orElse: () =>
                                              _PatientOption(id: value, label: value));
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  backgroundColor: const Color(0xFFF8FAFC),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    const SizedBox(height: 14),

                    // Patient identity (auto-filled)
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                            controller: _patientIdCtrl,
                            readOnly: true,
                            decoration: _dec('Patient ID')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                            controller: _patientNameCtrl,
                            readOnly: true,
                            decoration: _dec('Patient Name')),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                          width: 120,
                          child: TextFormField(
                              controller: _patientAgeCtrl,
                              readOnly: true,
                              decoration: _dec('Age'))),
                      const SizedBox(width: 12),
                      SizedBox(
                          width: 140,
                          child: TextFormField(
                              controller: _patientGenderCtrl,
                              readOnly: true,
                              decoration: _dec('Gender'))),
                    ]),
                    const SizedBox(height: 16),

                    // Last Visit Summary + Critical Alerts (two-column)
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Last Visit Summary',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                      controller: _lastVisitDateCtrl,
                                      readOnly: true,
                                      decoration: _dec('Last Visit Date')),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                      controller: _lastDiagnosisCtrl,
                                      readOnly: true,
                                      minLines: 2,
                                      maxLines: 4,
                                      decoration: _dec('Previous Diagnosis')),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                      controller: _lastProcedureCtrl,
                                      readOnly: true,
                                      minLines: 1,
                                      maxLines: 3,
                                      decoration: _dec(
                                          'Previous Procedure / Treatment')),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                      controller: _lastDoctorNotesCtrl,
                                      readOnly: true,
                                      minLines: 2,
                                      maxLines: 5,
                                      decoration:
                                          _dec('Previous Doctor Notes')),
                                ]),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 320,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Critical Medical Alerts',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Allergies'),
                                      value: _allergyFlag,
                                      onChanged: null),
                                  CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Diabetes'),
                                      value: _diabetesFlag,
                                      onChanged: null),
                                  CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Hypertension'),
                                      value: _hypertensionFlag,
                                      onChanged: null),
                                  CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Heart Disease'),
                                      value: _heartFlag,
                                      onChanged: null),
                                  CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Thyroid'),
                                      value: _thyroidFlag,
                                      onChanged: null),
                                  CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Bleeding Disorder'),
                                      value: _bleedingFlag,
                                      onChanged: null),
                                ]),
                          ),
                        ]),
                    const SizedBox(height: 16),

                    // Last recorded vitals & medication status
                    _sectionHeader('Last Recorded Vitals & Medications'),
                    Row(children: [
                      Expanded(
                          child: TextFormField(
                              controller: _lastBpSysCtrl,
                              readOnly: true,
                              decoration: _dec('BP (Systolic)'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextFormField(
                              controller: _lastBpDiaCtrl,
                              readOnly: true,
                              decoration: _dec('BP (Diastolic)'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextFormField(
                              controller: _lastHeartRateCtrl,
                              readOnly: true,
                              decoration: _dec('Heart Rate'))),
                      const SizedBox(width: 12),
                      SizedBox(
                          width: 140,
                          child: TextFormField(
                              controller: _lastSugarCtrl,
                              readOnly: true,
                              decoration: _dec('Sugar'))),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: TextFormField(
                              controller: _lastWeightCtrl,
                              readOnly: true,
                              decoration: _dec('Weight'))),
                      const SizedBox(width: 12),
                      SizedBox(
                          width: 140,
                          child: TextFormField(
                              controller: _lastBmiCtrl,
                              readOnly: true,
                              decoration: _dec('BMI'))),
                    ]),
                    const SizedBox(height: 8),
                    TextFormField(
                        controller: _currentMedsCtrl,
                        readOnly: true,
                        minLines: 2,
                        maxLines: 4,
                        decoration: _dec('Current Medications')),
                    const SizedBox(height: 8),
                    TextFormField(
                        controller: _lastPrescribedCtrl,
                        readOnly: true,
                        decoration: _dec('Last Prescribed Medicines')),
                    const SizedBox(height: 16),

                    // Dental history
                    _sectionHeader('Dental Treatment History'),
                    Wrap(spacing: 12, runSpacing: 6, children: [
                      SizedBox(
                          width: 180,
                          child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Root Canal'),
                              value: _dhRootCanal,
                              onChanged: null)),
                      SizedBox(
                          width: 180,
                          child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Implants'),
                              value: _dhImplants,
                              onChanged: null)),
                      SizedBox(
                          width: 180,
                          child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Crowns/Bridges'),
                              value: _dhCrowns,
                              onChanged: null)),
                      SizedBox(
                          width: 180,
                          child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Braces'),
                              value: _dhBraces,
                              onChanged: null)),
                      SizedBox(
                          width: 180,
                          child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Dentures'),
                              value: _dhDentures,
                              onChanged: null)),
                    ]),
                    const SizedBox(height: 8),
                    TextFormField(
                        controller: _dentalComplicationsCtrl,
                        readOnly: true,
                        minLines: 1,
                        maxLines: 3,
                        decoration: _dec('Previous Complications')),
                    const SizedBox(height: 16),

                    // Today's Symptoms
                    _sectionHeader("Today's Symptoms"),
                    Row(children: [
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Pain Level',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                              Wrap(
                                  spacing: 8,
                                  children: [
                                    'None',
                                    'Mild',
                                    'Moderate',
                                    'Severe'
                                  ].map((p) {
                                    return ChoiceChip(
                                      label: Text(p),
                                      selected: _painLevel == p,
                                      onSelected: (sel) =>
                                          setState(() => _painLevel = p),
                                    );
                                  }).toList()),
                            ]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Swelling'),
                              value: _symSwelling,
                              onChanged: (v) =>
                                  setState(() => _symSwelling = v ?? false))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Sensitivity'),
                              value: _symSensitivity,
                              onChanged: (v) => setState(
                                  () => _symSensitivity = v ?? false))),
                    ]),
                    const SizedBox(height: 8),
                    TextFormField(
                        controller: _newComplaintsCtrl,
                        minLines: 2,
                        maxLines: 5,
                        decoration: _dec('New complaints (describe)'),
                        validator: (v) => null),
                    const SizedBox(height: 16),

                    // Doctor's Assessment
                    _sectionHeader("Doctor's Assessment"),
                    TextFormField(
                        controller: _clinicalNotesCtrl,
                        minLines: 3,
                        maxLines: 6,
                        decoration: _dec('Clinical Examination Notes'),
                        validator: _required),
                    const SizedBox(height: 8),
                    TextFormField(
                        controller: _diagnosisCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: _dec('Diagnosis (Today)'),
                        validator: _required),
                    const SizedBox(height: 16),

                    // Treatment Plan
                    _sectionHeader('Treatment Plan'),
                    TextFormField(
                        controller: _newMedsPlanCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: _dec('New Medications (prescribe)')),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField2<String>(
                          value: _recommendedProcedure,
                          items: const [
                            DropdownMenuItem(
                                value: 'Procedure - Extraction',
                                child: Text('Extraction')),
                            DropdownMenuItem(
                                value: 'Procedure - Filling',
                                child: Text('Filling')),
                            DropdownMenuItem(
                                value: 'Procedure - Cleaning',
                                child: Text('Cleaning')),
                            DropdownMenuItem(
                                value: 'Procedure - Root Canal',
                                child: Text('Root Canal')),
                            DropdownMenuItem(
                                value: 'Procedure - Implant',
                                child: Text('Implant')),
                          ],
                          onChanged: (v) =>
                              setState(() => _recommendedProcedure = v),
                          decoration: _dec('Recommended Procedure (optional)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextFormField(
                              controller: _instructionsCtrl,
                              minLines: 1,
                              maxLines: 3,
                              decoration: _dec('Instructions to patient'))),
                    ]),
                    const SizedBox(height: 16),

                    // Next Appointment Scheduling
                    _sectionHeader('Next Appointment Scheduling'),
                    Row(children: [
                      SizedBox(
                        width: 180,
                        child: OutlinedButton(
                          onPressed: _pickNextVisitDate,
                          style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFF8FAFC)),
                          child: Text(_nextVisitDate == null
                              ? 'Pick date'
                              : _dateFmt.format(_nextVisitDate!)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 160,
                        child: OutlinedButton(
                          onPressed: _pickNextVisitTime,
                          style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFF8FAFC)),
                          child: Text(_nextVisitTime == null
                              ? 'Pick time'
                              : _timeOfDayLabel(_nextVisitTime)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField2<String>(
                          value: _nextVisitPurpose,
                          items: const [
                            DropdownMenuItem(
                                value: 'Follow-up', child: Text('Follow-up')),
                            DropdownMenuItem(
                                value: 'Cleaning', child: Text('Cleaning')),
                            DropdownMenuItem(
                                value: 'Procedure', child: Text('Procedure')),
                          ],
                          onChanged: (v) =>
                              setState(() => _nextVisitPurpose = v),
                          decoration: _dec('Purpose'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Doctor Signature / meta
                    _sectionHeader('Doctor Signature'),
                    Row(children: [
                      Expanded(
                          child: TextFormField(
                              controller: _doctorNameCtrl,
                              decoration: _dec('Doctor Name (auto)'))),
                      const SizedBox(width: 12),
                      SizedBox(
                          width: 240,
                          child: TextFormField(
                              controller: _signedAtCtrl,
                              readOnly: true,
                              decoration: _dec('Date & Time'))),
                    ]),
                    const SizedBox(height: 18),

                    // Actions
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      OutlinedButton(
                        onPressed: _saving ? null : () => _clearFormAfterSave(),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
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
                                borderRadius: BorderRadius.circular(12))),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Save Follow-up',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF111827))),
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

class _PatientOption {
  final String id;
  final String label;
  _PatientOption({required this.id, required this.label});
}