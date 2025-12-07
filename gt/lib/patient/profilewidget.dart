import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ProfileMode { create, edit }

class ProfileWidget extends StatefulWidget {
  const ProfileWidget({super.key}); // 👈 internal mode handling

  @override
  State<ProfileWidget> createState() => _ProfileWidgetState();
}

class _ProfileWidgetState extends State<ProfileWidget> {
  final _formKey = GlobalKey<FormState>();

  final _patientIdCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // search text inside dropdown
  final TextEditingController _searchCtrl = TextEditingController();

  String? _gender; // M / F / O
  bool _loading = false; // for save / load
  bool _loadingPatients = true; // for dropdown loading

  ProfileMode _mode = ProfileMode.create; // internal mode
  String? _selectedPatientId; // from Patient Search

  final _db = FirebaseFirestore.instance;

  // For dropdown options: patientId + fullName
  List<_PatientOption> _patientOptions = [];

  @override
  void initState() {
    super.initState();
    _patientIdCtrl.text = 'Auto-generated';
    _loadPatientsForDropdown();
  }

  @override
  void dispose() {
    _patientIdCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _ageCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------
// COMPOSITE (FIRST + LAST + MOBILE) DUPLICATE CHECK
// -------------------------------------------------------
  Future<String?> _findDuplicateComposite(
    String firstName,
    String lastName,
    String mobileFormatted,
  ) async {
    // Normalise mobile: strip spaces
    final mobileRaw = mobileFormatted.replaceAll(' ', '').trim();

    // Normalise names: lowercase, trim
    final key =
        '${firstName.toLowerCase()}|${lastName.toLowerCase()}|$mobileRaw';

    final snap = await _db
        .collection('patients')
        .where('compositeKey', isEqualTo: key)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null; // no duplicate

    // Return the existing patient's id (document id == patientId)
    return snap.docs.first.id;
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

        // skip soft-deleted patients
        if (data['isActive'] == false) continue;

        final id = (data['patientId'] ?? doc.id).toString();

        final fullName = (data['fullName'] ??
                '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
            .toString()
            .trim();

        // label used for display & searching: "<id>  <name>"
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

  // Convert full gender -> code
  String? _toCode(String? g) {
    switch (g) {
      case 'Male':
        return 'M';
      case 'Female':
        return 'F';
      case 'Other':
        return 'O';
    }
    return null;
  }

  // Convert code -> full text
  String _fromCode(String code) {
    switch (code) {
      case 'M':
        return 'Male';
      case 'F':
        return 'Female';
      case 'O':
        return 'Other';
      default:
        return 'Other';
    }
  }

  // -------------------------------------------------------
  // FIRESTORE - AUTO GENERATE PATIENT ID
  // -------------------------------------------------------
  Future<String> _generatePatientId() async {
    final counterRef = _db.collection('counters').doc('patientCounter');

    return await _db.runTransaction((tx) async {
      final snap = await tx.get(counterRef);
      int last = snap.exists ? snap['lastNumber'] : 0;
      int newNum = last + 1;

      tx.update(counterRef, {'lastNumber': newNum});

      return "P-${newNum.toString().padLeft(5, '0')}";
    });
  }

  Future<bool> _checkDuplicateId(String patientId) async {
    final doc = await _db.collection('patients').doc(patientId).get();
    return doc.exists;
  }

  // -------------------------------------------------------
  // VALIDATIONS
  // -------------------------------------------------------
  String? _req(String? v, {String name = "This field"}) {
    if (v == null || v.trim().isEmpty) return "$name is required";
    return null;
  }

  // allow alphabets + spaces
  String? _nameVal(String? v, {String name = "This field"}) {
    if ((v ?? '').trim().isEmpty) return "$name is required";

    final t = v!.trim();

    if (!RegExp(r'^[A-Za-z ]+$').hasMatch(t)) {
      return "$name must contain only alphabets and spaces";
    }
    if (t.length < 2) return "$name must be at least 2 characters";
    if (t.length > 50) return "$name must be under 50 characters";

    return null;
  }

  String? _ageVal(String? v) {
    if (v == null || v.trim().isEmpty) return "Age is required";
    final age = int.tryParse(v.trim());
    if (age == null) return "Enter a valid number";

    if (age < 1 || age > 120) {
      return "Age must be between 1–120";
    }
    return null;
  }

  String? _mobileVal(String? v) {
    if ((v ?? '').trim().isEmpty) return "Mobile number is required";

    // remove all spaces
    final digits = v!.replaceAll(' ', '');

    if (!RegExp(r'^[0-9]{10}$').hasMatch(digits)) {
      return "Enter a valid 10-digit number";
    }
    return null;
  }

  String? _addressVal(String? v) {
    if ((v ?? '').trim().isEmpty) return "Address is required";
    final t = v!.trim();
    if (t.length < 2) return "Address must be at least 2 characters";
    if (t.length > 100) return "Address must be under 100 characters";
    return null;
  }

  // -------------------------------------------------------
  // MODE & FORM HELPERS
  // -------------------------------------------------------
  void _clearForm() {
    _patientIdCtrl.text = 'Auto-generated';
    _firstNameCtrl.clear();
    _lastNameCtrl.clear();
    _ageCtrl.clear();
    _mobileCtrl.clear();
    _addressCtrl.clear();
    _gender = null;
  }

  Future<void> _loadPatientAndFillForm(String patientId) async {
    setState(() => _loading = true);
    try {
      final doc = await _db.collection('patients').doc(patientId).get();
      if (!doc.exists) {
        throw Exception('Patient not found');
      }
      final p = doc.data() as Map<String, dynamic>;

      _patientIdCtrl.text = p['patientId'] ?? patientId;
      _firstNameCtrl.text = p['firstName'] ?? '';
      _lastNameCtrl.text = p['lastName'] ?? '';
      _gender = _toCode(p['gender']);
      _ageCtrl.text = p['age']?.toString() ?? '';
      _mobileCtrl.text = p['mobile'] ?? '';
      _addressCtrl.text = p['address'] ?? '';

      setState(() {
        _mode = ProfileMode.edit;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load patient: $e')),
      );
      _clearForm();
      setState(() {
        _selectedPatientId = null;
        _mode = ProfileMode.create;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onPatientSelected(String? value) {
    // value == '' => "New Patient (Create)"
    if (value == null || value.isEmpty) {
      setState(() {
        _selectedPatientId = null;
        _mode = ProfileMode.create;
      });
      _clearForm();
    } else {
      setState(() {
        _selectedPatientId = value;
      });
      _loadPatientAndFillForm(value);
    }
  }

  // -------------------------------------------------------
  // CREATE / UPDATE
  // -------------------------------------------------------
  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select gender")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // ----- 1. Gather & normalise basic fields -----
      final firstName = _firstNameCtrl.text.trim();
      final lastName = _lastNameCtrl.text.trim();
      final mobileFormatted = _mobileCtrl.text; // may contain a space
      final mobileRaw = mobileFormatted.replaceAll(' ', '').trim();

      // Safety: mobile should already be valid from validator, but double-check
      if (!RegExp(r'^[0-9]{10}$').hasMatch(mobileRaw)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter a valid 10-digit number")),
        );
        setState(() => _loading = false);
        return;
      }

      // Composite key (normalized)
      final compositeKey =
          '${firstName.toLowerCase()}|${lastName.toLowerCase()}|$mobileRaw';

      // ----- 2. Composite-uniqueness check -----
      final dupId =
          await _findDuplicateComposite(firstName, lastName, mobileFormatted);

      // CREATE: any duplicate is not allowed
      if (_mode == ProfileMode.create && dupId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Patient already exists with ID $dupId (same name & mobile)',
            ),
          ),
        );
        setState(() => _loading = false);
        return;
      }

      // EDIT: allow if it's the *same* patient, block if different patient
      if (_mode == ProfileMode.edit &&
          dupId != null &&
          dupId != _patientIdCtrl.text.trim()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Another patient already exists with same name & mobile (ID $dupId)',
            ),
          ),
        );
        setState(() => _loading = false);
        return;
      }

      // ----- 3. Get / generate patientId as before -----
      String patientId;

      if (_mode == ProfileMode.create) {
        patientId = await _generatePatientId();

        if (await _checkDuplicateId(patientId)) {
          throw Exception("Duplicate Patient ID generated. Try again.");
        }
      } else {
        patientId = _patientIdCtrl.text.trim();
      }

      final fullName = "$firstName $lastName";

      // ----- 4. Build data payload (note: mobileRaw + compositeKey) -----
      final data = {
        'patientId': patientId,
        'firstName': firstName,
        'lastName': lastName,
        'fullName': fullName,
        'gender': _fromCode(_gender!),
        'age': int.parse(_ageCtrl.text.trim()),
        'mobile': mobileRaw, // 👈 stored without spaces
        'address': _addressCtrl.text.trim(),
        'compositeKey': compositeKey, // 👈 NEW field for uniqueness
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      if (_mode == ProfileMode.create) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      // ----- 5. Save (works for both create & update) -----
      await _db
          .collection('patients')
          .doc(patientId)
          .set(data, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _mode == ProfileMode.create ? "Patient Created" : "Patient Updated",
          ),
        ),
      );

