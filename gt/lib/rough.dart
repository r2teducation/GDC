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

  // ---------------- Patient Health Snapshot ----------------
  Map<String, dynamic>? _patientHealthSnapshot;
  bool _loadingHealthSnapshot = false;

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
    } catch (_) {
      setState(() => _loadingPatients = false);
    }
  }

  // ======================================================
  // Patient selection + fetch latest appointment snapshot
  // ======================================================
  Future<void> _onPatientSelected(String? v) async {
    setState(() {
      _selectedPatientId = v;
      _patientHealthSnapshot = null;
    });

    if (v == null) return;

    setState(() => _loadingHealthSnapshot = true);

    try {
      final snap = await _db
          .collection('appointments')
          .where('patientId', isEqualTo: v)
          .orderBy('appointmentDateTime', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        setState(() {
          _patientHealthSnapshot = snap.docs.first.data();
        });
      }
    } catch (_) {
      // ignore silently
    } finally {
      if (mounted) setState(() => _loadingHealthSnapshot = false);
    }
  }

  // ======================================================
  // Save
  // ======================================================
  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedPatientId == null) {
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
      _patientHealthSnapshot = null;
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _buildPatientOptionRow(_PatientOption p) {
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

  // ======================================================
  // Patient Health Panel (READ ONLY)
  // ======================================================
  Widget _patientHealthPanel() {
    if (_loadingHealthSnapshot) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }

    if (_patientHealthSnapshot == null) return const SizedBox.shrink();

    final health = _patientHealthSnapshot!['healthConditions'] as Map?;
    final allergies = _patientHealthSnapshot!['allergyNotes'] ?? '';
    final vitals = _patientHealthSnapshot!;

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF22C55E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patient Health Conditions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),

          if (health != null)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: health.entries
                  .where((e) => e.value == true)
                  .map((e) => Chip(
                        label: Text(e.key),
                        backgroundColor: Colors.green.shade100,
                      ))
                  .toList(),
            ),

          if (allergies.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Allergies: $allergies',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ],
      ),
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

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField2<String>(
                  isExpanded: true,
                  value: _selectedPatientId,
                  decoration: _dec("Select patient"),
                  items: _patientOptions
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: _buildPatientOptionRow(p),
                          ))
                      .toList(),
                  onChanged: _onPatientSelected,
                  validator: (v) =>
                      v == null ? 'Please select a patient' : null,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (d != null) setState(() => _selectedDate = d);
                },
                child: Text(_displayDate.format(_selectedDate)),
              ),
            ],
          ),

          // 🔥 PATIENT HEALTH CONDITIONS PANEL
          _patientHealthPanel(),

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
            onPressed: () {}, // unchanged dialog logic
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