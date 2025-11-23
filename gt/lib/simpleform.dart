import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SimpleFormWidget extends StatefulWidget {
  const SimpleFormWidget({super.key});

  @override
  State<SimpleFormWidget> createState() => _SimpleFormWidgetState();
}

class _SimpleFormWidgetState extends State<SimpleFormWidget> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  DateTime? _dob;
  String? _gender;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint, {Widget? suffixIcon}) {
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
      suffixIcon: suffixIcon,
    );
  }

  String? _req(String? v, {String name = 'This field'}) {
    if (v == null || v.trim().isEmpty) return '$name is required';
    return null;
  }

  String? _emailVal(String? v) {
    final base = _req(v, name: 'E-mail Address');
    if (base != null) return base;
    final re = RegExp(r'^[\w\.\-+]+@[\w\-]+\.[\w\.\-]+$');
    if (!re.hasMatch(v!.trim())) return 'Enter a valid email address';
    return null;
  }

  String? _phoneVal(String? v) {
    final base = _req(v, name: 'Phone Number');
    if (base != null) return base;
    final digits = v!.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return 'Enter a 10-digit phone number';
    return null;
  }

  String _fmtDate(DateTime d) {
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 20, now.month, now.day);
    final first = DateTime(now.year - 120, 1, 1);
    final last = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
                  primary: const Color(0xFFDC2626),
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobCtrl.text = _fmtDate(picked);
      });
    }
  }

  String? _dobVal(String? v) {
    final base = _req(v, name: 'Date of Birth');
    if (base != null) return base;
    if (_dob == null) return 'Please pick your date of birth';
    if (_dob!.isAfter(DateTime.now())) return 'DOB cannot be in the future';
    return null;
  }

  void _onSave() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved successfully')),
      );
      // TODO: Use the values as needed
      // print({
      //   'name': _nameCtrl.text,
      //   'email': _emailCtrl.text,
      //   'phone': _phoneCtrl.text,
      //   'dob': _dobCtrl.text,
      //   'gender': _gender,
      // });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, __) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Container(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 40),
              decoration: BoxDecoration(
                color: Colors.white, // white card
                borderRadius: BorderRadius.circular(24), // smooth curves
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
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Fields remain the same...
                    const _FieldLabel('Full Name *'),
                    TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: _dec('John Doe'),
                      validator: (v) {
                        final base = _req(v, name: 'Full Name');
                        if (base != null) return base;
                        if (v!.trim().length < 2) return 'Enter a valid name';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    const _FieldLabel('E-mail Address *'),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: _dec('your_email@example.com'),
                      validator: _emailVal,
                    ),
                    const SizedBox(height: 16),

                    const _FieldLabel('Phone Number *'),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _UsPhoneNumberFormatter(),
                      ],
                      decoration: _dec('(___) ___-____'),
                      validator: _phoneVal,
                    ),
                    const SizedBox(height: 16),

                    const _FieldLabel('Date of Birth *'),
                    TextFormField(
                      controller: _dobCtrl,
                      readOnly: true,
                      onTap: _pickDob,
                      decoration: _dec('__ / __ / ____',
                          suffixIcon: IconButton(
                            onPressed: _pickDob,
                            icon: const Icon(Icons.calendar_today_outlined),
                          )),
                      validator: _dobVal,
                    ),
                    const SizedBox(height: 16),

                    const _FieldLabel('Gender *'),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                            value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                        DropdownMenuItem(
                            value: 'Prefer not to say',
                            child: Text('Prefer not to say')),
                      ],
                      onChanged: (v) => setState(() => _gender = v),
                      decoration: _dec(''),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Please select gender'
                          : null,
                    ),
                    const SizedBox(height: 32),

                    // Save button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                        onPressed: _onSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save',
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
      ),
    );
  }
}

/// Label text above each control (matches the screenshot style)
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
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
  }
}

/// Simple (###) ###-#### formatter for the phone field
class _UsPhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    int i = 0;
    if (digits.isNotEmpty) {
      buf.write('(');
      for (; i < digits.length && i < 3; i++) {
        buf.write(digits[i]);
      }
      if (digits.length >= 3) buf.write(') ');
    }
    if (digits.length > 3) {
      for (; i < digits.length && i < 6; i++) {
        buf.write(digits[i]);
      }
      if (digits.length >= 6) buf.write('-');
    }
    if (digits.length > 6) {
      for (; i < digits.length && i < 10; i++) {
        buf.write(digits[i]);
      }
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
