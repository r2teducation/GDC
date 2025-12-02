import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ProfileMode { create, edit }

class ProfileWidget extends StatefulWidget {
  final ProfileMode mode;
  final Map<String, dynamic>? initial; // for EDIT mode

  const ProfileWidget({
    super.key,
    required this.mode,
    this.initial,
  });

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

  String? _gender; // M / F / O
  bool _loading = false;

  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    if (widget.mode == ProfileMode.edit && widget.initial != null) {
      final p = widget.initial!;
      _patientIdCtrl.text = p['patientId'] ?? '';
      _firstNameCtrl.text = p['firstName'] ?? '';
      _lastNameCtrl.text = p['lastName'] ?? '';
      _gender = _toCode(p['gender']);
      _ageCtrl.text = p['age']?.toString() ?? '';
      _mobileCtrl.text = p['mobile'] ?? '';
      _addressCtrl.text = p['address'] ?? '';
    } else {
      _patientIdCtrl.text = 'Auto-generated';
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

  @override
  void dispose() {
    _patientIdCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _ageCtrl.dispose();
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------
  // FIRESTORE - AUTO GENERATE PATIENT ID
  // -------------------------------------------------------
  Future<String> _generatePatientId() async {
    final counterRef =
        _db.collection('counters').doc('patientCounter');

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
  // VALIDATIONS — AS REQUESTED
  // -------------------------------------------------------
  String? _req(String? v, {String name = "This field"}) {
    if (v == null || v.trim().isEmpty) return "$name is required";
    return null;
  }

  String? _nameVal(String? v, {String name = "This field"}) {
    if ((v ?? '').trim().isEmpty) return "$name is required";

    final t = v!.trim();

    if (!RegExp(r'^[A-Za-z]+$').hasMatch(t)) {
      return "$name must contain only alphabets";
    }
    if (t.length < 2) return "$name must be at least 2 characters";
    if (t.length > 50) return "$name must be under 50 characters";

    return null;
  }

  String? _ageVal(String? v) {
    if (v == null || v.trim().isEmpty) return "Age is required";
    final age = int.tryParse(v.trim());
    if (age == null) return "Enter a valid number";
    if (age < 0 || age > 120) return "Age must be between 0–120";
    return null;
  }

  String? _mobileVal(String? v) {
    if ((v ?? '').trim().isEmpty) return "Mobile number is required";

    final digits = v!.trim();
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
  // ON SAVE
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
      String patientId;

      if (widget.mode == ProfileMode.create) {
        patientId = await _generatePatientId();

        if (await _checkDuplicateId(patientId)) {
          throw Exception("Duplicate Patient ID generated. Try again.");
        }
      } else {
        patientId = _patientIdCtrl.text;
      }

      final firstName = _firstNameCtrl.text.trim();
      final lastName = _lastNameCtrl.text.trim();
      final fullName = "$firstName $lastName";

      final data = {
        'patientId': patientId,
        'firstName': firstName,
        'lastName': lastName,
        'fullName': fullName,
        'gender': _fromCode(_gender!),
        'age': int.parse(_ageCtrl.text.trim()),
        'mobile': _mobileCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      if (widget.mode == ProfileMode.create) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await _db.collection('patients').doc(patientId).set(
            data,
            SetOptions(merge: true),
          );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(widget.mode == ProfileMode.create
                ? "Patient Created"
                : "Patient Updated")),
      );

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
                  Text(
                    widget.mode == ProfileMode.create
                        ? "Create Patient"
                        : "Edit Patient",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---------------------------------------------------
                  // PATIENT ID
                  // ---------------------------------------------------
                  _label("Patient ID"),
                  TextFormField(
                    controller: _patientIdCtrl,
                    readOnly: true,
                    decoration: _dec("Auto-generated"),
                  ),
                  const SizedBox(height: 16),

                  // FIRST NAME
                  _label("First Name *"),
                  TextFormField(
                    controller: _firstNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => _nameVal(v, name: "First Name"),
                    decoration: _dec("Enter first name"),
                  ),
                  const SizedBox(height: 16),

                  // LAST NAME
                  _label("Last Name *"),
                  TextFormField(
                    controller: _lastNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => _nameVal(v, name: "Last Name"),
                    decoration: _dec("Enter last name"),
                  ),
                  const SizedBox(height: 16),

                  // GENDER
                  _label("Gender *"),
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: _dec("Select gender"),
                    items: const [
                      DropdownMenuItem(value: 'M', child: Text("Male")),
                      DropdownMenuItem(value: 'F', child: Text("Female")),
                      DropdownMenuItem(value: 'O', child: Text("Other")),
                    ],
                    onChanged: (v) => setState(() => _gender = v),
                    validator: (_) =>
                        _gender == null ? "Gender is required" : null,
                  ),
                  const SizedBox(height: 16),

                  // AGE
                  _label("Age *"),
                  TextFormField(
                    controller: _ageCtrl,
                    validator: _ageVal,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _dec("Enter age"),
                  ),
                  const SizedBox(height: 16),

                  // MOBILE
                  _label("Mobile Number *"),
                  TextFormField(
                    controller: _mobileCtrl,
                    validator: _mobileVal,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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

                  // SAVE BUTTON
                  ElevatedButton(
                    onPressed: _loading ? null : _onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : Text(
                            widget.mode == ProfileMode.create
                                ? "Create"
                                : "Save Changes",
                            style:
                                const TextStyle(fontWeight: FontWeight.w700),
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