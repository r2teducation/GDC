import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PatientRegisterWidget extends StatefulWidget {
  const PatientRegisterWidget({super.key});

  @override
  State<PatientRegisterWidget> createState() => _PatientRegisterWidgetState();
}

class _PatientRegisterWidgetState extends State<PatientRegisterWidget> {
  final _formKey = GlobalKey<FormState>();

  final _patientIdCtrl = TextEditingController(text: 'Auto-generated');
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // referred by (moved from Visits)
  String? _referredBy; // D / P / O / X

  final TextEditingController _searchCtrl =
      TextEditingController(); // unused but kept if needed
  String? _gender; // M / F / O

  bool _loading = false;

  final _db = FirebaseFirestore.instance;

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

  // ---------------------------
  // Helpers / Validations
  // ---------------------------
  String? _req(String? v, {String name = "This field"}) {
    if (v == null || v.trim().isEmpty) return "$name is required";
    return null;
  }

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

  // gender helpers
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

  // ---------------------------
  // Firestore helpers
  // ---------------------------
  Future<String> _generatePatientId() async {
    final counterRef = _db.collection('counters').doc('patientCounter');

    return await _db.runTransaction((tx) async {
      final snap = await tx.get(counterRef);
      int last = snap.exists ? (snap['lastNumber'] as int) : 0;
      int newNum = last + 1;
      tx.update(counterRef, {'lastNumber': newNum});
      return "P-${newNum.toString().padLeft(5, '0')}";
    });
  }

  Future<bool> _checkDuplicateId(String patientId) async {
    final doc = await _db.collection('patients').doc(patientId).get();
    return doc.exists;
  }

  Future<String?> _findDuplicateComposite(
    String firstName,
    String lastName,
    String mobileFormatted,
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
    return snap.docs.first.id;
  }

  // ---------------------------
  // Save (create)
  // ---------------------------
  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select gender")),
      );
      return;
    }
    if (_referredBy == null || _referredBy!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Referred By")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final firstName = _firstNameCtrl.text.trim();
      final lastName = _lastNameCtrl.text.trim();
      final mobileFormatted = _mobileCtrl.text;
      final mobileRaw = mobileFormatted.replaceAll(' ', '').trim();

      if (!RegExp(r'^[0-9]{10}$').hasMatch(mobileRaw)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Enter a valid 10-digit number")),
        );
        setState(() => _loading = false);
        return;
      }

      final compositeKey =
          '${firstName.toLowerCase()}|${lastName.toLowerCase()}|$mobileRaw';

      final dupId =
          await _findDuplicateComposite(firstName, lastName, mobileFormatted);

      if (dupId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Patient already exists with ID $dupId (same name & mobile)')),
        );
        setState(() => _loading = false);
        return;
      }

      String patientId = await _generatePatientId();
      if (await _checkDuplicateId(patientId)) {
        throw Exception("Duplicate Patient ID generated. Try again.");
      }

      final fullName = "$firstName $lastName";

      final data = {
        'patientId': patientId,
        'firstName': firstName,
        'lastName': lastName,
        'fullName': fullName,
        'gender': _fromCode(_gender!),
        'age': int.parse(_ageCtrl.text.trim()),
        'mobile': mobileRaw,
        'address': _addressCtrl.text.trim(),
        'referredBy': _referredBy,
        'compositeKey': compositeKey,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await _db
          .collection('patients')
          .doc(patientId)
          .set(data, SetOptions(merge: true));

      // show success and set patient id in the form
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient Created')),
      );

      setState(() {
        _patientIdCtrl.text = patientId;
      });

      // optionally clear form but keep the id visible — here we keep fields
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------
  // UI helpers
  // ---------------------------
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
                    "Register Patient",
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
                      _label("Patient ID"),
                      TextFormField(
                        controller: _patientIdCtrl,
                        readOnly: true,
                        decoration: _dec("Auto-generated"),
                      ),
                      const SizedBox(height: 16),
                      _label("First Name *"),
                      TextFormField(
                        controller: _firstNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => _nameVal(v, name: "First Name"),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z ]')),
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
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z ]')),
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
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
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
                          if (v == null || v.isEmpty) {
                            return "Referred By is required";
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
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                      ),
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

            // ============== FOOTER ==============
            SizedBox(
              height: size.height * 0.08,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 32, // 👈 same as TemplateWidget
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end, // 👈 key change
                  children: [
                    InkWell(
                      onTap: _loading ? null : _onSave,
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
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Create',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
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
}

/// Shared helpers (copy into same file or import from your shared utils)
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
