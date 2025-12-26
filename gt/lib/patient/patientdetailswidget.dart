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

  // edit mode
  bool _editing = false;
  bool _saving = false;

  // edit form controllers
  final _formKey = GlobalKey<FormState>();
  final _patientIdCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _gender; // M / F / O
  String? _referredBy; // D / P / O / X

  @override
  void initState() {
    super.initState();
    _loadPatientsForDropdown();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _patientIdCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _ageCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
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
      _editing = false;
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
  // Edit helpers
  // -----------------------
  void _startEdit() {
    if (_patientData == null) return;
    // populate controllers
    _patientIdCtrl.text =
        (_patientData!['patientId'] ?? _selectedPatientId) ?? '';
    _firstNameCtrl.text = (_patientData!['firstName'] ?? '');
    _lastNameCtrl.text = (_patientData!['lastName'] ?? '');
    _ageCtrl.text = (_patientData!['age']?.toString() ?? '');
    _mobileCtrl.text = (_patientData!['mobile'] ?? '');
    _addressCtrl.text = (_patientData!['address'] ?? '');
    final genderStr = (_patientData!['gender'] ?? '');
    _gender = (genderStr == 'Male')
        ? 'M'
        : (genderStr == 'Female')
            ? 'F'
            : (genderStr == 'Other')
                ? 'O'
                : null;
    _referredBy = (_patientData!['referredBy'] as String?) ?? null;

    setState(() {
      _editing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
    });
  }

  // Validation helpers (same rules as register)
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
    if (age < 1 || age > 120) return "Age must be between 1–120";
    return null;
  }

  String? _mobileVal(String? v) {
    if ((v ?? '').trim().isEmpty) return "Mobile number is required";
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

  // Duplicate composite check (exclude current id)
  Future<String?> _findDuplicateCompositeExcluding(
    String firstName,
    String lastName,
    String mobileFormatted,
    String excludePatientId,
  ) async {
    final mobileRaw = mobileFormatted.replaceAll(' ', '').trim();
    final key =
        '${firstName.toLowerCase()}|${lastName.toLowerCase()}|$mobileRaw';

    final snap = await _db
        .collection('patients')
        .where('compositeKey', isEqualTo: key)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    final foundId = snap.docs.first.id;
    if (foundId == excludePatientId) return null;
    return foundId;
  }

  Future<void> _onUpdate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please select gender")));
      return;
    }
    if (_referredBy == null || _referredBy!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select Referred By")));
      return;
    }

    setState(() => _saving = true);

    try {
      final patientId = _patientIdCtrl.text.trim();
      final firstName = _firstNameCtrl.text.trim();
      final lastName = _lastNameCtrl.text.trim();
      final mobileFormatted = _mobileCtrl.text;
      final mobileRaw = mobileFormatted.replaceAll(' ', '').trim();

      // duplicate check (exclude current doc)
      final dup = await _findDuplicateCompositeExcluding(
          firstName, lastName, mobileFormatted, patientId);
      if (dup != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Another patient exists with same name & mobile (ID $dup)')));
        setState(() => _saving = false);
        return;
      }

      final compositeKey =
          '${firstName.toLowerCase()}|${lastName.toLowerCase()}|$mobileRaw';

      final data = {
        'patientId': patientId,
        'firstName': firstName,
        'lastName': lastName,
        'fullName': '$firstName $lastName',
        'gender': (_gender == 'M')
            ? 'Male'
            : (_gender == 'F')
                ? 'Female'
                : 'Other',
        'age': int.parse(_ageCtrl.text.trim()),
        'mobile': mobileRaw,
        'address': _addressCtrl.text.trim(),
        'referredBy': _referredBy,
        'compositeKey': compositeKey,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _db
          .collection('patients')
          .doc(patientId)
          .set(data, SetOptions(merge: true));

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Patient updated')));
      // refresh details and exit edit
      await _loadPatientDetails(patientId);
      setState(() {
        _editing = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _editing ? _buildEditForm() : _buildView(),
                    ],
                  ),
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
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 32,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // ───── VIEW MODE → EDIT BUTTON ─────
                    if (!_editing)
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

                          // 🔄 reload details if updated
                          if (updated == true && _selectedPatientId != null) {
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

                    // ───── EDIT MODE → UPDATE + CANCEL ─────
                    if (_editing) ...[
                      InkWell(
                        onTap: _saving ? null : _onUpdate,
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
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Update',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: _saving ? null : _cancelEdit,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 26),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Edit Patient",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827))),
          const SizedBox(height: 24),

          // Patient ID (read-only)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text("Patient ID",
                style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          TextFormField(
              controller: _patientIdCtrl,
              readOnly: true,
              decoration: _dec("Auto-generated")),
          const SizedBox(height: 16),

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
              if (value == null || value.isEmpty) return "Gender is required";
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
                      offset: const Offset(0, 4)),
                ],
              ),
            ),
            menuItemStyleData: const MenuItemStyleData(
                height: 44,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
          ),
          const SizedBox(height: 16),

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

          _label("Mobile Number *"),
          TextFormField(
            controller: _mobileCtrl,
            validator: _mobileVal,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
              MobileNumberFormatter(),
            ],
            decoration: _dec("10-digit mobile number"),
          ),
          const SizedBox(height: 16),

          _label("Address *"),
          TextFormField(
            controller: _addressCtrl,
            validator: _addressVal,
            minLines: 2,
            maxLines: 4,
            decoration: _dec("Enter address"),
          ),
          const SizedBox(height: 16),

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
            validator: (v) {
              if (v == null || v.isEmpty) return "Referred By is required";
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
                      offset: const Offset(0, 4)),
                ],
              ),
            ),
            menuItemStyleData: const MenuItemStyleData(
                height: 44,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              ElevatedButton(
                onPressed: _saving ? null : _onUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text("Update",
                        style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _saving ? null : _cancelEdit,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Cancel"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 14,
                fontWeight: FontWeight.w600)),
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
