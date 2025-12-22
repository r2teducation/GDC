import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class TreatmentWidget extends StatefulWidget {
  const TreatmentWidget({super.key});

  @override
  State<TreatmentWidget> createState() => _TreatmentWidgetState();
}

class _TreatmentWidgetState extends State<TreatmentWidget> {
  final ScrollController _medicineScrollCtrl = ScrollController();

  // ---------------- Medicine Prescription ----------------
  final TextEditingController _medicineSearchCtrl = TextEditingController();
  String _medicineSearch = '';

  bool _loadingMedicines = false;
  List<Map<String, dynamic>> _medicineStock = [];
  List<Map<String, dynamic>> _medicineCart = [];

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

  // ---------------- Problems ----------------
  final List<_ProblemRow> _problems = [];

  // ---------------- Doctor Notes ----------------
  final TextEditingController _doctorNotesCtrl = TextEditingController();

  // ---------------- Treatment Amount ----------------
  final TextEditingController _treatmentAmountCtrl = TextEditingController();

  // ---------------- Patient Health Snapshot ----------------
  Map<String, dynamic>? _patientHealthSnapshot;
  bool _loadingHealthSnapshot = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPatientsForDropdown();
    _loadMedicines(); // 👈 ADD

    _medicineSearchCtrl.addListener(() {
      setState(() {
        _medicineSearch = _medicineSearchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _doctorNotesCtrl.dispose();
    _treatmentAmountCtrl.dispose();
    _medicineSearchCtrl.dispose(); // 👈 ADD
    _medicineScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMedicines() async {
    setState(() => _loadingMedicines = true);

    final snap = await _db.collection('medicines').get();
    _medicineStock = snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'medicineName': data['medicineName'],
        'availableQty': data['quantityPurchased'],
      };
    }).toList();

    setState(() => _loadingMedicines = false);
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Widget _buildMedicineStock() {
    if (_loadingMedicines) {
      return const LinearProgressIndicator();
    }

    final filtered = _medicineStock.where((m) {
      final name = (m['medicineName'] ?? '').toString().toLowerCase();
      return _medicineSearch.isEmpty || name.contains(_medicineSearch);
    }).toList();

    const double rowHeight = 56;
    final double maxHeight =
        filtered.length > 3 ? rowHeight * 3 : filtered.length * rowHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Medicine Stock'),
        const SizedBox(height: 8),

        // 🔍 Search
        TextField(
          controller: _medicineSearchCtrl,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search, size: 18),
            hintText: 'Search medicine',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        const SizedBox(height: 16),

        _tableHeader(const [
          ('S.No', 40),
          ('Medicine Name', null),
          ('Availability', 120),
          ('', 80),
        ]),

        const SizedBox(height: 6),

        SizedBox(
          height: maxHeight,
          child: Scrollbar(
            controller: _medicineScrollCtrl, // ✅ REQUIRED
            thumbVisibility: true,
            child: ListView.builder(
              controller: _medicineScrollCtrl, // ✅ REQUIRED
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final m = filtered[index];
                final available = m['availableQty'] ?? 0;

                return _tableRow(children: [
                  SizedBox(width: 40, child: Text('${index + 1}')),
                  Expanded(child: Text(m['medicineName'])),
                  SizedBox(width: 120, child: Text('$available')),
                  SizedBox(
                    width: 80,
                    child: TextButton(
                      onPressed: () => setState(() => _addToCart(m)),
                      child: const Text('Add'),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableHeader(List<(String, double?)> columns) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Row(
        children: columns.map((c) {
          return c.$2 == null
              ? Expanded(
                  child: Text(c.$1,
                      style: const TextStyle(fontWeight: FontWeight.w600)))
              : SizedBox(
                  width: c.$2!,
                  child: Text(c.$1,
                      style: const TextStyle(fontWeight: FontWeight.w600)));
        }).toList(),
      ),
    );
  }

  Widget _tableRow({required List<Widget> children}) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(children: children),
    );
  }

  void _addToCart(Map<String, dynamic> m) {
    final index = _medicineCart.indexWhere((e) => e['medicineId'] == m['id']);

    if (index >= 0) {
      _medicineCart[index]['quantity'] += 1;
    } else {
      _medicineCart.add({
        'medicineId': m['id'],
        'medicineName': m['medicineName'],
        'quantity': 1,
        'price': null,
      });
    }
    setState(() {});
  }

  Widget _buildMedicineCart(void Function(void Function()) setDialogState) {
    if (_medicineCart.isEmpty) return const SizedBox();

    const double rowHeight = 56;
    final double maxHeight = _medicineCart.length > 3
        ? rowHeight * 3
        : _medicineCart.length * rowHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Medicine Cart'),
        _tableHeader(const [
          ('S.No', 40),
          ('Medicine Name', null),
          ('Quantity', 140),
          ('', 60),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          height: maxHeight,
          child: ListView.builder(
            itemCount: _medicineCart.length,
            itemBuilder: (context, index) {
              final c = _medicineCart[index];

              return _tableRow(children: [
                SizedBox(width: 40, child: Text('${index + 1}')),
                Expanded(child: Text(c['medicineName'])),

                /// ➖ ➕ Quantity (FIXED)
                SizedBox(
                  width: 140,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: c['quantity'] > 1
                            ? () {
                                setDialogState(() {
                                  c['quantity']--;
                                });
                              }
                            : null,
                      ),
                      Text(
                        '${c['quantity']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () {
                          setDialogState(() {
                            c['quantity']++;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                /// ❌ Remove
                SizedBox(
                  width: 60,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setDialogState(() {
                        _medicineCart.removeAt(index);
                      });
                    },
                  ),
                ),
              ]);
            },
          ),
        ),
      ],
    );
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
    } catch (e) {
      setState(() => _loadingPatients = false);
    }
  }

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
      // silently ignore
    } finally {
      if (mounted) setState(() => _loadingHealthSnapshot = false);
    }
  }

  // ======================================================
  // Date picker
  // ======================================================
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Widget _patientHealthPanel() {
    if (_loadingHealthSnapshot) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }

    if (_patientHealthSnapshot == null) return const SizedBox.shrink();

    final data = _patientHealthSnapshot!;
    final vitals = Map<String, dynamic>.from(data['vitals'] ?? {});
    final health = Map<String, dynamic>.from(data['healthConditions'] ?? {});
    final allergies = Map<String, dynamic>.from(data['allergies'] ?? {});
    final dental = Map<String, dynamic>.from(data['dentalHistory'] ?? {});
    final consent = Map<String, dynamic>.from(data['consent'] ?? {});

    final Timestamp? apptTs = data['appointmentDateTime'];
    final DateTime? apptDate = apptTs != null ? apptTs.toDate() : null;

    final String apptLabel = apptDate != null
        ? DateFormat('EEEE dd-MMM-yyyy h:mm a').format(apptDate)
        : 'Unknown time';

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ===== HEADER (NON-SCROLLABLE) =====
          Text(
            'Patient Health Snapshot at $apptLabel',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          /// ===== SCROLLABLE CONTENT =====
          SizedBox(
            height: 280, // 👈 adjust as needed (250–350 works well)
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionText('Vitals', [
                    _kv('BP',
                        '${vitals['bpSystolic']} / ${vitals['bpDiastolic']}'),
                    _kv('HR', '${vitals['heartRate']}'),
                    _kv('BR', '${vitals['breathingRate']}'),
                    _kv('Ht / Wt',
                        '${vitals['heightCm']} / ${vitals['weightKg']}'),
                    _kv('BMI', '${vitals['bmi']}'),
                    _kv('FBS / RBS', '${vitals['fbs']} / ${vitals['rbs']}'),
                  ]),
                  _sectionText(
                    'Health Conditions',
                    _trueKeys(health),
                  ),
                  _sectionText('Allergies', [
                    _kv('Drug', allergies['drug'] == true ? 'Yes' : 'No'),
                    _kv('Food', allergies['food'] == true ? 'Yes' : 'No'),
                    _kv('Latex', allergies['latex'] == true ? 'Yes' : 'No'),
                    _kv('Notes', allergies['notes'] ?? '--'),
                  ]),
                  _sectionText(
                    'Dental History',
                    [
                      ..._trueKeys(dental['conditions'] ?? {}),
                      _kv('Notes', dental['notes'] ?? '--'),
                    ],
                  ),
                  _sectionText(
                    'Consent',
                    [
                      Text(
                        consent['given'] == true
                            ? 'Consent Given'
                            : 'Not Given',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: consent['given'] == true
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionText(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              key,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Text(' : '),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  List<Widget> _trueKeys(Map<dynamic, dynamic> map) {
    final keys =
        map.entries.where((e) => e.value == true).map((e) => e.key).toList();
    if (keys.isEmpty) {
      return const [
        Text('None', style: TextStyle(color: Colors.grey)),
      ];
    }
    return keys.map((e) => Text('• $e')).toList();
  }

  // ======================================================
  // Add Problem Dialog (WORKING VERSION)
  // ======================================================
  final Map<int, Map<String, TextEditingController>> rctInputs = {};
  void _openAddProblemDialog() {
    final Set<int> selectedTeeth = {};
    String? problemType;
    final TextEditingController notesCtrl = TextEditingController();

    List<String> _getCanalsForTooth(int tooth) {
      if ([11, 21, 31, 41, 12, 22, 32, 42, 13, 23, 33, 43].contains(tooth)) {
        return ['Single'];
      }
      if ([14, 24, 15, 25].contains(tooth)) {
        return ['Buccal', 'Palatal'];
      }
      if ([34, 44, 35, 45].contains(tooth)) {
        return ['Buccal', 'Lingual'];
      }
      if ([16, 26, 17, 27, 18, 28].contains(tooth)) {
        return ['Palatal', 'Mesial', 'Distal'];
      }
      if ([36, 46, 37, 47, 38, 48].contains(tooth)) {
        return ['Mesial', 'Distal', 'Lingual', 'Distal 2'];
      }
      return [];
    }

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          Widget toothBox(int number) {
            final selected = selectedTeeth.contains(number);
            return InkWell(
              onTap: () {
                setStateDialog(() {
                  if (selected) {
                    selectedTeeth.remove(number);
                    rctInputs.remove(number);
                  } else {
                    selectedTeeth.add(number);
                    if (problemType == 'Root Canal') {
                      final canals = _getCanalsForTooth(number);
                      rctInputs[number] = {
                        for (final c in canals) c: TextEditingController()
                      };
                    }
                  }
                });
              },
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF0EA5A4) : Colors.white,
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.black,
                  ),
                ),
              ),
            );
          }

          Widget quadrant(String title, List<int> teeth) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 6),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 8,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  physics: const NeverScrollableScrollPhysics(),
                  children: teeth.map(toothBox).toList(),
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Add Problem'),
            content: SizedBox(
              width: 760,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: quadrant('Upper Left',
                                [18, 17, 16, 15, 14, 13, 12, 11])),
                        const SizedBox(width: 16),
                        Expanded(
                            child: quadrant('Upper Right',
                                [21, 22, 23, 24, 25, 26, 27, 28])),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: quadrant('Lower Left',
                                [48, 47, 46, 45, 44, 43, 42, 41])),
                        const SizedBox(width: 16),
                        Expanded(
                            child: quadrant('Lower Right',
                                [31, 32, 33, 34, 35, 36, 37, 38])),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField2<String>(
                      decoration: _dec('Type of problem'),
                      items: const [
                        'Root Canal',
                        'Implants',
                        'Crowns/Bridges',
                        'Braces',
                        'Dentures'
                      ]
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => problemType = v,
                    ),
                    if (problemType == 'Root Canal' && selectedTeeth.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: selectedTeeth.map((tooth) {
                          final canals = rctInputs[tooth]!;
                          final fields = [
                            ...canals.entries.map((entry) {
                              return TextFormField(
                                controller: entry.value,
                                decoration: _dec('${entry.key} (mm)'),
                                keyboardType: TextInputType.number,
                              );
                            }),

                            // 👇 ADD THIS
                            TextFormField(
                              decoration: _dec('Others (mm / notes)'),
                            ),
                          ];
                          if (canals == null) return const SizedBox();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              Text(
                                'Tooth $tooth – Canal Lengths',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              GridView.count(
                                shrinkWrap: true,
                                crossAxisCount: 3,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                physics: const NeverScrollableScrollPhysics(),
                                childAspectRatio: 3.2,
                                children: fields,
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: _dec('Notes'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close')),
              ElevatedButton(
                onPressed: () {
                  if (selectedTeeth.isEmpty || problemType == null) return;
                  setState(() {
                    _problems.add(_ProblemRow(
                      teeth: selectedTeeth.toList()..sort(),
                      type: problemType!,
                      notes: notesCtrl.text.trim(),
                    ));
                  });
                  Navigator.pop(context);
                },
                child: const Text('Add'),
              ),
            ],
          );
        });
      },
    );
  }

  // ======================================================
  // Save
  // ======================================================
  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (_selectedPatientId == null || _selectedPatientId!.isEmpty) {
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
        'treatmentAmount': double.parse(_treatmentAmountCtrl.text),
        'doctorNotes': _doctorNotesCtrl.text.trim(),

        'problems': _problems
            .map((p) => {
                  'teeth': p.teeth,
                  'type': p.type,
                  'notes': p.notes,
                })
            .toList(),

        // 🧾 Medicine Prescription
        'prescribedMedicinesCart': _medicineCart
            .map((m) => {
                  'medicineId': m['medicineId'],
                  'medicineName': m['medicineName'],
                  'quantity': m['quantity'],
                })
            .toList(),

        'cartFulfilled': false, // 👈 IMPORTANT FLAG
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Treatment saved successfully')),
      );

      _clearForm();
    } catch (e) {
      if (!mounted) return;
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
      _treatmentAmountCtrl.clear();

      _medicineSearchCtrl.clear();
      _medicineCart.clear();
      _medicineStock.clear();
      _medicineSearch = '';

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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _buildPatientOptionRow(_PatientOption p) {
    final parts = p.label.split(RegExp(r'\s{2,}'));
    return Row(
      children: [
        Text(parts.first, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(parts.length > 1 ? parts.last : '',
                overflow: TextOverflow.ellipsis)),
      ],
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

          // Patient search + date
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField2<String>(
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
                  onChanged: _onPatientSelected,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return "Please select a patient";
                    }
                    return null;
                  },

                  // ✅ THIS MAKES THE DROPDOWN LOOK CLEAN & CURVED
                  dropdownStyleData: DropdownStyleData(
                    maxHeight: 280,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    scrollbarTheme: ScrollbarThemeData(
                      radius: const Radius.circular(12),
                      thickness: MaterialStateProperty.all(4),
                      thumbVisibility: MaterialStateProperty.all(true),
                    ),
                  ),

                  // ✅ COMPACT ROW HEIGHT (VERY IMPORTANT)
                  menuItemStyleData: const MenuItemStyleData(
                    height: 44,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),

                  // ✅ SEARCH BOX INSIDE DROPDOWN
                  dropdownSearchData: DropdownSearchData(
                    searchController: _searchCtrl,
                    searchInnerWidgetHeight: 56,
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
                              horizontal: 12, vertical: 12),
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
                        orElse: () => _PatientOption(id: value, label: value),
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
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _pickDate,
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
            onPressed: _openAddProblemDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Problem'),
          ),

          // 💰 Treatment Amount
          _sectionHeader('Treatment Amount'),
          TextFormField(
            controller: _treatmentAmountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d+\.?\d{0,2}'),
              ),
            ],
            decoration: _dec('Enter amount'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please enter treatment amount';
              }
              final val = double.tryParse(v);
              if (val == null || val <= 0) {
                return 'Enter a valid amount';
              }
              return null;
            },
          ),