      // After creating, switch to edit mode and refresh dropdown
      if (_mode == ProfileMode.create) {
        setState(() {
          _mode = ProfileMode.edit;
          _patientIdCtrl.text = patientId;
          _selectedPatientId = patientId;
        });
        _loadPatientsForDropdown();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  // -------------------------------------------------------
  // SOFT DELETE
  // -------------------------------------------------------
  Future<void> _onDelete() async {
    final patientId = _patientIdCtrl.text.trim();
    if (patientId.isEmpty || patientId == 'Auto-generated') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No patient selected to delete')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await _db.collection('patients').doc(patientId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'deletedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient deleted (soft delete)')),
      );

      // Reset to create mode, clear form, refresh dropdown
      _clearForm();
      setState(() {
        _mode = ProfileMode.create;
        _selectedPatientId = null;
      });
      await _loadPatientsForDropdown();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }

    if (mounted) setState(() => _loading = false);
  }

  // -------------------------------------------------------
  // UI — MATCHES SimpleFormWidget
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
    // assume label = "<id>  <name>"
    final parts = p.label.split(RegExp(r'\s{2,}')); // split by 2+ spaces
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
                    _mode == ProfileMode.create
                        ? "Create Patient"
                        : "Edit Patient",
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
                      value: _selectedPatientId ?? '',
                      decoration: _dec("Select patient to edit"),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('➕ New Patient (Create)'),
                        ),
                        ..._patientOptions.map(
                          (p) => DropdownMenuItem<String>(
                            value: p.id,
                            child: _buildPatientOptionRow(p),
                          ),
                        ),
                      ],
                      onChanged: _loading ? null : _onPatientSelected,

                      // 🔽 here we limit dropdown height + keep your nice styling
                      dropdownStyleData: DropdownStyleData(
                        // 👇 height for about 6 items (tweak as you like)
                        maxHeight: 280,

                        decoration: BoxDecoration(
                          color: const Color(
                              0xFFF8FAFC), // same as form field fill
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),

                        // optional: nicer visible scrollbar
                        scrollbarTheme: ScrollbarThemeData(
                          radius: const Radius.circular(12),
                          thickness: MaterialStateProperty.all(4),
                          thumbVisibility: MaterialStateProperty.all(true),
                        ),
                      ),

                      menuItemStyleData: const MenuItemStyleData(
                        // 👇 reduce height slightly so 6 fit nicely
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
                          if (value.isEmpty)
                            return true; // always show "New Patient"
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
                  const SizedBox(height: 24),

                  // PATIENT ID
                  _label("Patient ID"),
                  TextFormField(
                    controller: _patientIdCtrl,
                    readOnly: true,
                    decoration: _dec("Auto-generated"),
                  ),
                  const SizedBox(height: 16),

                  // FIRST NAME (alphabets + space only)
                  _label("First Name *"),
                  TextFormField(
                    controller: _firstNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => _nameVal(v, name: "First Name"),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
                      SingleSpaceNameFormatter(),
                      LengthLimitingTextInputFormatter(50),
                    ],
                    decoration: _dec("Enter first name"),
                  ),
                  const SizedBox(height: 16),

                  // LAST NAME (alphabets + space only)
                  _label("Last Name *"),
                  TextFormField(
                    controller: _lastNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => _nameVal(v, name: "Last Name"),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z ]')),
                      SingleSpaceNameFormatter(),
                      LengthLimitingTextInputFormatter(50),
                    ],
                    decoration: _dec("Enter last name"),
                  ),
                  const SizedBox(height: 16),

                  // GENDER
                  _label("Gender *"),
                  DropdownButtonFormField2<String>(
                    isExpanded: true,
                    value: _gender,
                    decoration: _dec("Select gender"),
                    items: const [
                      DropdownMenuItem(value: 'M', child: Text("Male")),
                      DropdownMenuItem(value: 'F', child: Text("Female")),
                      DropdownMenuItem(value: 'O', child: Text("Other")),
                    ],
                    onChanged: (value) => setState(() => _gender = value),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Gender is required";
                      }
                      return null;
                    },
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

                  // AGE
                  _label("Age *"),
                  TextFormField(
                    controller: _ageCtrl,
                    validator: _ageVal,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: _dec("Enter age"),
                  ),
                  const SizedBox(height: 16),

                  // MOBILE
                  _label("Mobile Number *"),
                  TextFormField(
                    controller: _mobileCtrl,
                    validator: _mobileVal,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(
                          11), // 10 digits + 1 space
                      MobileNumberFormatter(),
                    ],
                    decoration: _dec("10-digit mobile number"),
                  ),
                  const SizedBox(height: 16),

                  // ADDRESS
                  _label("Address *"),
                  TextFormField(
                    controller: _addressCtrl,
                    validator: _addressVal,
                    minLines: 2,
                    maxLines: 4,
                    decoration: _dec("Enter address"),
                  ),
                  const SizedBox(height: 32),

                  // ACTION BUTTONS
                  if (_mode == ProfileMode.create)
                    // CREATE MODE → single green button
                    ElevatedButton(
                      onPressed: _loading ? null : _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A), // green
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Create",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    )
                  else
                    // EDIT MODE → Update (orange) + Delete (red)
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _loading ? null : _onSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF97316), // orange
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Update",
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _loading ? null : _onDelete,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626), // red
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Delete",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
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
}

class _PatientOption {
  final String id;
  final String label; // contains ID + name for display & searching
  _PatientOption({required this.id, required this.label});
}

class MobileNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(' ', ''); // remove spaces

    // limit to 10 digits
    if (digits.length > 10) digits = digits.substring(0, 10);

    String formatted = '';
    for (int i = 0; i < digits.length; i++) {
      formatted += digits[i];
      if (i == 4 && digits.length > 5)
        formatted += ' '; // add space after 5th digit
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class SingleSpaceNameFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;

    // Replace multiple spaces with a single space
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    // Remove leading spaces
    if (text.startsWith(' ')) {
      text = text.trimLeft();
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
