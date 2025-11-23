import 'package:flutter/material.dart';

class MultiLevelFormWidget extends StatefulWidget {
  const MultiLevelFormWidget({super.key});

  @override
  State<MultiLevelFormWidget> createState() => _MultiLevelFormWidgetState();
}

class _MultiLevelFormWidgetState extends State<MultiLevelFormWidget> {
  static const List<String> _stepTitles = [
    'Personal Information',
    'Trip Information',
    'Coverage Options',
    'Additional Information',
  ];

  // steps: 0 Personal, 1 Trip, 2 Coverage, 3 Additional
  int step = 0;

  final _formKeys = List.generate(4, (_) => GlobalKey<FormState>());

  // Step 0 controllers
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _dobCtrl = TextEditingController();
  DateTime? _dob;
  String? _gender;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  // Palette (matching screenshot #2)
  static const _accentRed = Color(0xFFDC2626); // progress + Next button
  static const _barGray = Color(0xFFE5E7EB);
  static const _titleColor = Color(0xFF111827);
  static const _fieldFill = Color(0xFFFAFAFA); // soft fill
  static const _fieldBorder = Color(0xFFE5E7EB);
  static const _hint = Color(0xFF9CA3AF);

  void _next() {
    final key = _formKeys[step];
    if (key.currentState?.validate() ?? true) {
      if (step < 3) setState(() => step++);
    }
  }

  void _back() {
    if (step > 0) setState(() => step--);
  }

  // Scoped field theme to match screenshot #2
  ThemeData _fieldTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: _fieldFill,
        hintStyle: TextStyle(color: _hint),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _fieldBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _fieldBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _accentRed, width: 1.2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // STEP HEADER (tabs + progress line)
          _StepTabs(
            step: step,
            labels: const [
              'Personal\nInformation',
              'Trip\nInformation',
              'Coverage\nOptions',
              'Additional\nInformation',
            ],
          ),

          // CONTENT
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, 28, 40, 24),
              child: Theme(
                // <— scoped input style here
                data: _fieldTheme(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _stepTitles[step],
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: _titleColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildStep(),
                    const SizedBox(height: 24),
                    _controls(),
                    const SizedBox(height: 24),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: const [
                          Text(
                            "Stuck on the form? ",
                            style: TextStyle(color: Color(0xFF6B7280)),
                          ),
                          Text(
                            "Let's call you!",
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                              color: _titleColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // region: step bodies
  Widget _buildStep() {
    switch (step) {
      case 0:
        return Form(
          key: _formKeys[0],
          child: Column(
            children: [
              _LabeledField(
                label: 'Full Name *',
                child: TextFormField(
                  controller: _fullName,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                  decoration: const InputDecoration(hintText: 'John Doe'),
                ),
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'E-mail Address *',
                child: TextFormField(
                  controller: _email,
                  validator: (v) =>
                      (v == null || !RegExp(r'.+@.+\..+').hasMatch(v))
                          ? 'Enter a valid email'
                          : null,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'your_email@example.com',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Phone Number *',
                child: TextFormField(
                  controller: _phone,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '(___) ___-____',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Date of Birth *',
                child: TextFormField(
                  controller: _dobCtrl,
                  readOnly: true,
                  validator: (_) => _dob == null ? 'Select date' : null,
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(now.year - 18, now.month, now.day),
                      firstDate: DateTime(1900),
                      lastDate: now,
                    );
                    if (picked != null) {
                      _dob = picked;
                      _dobCtrl.text =
                          '${picked.day.toString().padLeft(2, '0')}/'
                          '${picked.month.toString().padLeft(2, '0')}/'
                          '${picked.year}';
                      setState(() {});
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: '__/__/____',
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _LabeledField(
                label: 'Gender *',
                child: DropdownButtonFormField<String>(
                  value: _gender,
                  items: const [
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  validator: (v) => v == null ? 'Required' : null,
                  onChanged: (v) => setState(() => _gender = v),
                  decoration: const InputDecoration(), // uses scoped theme
                  icon: const Icon(Icons.expand_more),
                ),
              ),
            ],
          ),
        );

      case 1:
        return Form(
          key: _formKeys[1],
          child: Column(
            children: const [
              _LabeledField(
                label: 'From *',
                child: TextField(
                  decoration: InputDecoration(hintText: 'City / Airport'),
                ),
              ),
              SizedBox(height: 14),
              _LabeledField(
                label: 'To *',
                child: TextField(
                  decoration: InputDecoration(hintText: 'City / Airport'),
                ),
              ),
              SizedBox(height: 14),
              _LabeledField(
                label: 'Travel Dates *',
                child: TextField(
                  decoration:
                      InputDecoration(hintText: 'DD/MM/YYYY - DD/MM/YYYY'),
                ),
              ),
            ],
          ),
        );

      case 2:
        return Form(
          key: _formKeys[2],
          child: Column(
            children: const [
              _LabeledField(
                label: 'Plan *',
                child: TextField(
                    decoration:
                        InputDecoration(hintText: 'Standard / Premium')),
              ),
              SizedBox(height: 14),
              _LabeledField(
                label: 'Extras',
                child: TextField(
                    decoration:
                        InputDecoration(hintText: 'Baggage, Delay, etc.')),
              ),
            ],
          ),
        );

      default:
        return Form(
          key: _formKeys[3],
          child: Column(
            children: const [
              _LabeledField(
                label: 'Notes',
                child: TextField(maxLines: 3),
              ),
              SizedBox(height: 14),
              _LabeledField(
                label: 'Referral Code',
                child: TextField(),
              ),
            ],
          ),
        );
    }
  }
  // endregion

  Widget _controls() {
    return Row(
      children: [
        // Back
        TextButton.icon(
          onPressed: step == 0 ? null : _back,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Back'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF6B7280),
            disabledForegroundColor: const Color(0xFF9CA3AF),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            backgroundColor: const Color(0xFFF3F4F6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 16),
        // Next
        ElevatedButton.icon(
          onPressed: _next,
          icon: const Icon(Icons.chevron_right),
          label: Text(step == 3 ? 'Finish' : 'Next'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}

// ---------- Helpers ----------

class _StepTabs extends StatelessWidget {
  final int step;
  final List<String> labels;
  const _StepTabs({required this.step, required this.labels});

  static const _accentRed = Color(0xFFDC2626);
  static const _barGray = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _barGray)),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i <= step;
          return Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Opacity(
                  opacity: active ? 1 : 0.45,
                  child: Text(
                    labels[i],
                    maxLines: 2,
                    style: TextStyle(
                      height: 1.25,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: active ? _accentRed : _barGray,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