          // 💊 Medicine Prescription
          _sectionHeader('Medicine Prescription'),
          _buildMedicinePrescriptionTable(),

          ElevatedButton.icon(
            onPressed: _openAddMedicineDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Medicines'),
          ),

// 📝 Doctor Notes
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

  void _openAddMedicineDialog() {
    final TextEditingController dialogSearchCtrl = TextEditingController();
    String dialogSearch = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Medicines'),
              content: SizedBox(
                width: 760,
                height: 520, // 🔥 BOUNDED HEIGHT (prevents overflow)
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// 🔍 SEARCH
                      TextField(
                        controller: dialogSearchCtrl,
                        onChanged: (v) {
                          setDialogState(() {
                            dialogSearch = v.trim().toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 18),
                          hintText: 'Search medicine',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      /// 📦 STOCK
                      _buildMedicineStockForDialog(
                        dialogSearch,
                        setDialogState, // 🔥 PASS DIALOG STATE
                      ),

                      const SizedBox(height: 16),

                      /// 🛒 CART (NOW INSTANT)
                      if (_medicineCart.isNotEmpty)
                        _buildMedicineCart(setDialogState),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    dialogSearchCtrl.dispose();
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () {
                    dialogSearchCtrl.dispose();
                    setState(() {}); // 🔥 refresh summary card
                    Navigator.pop(context);
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMedicinePrescriptionTable() {
    if (_medicineCart.isEmpty) {
      return const Text(
        'No medicines prescribed',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🧾 Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  'S.No',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Text(
                  'Medicine Name',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  'Qty',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // 📋 Table Rows
        ...List.generate(_medicineCart.length, (index) {
          final m = _medicineCart[index];

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text('${index + 1}'),
                ),
                Expanded(
                  child: Text(
                    m['medicineName'],
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '${m['quantity']}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMedicineStockForDialog(
    String search,
    void Function(void Function()) setDialogState,
  ) {
    final filtered = _medicineStock.where((m) {
      final name = (m['medicineName'] ?? '').toString().toLowerCase();
      return search.isEmpty || name.contains(search);
    }).toList();

    const double rowHeight = 56;
    final double maxHeight =
        filtered.length > 3 ? rowHeight * 3 : filtered.length * rowHeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Medicine Stock'),
        _tableHeader(const [
          ('S.No', 40),
          ('Medicine Name', null),
          ('Availability', 120),
          ('', 80),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          height: maxHeight,
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final m = filtered[index];

              return _tableRow(children: [
                SizedBox(width: 40, child: Text('${index + 1}')),
                Expanded(child: Text(m['medicineName'])),
                SizedBox(width: 120, child: Text('${m['availableQty']}')),
                SizedBox(
                  width: 80,
                  child: TextButton(
                    onPressed: () {
                      setDialogState(() {
                        _addToCart(m); // 🔥 CART UPDATES INSTANTLY
                      });
                    },
                    child: const Text('Add'),
                  ),
                ),
              ]);
            },
          ),
        ),
      ],
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
