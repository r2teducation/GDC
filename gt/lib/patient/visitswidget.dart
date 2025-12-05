import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

enum VisitMode { create, edit }

class VisitsWidget extends StatefulWidget {
  const VisitsWidget({super.key});

  @override
  State<VisitsWidget> createState() => _VisitsWidgetState();
}

class _VisitsWidgetState extends State<VisitsWidget> {
  final _formKey = GlobalKey<FormState>();

  // Patient search
  final TextEditingController _patientSearchCtrl = TextEditingController();
  String? _selectedPatientId;
  bool _loadingPatients = true;
  bool _loadingVisit = false;

  // Form controllers
  final TextEditingController _registrationDateCtrl = TextEditingController();
  final TextEditingController _appointmentDateTimeCtrl =
      TextEditingController();

  // Enums as codes
  String? _referredBy; // D / P / O / X
  String? _appointmentType; // N / F
  String? _consentSigned; // Y / N

  // Internal mode & state
  VisitMode _mode = VisitMode.create;
  String? _visitDocId; // Firestore doc id for editing

  final _db = FirebaseFirestore.instance;

  // Patient dropdown options
  List<_PatientOption> _patientOptions = [];

  // Date formats
  final DateFormat _dateFormatter = DateFormat('dd/MM/yyyy');
  final DateFormat _dateTimeFormatter = DateFormat('dd/MM/yyyy hh:mm:ss a');

  // Raw DateTime values for validation and saving
  DateTime? _registrationDate;
  DateTime? _appointmentDateTime;

  @override
  void initState() {
    super.initState();
    _loadPatientsForDropdown();
    _initDefaults();
  }

  void _initDefaults() {
    final now = DateTime.now();
    _registrationDate = DateTime(now.year, now.month, now.day);
    _appointmentDateTime = now;

    _registrationDateCtrl.text = _dateFormatter.format(_registrationDate!);
    _appointmentDateTimeCtrl.text =
        _dateTimeFormatter.format(_appointmentDateTime!);

    // Default appointment type = Follow-up (as per requirement)
    _appointmentType = 'F';
  }

  @override
  void dispose() {
    _patientSearchCtrl.dispose();
    _registrationDateCtrl.dispose();
    _appointmentDateTimeCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------
  // LOAD PATIENT LIST FOR DROPDOWN (only active patients)
  // -------------------------------------------------------
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

  // -------------------------------------------------------
  // VALIDATIONS
  // -------------------------------------------------------
  String? _validateRegistrationDate(String? v) {
    if (v == null || v.trim().isEmpty) {
      return "Registration date is required";
    }
    try {
      final parsed = _dateFormatter.parseStrict(v.trim());
      final today = DateTime.now();
      final todayDateOnly = DateTime(today.year, today.month, today.day);
      final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);

      if (dateOnly.isAfter(todayDateOnly)) {
        return "Registration date cannot be in the future";
      }
      return null;
    } catch (_) {
      return "Enter a valid date (DD/MM/YYYY)";
    }
  }

  String? _validateAppointmentDateTime(String? v) {
    if (v == null || v.trim().isEmpty) {
      return "Appointment date & time is required";
    }
    DateTime appt;
    try {
      appt = _dateTimeFormatter.parseStrict(v.trim());
    } catch (_) {
      return "Enter a valid date & time (DD/MM/YYYY HH:MM:SS AM/PM)";
    }

    // Also validate against registration date
    if (_registrationDateCtrl.text.trim().isNotEmpty) {
      try {
        final reg = _dateFormatter.parseStrict(
          _registrationDateCtrl.text.trim(),
        );
        final regDateOnly = DateTime(reg.year, reg.month, reg.day);
        if (appt.isBefore(regDateOnly)) {
          return "Appointment cannot be earlier than registration date";
        }
      } catch (_) {
        // if reg date itself invalid, that field's validator will handle
      }
    }

    return null;
  }

  String? _validateReferredBy(String? v) {
    if (v == null || v.isEmpty) return "Referred By is required";
    if (!['D', 'P', 'O', 'X'].contains(v)) {
      return "Invalid Referred By value";
    }
    return null;
  }

  String? _validateAppointmentType(String? v) {
    if (v == null || v.isEmpty) return "Appointment Type is required";
    if (!['N', 'F'].contains(v)) {
      return "Invalid Appointment Type";
    }
    return null;
  }

  String? _validateConsentSigned(String? v) {
    if (v == null || v.isEmpty) return "Consent status is required";
    if (!['Y', 'N'].contains(v)) {
      return "Invalid Consent status";
    }
    return null;
  }

  String? _validatePatientSelected(String? v) {
    if (v == null || v.isEmpty) {
      return "Please select a patient";
    }
    return null;
  }

