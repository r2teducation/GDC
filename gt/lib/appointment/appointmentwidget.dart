import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppointmentWidget extends StatefulWidget {
  const AppointmentWidget({super.key});

  @override
  State<AppointmentWidget> createState() => _AppointmentWidgetState();
}

class _AppointmentWidgetState extends State<AppointmentWidget> {
  final _formKey = GlobalKey<FormState>();

  // Patient search controls (pattern copied from PatientDetailsWidget)
  final TextEditingController _searchCtrl = TextEditingController();
  final _db = FirebaseFirestore.instance;

  bool _loadingPatients = true;
  List<_PatientOption> _patientOptions = [];
  String? _selectedPatientId;

  // Appointment date/time
  DateTime? _appointmentDateTime;
  final TextEditingController _appointmentDateTimeCtrl = TextEditingController();

  // Appointment type: 'N' = New, 'F' = Follow Up
  String? _appointmentType;

  // Notes
  final TextEditingController _notesCtrl = TextEditingController();

  // UI state
  bool _saving = false;

  // Show appointment-type validation only after user attempts submit
  bool _submittedAttempted = false;

  // Date formatter — clearer format requested: "10-December-2025 Wednesday 8:21 AM"
  final DateFormat _displayFormatter = DateFormat('dd-MMMM-yyyy EEEE h:mm a');

  @override
  void initState() {
    super.initState();
    _loadPatientsForDropdown();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _appointmentDateTimeCtrl.dispose();
    _notesCtrl.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load patients: $e')),
      );
    }
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
    );
  }

  // Pick date then time, store combined DateTime and format display text
  Future<void> _pickAppointmentDateTime() async {
    final now = DateTime.now();
    final initialDate = _appointmentDateTime ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_appointmentDateTime ?? now),
    );
    if (pickedTime == null) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _appointmentDateTime = combined;
      // format as "10-December-2025 Wednesday 8:21 AM"
      _appointmentDateTimeCtrl.text = _displayFormatter.format(combined);
    });
  }

  String? _validatePatient(String? v) {
    if (v == null || v.isEmpty) return "Please select a patient";
    return null;
  }

  String? _validateDateTime(String? v) {
    if (_appointmentDateTime == null) return "Please select date & time";
    return null;
  }

  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();

    // Mark that user attempted to submit — this toggles showing the radio error message.
    setState(() {
      _submittedAttempted = true;
    });

    if (!_formKey.currentState!.validate()) return;

    // check patient selection
    if (_selectedPatientId == null || _selectedPatientId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a patient')));
      return;
    }

    // check date/time
    if (_appointmentDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select appointment date & time')));
      return;
    }

    // check appointment type (radio)
    if (_appointmentType == null || _appointmentType!.isEmpty) {
      // keep inline error visible (because _submittedAttempted == true) and show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select appointment type')));
      return;
    }

    setState(() => _saving = true);

    try {
      final data = {
        'patientId': _selectedPatientId,
        'appointmentDateTime': Timestamp.fromDate(_appointmentDateTime!),
        'appointmentType': _appointmentType, // 'N' or 'F'
        'notes': _notesCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _db.collection('appointments').add(data);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment created')),
      );

      // reset form
      setState(() {
        _selectedPatientId = null;
        _appointmentDateTime = null;
        _appointmentDateTimeCtrl.text = '';
        _appointmentType = null;
        _notesCtrl.clear();
        _submittedAttempted = false; // reset so error message hides again
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save appointment: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Create Appointment",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Patient search (copied pattern)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      "Patient Search",
                      style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_loadingPatients)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    )
                  else
                    DropdownButtonFormField2<String>(
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
                      onChanged: (v) => setState(() => _selectedPatientId = v),
                      validator: _validatePatient,
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
                          thumbVisibility: MaterialStateProperty.all(true),
                        ),
                      ),
                      menuItemStyleData: const MenuItemStyleData(
                        height: 44,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                              prefixIcon: const Icon(Icons.search, size: 18),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
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
                        if (!isOpen) _searchCtrl.clear();
                      },
                    ),

                  const SizedBox(height: 20),

                  // Date & Time
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      "Appointment Date & Time *",
                      style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextFormField(
                    readOnly: true,
                    controller: _appointmentDateTimeCtrl,
                    onTap: _pickAppointmentDateTime,
                    decoration: _dec("DD-MMMM-YYYY dddd h:mm AM/PM"),
                    validator: _validateDateTime,
                  ),

                  const SizedBox(height: 16),

                  // Appointment Type (radio buttons)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      "Appointment Type *",
                      style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("New"),
                          value: 'N',
                          groupValue: _appointmentType,
                          onChanged: (v) => setState(() => _appointmentType = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text("Follow Up"),
                          value: 'F',
                          groupValue: _appointmentType,
                          onChanged: (v) => setState(() => _appointmentType = v),
                        ),
                      ),
                    ],
                  ),
                  // show inline validation message only after the user clicked Create once
                  if (_submittedAttempted && (_appointmentType == null))
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 6, bottom: 6),
                      child: Text(
                        "Please select appointment type",
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Notes — wide box upto 300 chars
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      "Notes",
                      style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 5,
                    maxLength: 300,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Enter notes (optional, up to 300 chars)',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Action button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Create Appointment",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
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