  // -------------------------------------------------------
  // HELPERS FOR LABELS / DECORATION
  // -------------------------------------------------------
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  // helper to build each dropdown row: [ID]  [Name...]
  Widget _buildPatientOptionRow(_PatientOption p) {
    final parts = p.label.split(RegExp(r'\s{2,}'));
    final idPart = parts.isNotEmpty ? parts.first : p.id;
    final namePart = parts.length > 1 ? parts.sublist(1).join('  ') : '';

    return Row(
      children: [
        Text(
          idPart,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            namePart,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------
  // PATIENT SELECTION → LOAD / DEFAULT VISIT
  // -------------------------------------------------------
  void _onPatientSelected(String? value) {
    if (value == null || value.isEmpty) {
      setState(() {
        _selectedPatientId = null;
        _mode = VisitMode.create;
        _visitDocId = null;
        _resetFormForNewVisit();
      });
      return;
    }

    _handlePatientSelection(value);
  }

  Future<void> _handlePatientSelection(String patientId) async {
    setState(() {
      _selectedPatientId = patientId;
      _loadingVisit = true;
    });

    try {
      // Find latest visit for this patient
      final snap = await _db
          .collection('visits')
          .where('patientId', isEqualTo: patientId)
          .orderBy('appointmentDateTime', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        // No appointment → show info dialog, then load defaults in Create mode
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('No Appointment Booked'),
            content: const Text(
              'There is no appointment booked for this patient. A new appointment form is ready with default values.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        setState(() {
          _mode = VisitMode.create;
          _visitDocId = null;
          _resetFormForNewVisit(); // fills defaults for selected patient
        });
      } else {
        // Existing visit found → Edit mode
        final doc = snap.docs.first;
        final data = doc.data();
        _visitDocId = doc.id;

        final regTs = data['registrationDate'] as Timestamp?;
        final apptTs = data['appointmentDateTime'] as Timestamp?;

        _registrationDate = regTs?.toDate();
        _appointmentDateTime = apptTs?.toDate();

        _registrationDateCtrl.text = _registrationDate != null
            ? _dateFormatter.format(_registrationDate!)
            : '';
        _appointmentDateTimeCtrl.text = _appointmentDateTime != null
            ? _dateTimeFormatter.format(_appointmentDateTime!)
            : '';

        _referredBy = (data['referredBy'] as String?) ?? 'D';
        _appointmentType = (data['appointmentType'] as String?) ?? 'F';
        _consentSigned = (data['consentFormsSigned'] as String?) ?? 'N';

        setState(() {
          _mode = VisitMode.edit;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load visit: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingVisit = false;
        });
      }
    }
  }

  void _resetFormForNewVisit() {
    _initDefaults();
    _referredBy = null;
    _consentSigned = null;
    // appointmentType already defaulted to 'F' in _initDefaults
  }

  // -------------------------------------------------------
  // DATE PICKERS
  // -------------------------------------------------------
  Future<void> _pickRegistrationDate() async {
    final now = DateTime.now();
    final initial = _registrationDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: now, // cannot be in future
    );
    if (picked != null) {
      setState(() {
        _registrationDate = picked;
        _registrationDateCtrl.text = _dateFormatter.format(picked);

        // Ensure appointment is not before registration
        if (_appointmentDateTime != null &&
            _appointmentDateTime!.isBefore(
              DateTime(picked.year, picked.month, picked.day),
            )) {
          _appointmentDateTime =
              DateTime(picked.year, picked.month, picked.day, 9, 0, 0);
          _appointmentDateTimeCtrl.text =
              _dateTimeFormatter.format(_appointmentDateTime!);
        }
      });
    }
  }

  Future<void> _pickAppointmentDateTime() async {
    final now = DateTime.now();
    final reg = _registrationDate ?? DateTime(now.year, now.month, now.day);

    final initialDate = _appointmentDateTime ?? reg;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: reg, // cannot be earlier than registration date
      lastDate: DateTime(now.year + 2),
    );

    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _appointmentDateTime ?? DateTime.now(),
      ),
    );

    if (pickedTime == null) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
      0,
    );

    setState(() {
      _appointmentDateTime = combined;
      _appointmentDateTimeCtrl.text =
          _dateTimeFormatter.format(_appointmentDateTime!);
    });
  }

  // -------------------------------------------------------
  // SAVE (CREATE / UPDATE)
  // -------------------------------------------------------
  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    if (_selectedPatientId == null || _selectedPatientId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient')),
      );
      return;
    }

    // Parse again to be safe
    try {
      _registrationDate =
          _dateFormatter.parseStrict(_registrationDateCtrl.text.trim());
      _appointmentDateTime =
          _dateTimeFormatter.parseStrict(_appointmentDateTimeCtrl.text.trim());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid date or time format: $e')),
      );
      return;
    }

    setState(() {
      _loadingVisit = true;
    });

    try {
      final data = {
        'patientId': _selectedPatientId,
        'registrationDate':
            Timestamp.fromDate(_registrationDate ?? DateTime.now()),
        'referredBy': _referredBy, // D/P/O/X
        'appointmentType': _appointmentType, // N/F
        'appointmentDateTime':
            Timestamp.fromDate(_appointmentDateTime ?? DateTime.now()),
        'consentFormsSigned': _consentSigned, // Y/N
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_mode == VisitMode.create || _visitDocId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        final docRef = await _db.collection('visits').add(data);
        _visitDocId = docRef.id;
        setState(() {
          _mode = VisitMode.edit;
        });
      } else {
        await _db
            .collection('visits')
            .doc(_visitDocId!)
            .set(data, SetOptions(merge: true));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _mode == VisitMode.create
                ? "Appointment Created"
                : "Appointment Updated",
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving visit: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingVisit = false;
        });
      }
    }
  }

  // -------------------------------------------------------
  // UI
  // -------------------------------------------------------
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
                  // TITLE
                  Text(
                    _mode == VisitMode.create
                        ? "Create Appointment"
                        : "Edit Appointment",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // PATIENT SEARCH
                  _label("Patient Search"),
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
                      onChanged: _loadingVisit ? null : _onPatientSelected,
                      validator: _validatePatientSelected,
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
                        searchController: _patientSearchCtrl,
                        searchInnerWidgetHeight: 52,
                        searchInnerWidget: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextField(
                            controller: _patientSearchCtrl,
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
                        if (!isOpen) _patientSearchCtrl.clear();
                      },
                    ),
                  const SizedBox(height: 24),
                  if (_loadingVisit)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: LinearProgressIndicator(),
                    ),

                  // REGISTRATION DATE
                  _label("Registration Date *"),
                  TextFormField(
                    controller: _registrationDateCtrl,
                    readOnly: true, // no manual key-in
                    onTap: _pickRegistrationDate,
                    decoration: _dec("DD/MM/YYYY"),
                    validator: _validateRegistrationDate,
                  ),
                  const SizedBox(height: 16),
                  // REFERRED BY
                  _label("Referred By *"),
                  DropdownButtonFormField2<String>(
                    isExpanded: true,
                    value: _referredBy,
                    decoration: _dec("Select source"),
                    items: const [
                      DropdownMenuItem(value: 'D', child: Text("Doctor")),
                      DropdownMenuItem(value: 'P', child: Text("Patient")),
                      DropdownMenuItem(value: 'O', child: Text("Online")),
                      DropdownMenuItem(value: 'X', child: Text("Other")),
                    ],
                    onChanged: (v) => setState(() => _referredBy = v),
                    validator: _validateReferredBy,
                    dropdownStyleData: DropdownStyleData(
                      maxHeight: 220,
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
                    ),
                    menuItemStyleData: const MenuItemStyleData(
                      height: 44,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // APPOINTMENT TYPE
                  _label("Appointment Type *"),
                  DropdownButtonFormField2<String>(
                    isExpanded: true,
                    value: _appointmentType,
                    decoration: _dec("Select appointment type"),
                    items: const [
                      DropdownMenuItem(value: 'N', child: Text("New")),
                      DropdownMenuItem(value: 'F', child: Text("Follow-up")),
                    ],
                    onChanged: (v) => setState(() => _appointmentType = v),
                    validator: _validateAppointmentType,
                    dropdownStyleData: DropdownStyleData(
                      maxHeight: 180,
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
                    ),
                    menuItemStyleData: const MenuItemStyleData(
                      height: 44,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // APPOINTMENT DATE & TIME
                  _label("Appointment Date & Time *"),
                  TextFormField(
                    controller: _appointmentDateTimeCtrl,
                    readOnly: true,
                    onTap: _pickAppointmentDateTime,
                    decoration: _dec("DD/MM/YYYY HH:MM:SS AM/PM"),
                    validator: _validateAppointmentDateTime,
                  ),
                  const SizedBox(height: 16),

                  // CONSENT SIGNED
                  _label("Consent Forms Signed *"),
                  DropdownButtonFormField2<String>(
                    isExpanded: true,
                    value: _consentSigned,
                    decoration: _dec("Select"),
                    items: const [
                      DropdownMenuItem(value: 'Y', child: Text("Yes")),
                      DropdownMenuItem(value: 'N', child: Text("No")),
                    ],
                    onChanged: (v) => setState(() => _consentSigned = v),
                    validator: _validateConsentSigned,
                    dropdownStyleData: DropdownStyleData(
                      maxHeight: 160,
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
                    ),
                    menuItemStyleData: const MenuItemStyleData(
                      height: 44,
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ACTION BUTTON
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      onPressed: _loadingVisit ? null : _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mode == VisitMode.create
                            ? const Color(0xFF16A34A) // green
                            : const Color(0xFFF97316), // orange
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loadingVisit
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _mode == VisitMode.create
                                  ? "Create Appointment"
                                  : "Update Appointment",
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
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
  final String label; // ID + Name
  _PatientOption({required this.id, required this.label});
}
