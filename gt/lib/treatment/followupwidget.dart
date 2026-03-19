import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gt/homelayout.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gt/homelayout.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:dropdown_search/dropdown_search.dart';

import 'dart:ui' as ui; // required for HtmlElementView

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// ignore: uri_does_not_exist
import 'dart:ui_web' as ui_web;

class FollowUpWidget extends StatefulWidget {
  const FollowUpWidget({super.key});

  @override
  State<FollowUpWidget> createState() => _FollowUpWidgetState();
}

class _FollowUpWidgetState extends State<FollowUpWidget> {
  // ---------------- New Problems ----------------
  final List<_ProblemRow> _newProblems = [];
  static const Color _tableBorder = Color(0xFFD1D5DB); // grey-300
  static const Color _tableBg = Color(0xFFF3F4F6); // grey-100
  static const Color _tableHeaderBg = Color(0xFF111827); // black
  static const Color _tableHeaderText = Colors.white;

// ---------------- Scans ----------------
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _selectedScans = [];
  bool _uploadingScans = false;

  // ---------------- Medicine Prescription ----------------
  final TextEditingController _medicineSearchCtrl = TextEditingController();
  String _medicineSearch = '';
  List<dynamic>? _chiefComplaintMedicines;

  bool _loadingMedicines = false;
  List<Map<String, dynamic>> _medicineStock = [];
  List<Map<String, dynamic>> _medicineCart = [];

  final ButtonStyle _blackActionButtonStyle = ElevatedButton.styleFrom(
    backgroundColor:
        const Color(0xFF111827), // pure black used in header/footer
    foregroundColor: Colors.white, // text + icon
    elevation: 0, // flat, modern
  );

  final Set<String> _registeredViews = {};
  String? _chiefComplaintDoctorNotes;
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;

  // ---------------- Scans ----------------
  List<Map<String, dynamic>> _treatmentScans = [];
  bool _loadingScans = false;

  static const Color _readOnlyText = Color(0xFF6B7280); // slate-500
  static const Color _readOnlyHeading = Color(0xFF4B5563); // slate-600
  static const Color _readOnlyDivider = Color(0xFFE5E7EB); // light grey

  // ---------------- Chief Complaint Snapshot ----------------
  List<Map<String, dynamic>> _chiefComplaintSnapshot = [];
  bool _loadingChiefComplaint = false;

  // ---------------- Date ----------------
  DateTime _selectedDate = DateTime.now();
  final DateFormat _displayDate = DateFormat('yyyy-MM-dd');

  bool _loadingPatients = true;
  List<_PatientOption> _patientOptions = [];
  String? _selectedPatientId;
  String? _chiefComplaintApptLabel;

  // ---------------- Doctor Notes ----------------
  final TextEditingController _doctorNotesCtrl = TextEditingController();

  // ---------------- Patient Health Snapshot ----------------
  Map<String, dynamic>? _patientHealthSnapshot;
  bool _loadingHealthSnapshot = false;

  // ---------------- Previous Follow Ups ----------------
  List<Map<String, dynamic>> _previousFollowUps = [];
  bool _loadingFollowUps = false;

  bool _saving = false;

  int _getAvailableQty(String medicineId) {
    final stock = _medicineStock.firstWhere(
      (m) => m['id'] == medicineId,
      orElse: () => {},
    );

    return stock['availableQty'] ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _loadPatientsForDropdown();
    _loadMedicines(); // 👈 ADD
  }

  @override
  void dispose() {
    _doctorNotesCtrl.dispose();
    super.dispose();
  }

  void _openAddProblemDialog() {
    final dialogState = AddProblemDialogState();
    final TextEditingController notesCtrl = TextEditingController();

    final maxWidth = MediaQuery.of(context).size.width * 0.9;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    showDialog(
      context: context,
      builder: (dctx) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
              child: StatefulBuilder(
                builder: (context, setStateDialog) {
                  Widget toothBox(int number) {
                    final selected = dialogState.selectedTeeth.contains(number);
                    return InkWell(
                      onTap: () {
                        setStateDialog(() {
                          dialogState.toggleTooth(number);
                        });
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              selected ? const Color(0xFF0EA5A4) : Colors.white,
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

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ================= HEADER =================
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Add Problem',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                onPressed: () {
                                  Navigator.of(dctx).pop();

                                  // Dispose AFTER dialog is fully removed
                                  Future.microtask(() {
                                    dialogState.dispose();
                                    notesCtrl.dispose();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        // ================= BODY =================
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                  isExpanded: true,
                                  decoration: _dec('Type of problem'),

                                  items: const [
                                    'Root Canal',
                                    'Implants',
                                    'Impaction',
                                    'Crowns/Bridges',
                                    'Braces',
                                    'Dentures',
                                    'Extraction',
                                    'Filling',
                                    'Scaling',
                                    'Cervical Abrasion',
                                    'Generalized Gingivitis'
                                  ]
                                      .map(
                                        (e) => DropdownMenuItem<String>(
                                          value: e,
                                          child: Text(
                                            e,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      )
                                      .toList(),

                                  onChanged: (v) {
                                    setStateDialog(() {
                                      dialogState.setProblemType(v);
                                    });
                                  },

                                  // ✅ MATCH PATIENT SEARCH DROPDOWN STYLE
                                  dropdownStyleData: DropdownStyleData(
                                    maxHeight: 260,
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
                                      thumbVisibility:
                                          MaterialStateProperty.all(true),
                                    ),
                                  ),

                                  // ✅ COMPACT, CLEAN ROW HEIGHT
                                  menuItemStyleData: const MenuItemStyleData(
                                    height: 44,
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                ),
                                if (dialogState.problemType == 'Impaction')
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Type of Impaction',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _impactionRadio(
                                            label: 'Mesio-angular',
                                            value: 'Mesio-angular',
                                            group: dialogState.impactionType,
                                            onChanged: (v) =>
                                                setStateDialog(() {
                                              dialogState.impactionType = v;
                                            }),
                                          ),
                                          _impactionRadio(
                                            label: 'Disto-angular',
                                            value: 'Disto-angular',
                                            group: dialogState.impactionType,
                                            onChanged: (v) =>
                                                setStateDialog(() {
                                              dialogState.impactionType = v;
                                            }),
                                          ),
                                          _impactionRadio(
                                            label: 'Vertical',
                                            value: 'Vertical',
                                            group: dialogState.impactionType,
                                            onChanged: (v) =>
                                                setStateDialog(() {
                                              dialogState.impactionType = v;
                                            }),
                                          ),
                                          _impactionRadio(
                                            label: 'Horizontal',
                                            value: 'Horizontal',
                                            group: dialogState.impactionType,
                                            onChanged: (v) =>
                                                setStateDialog(() {
                                              dialogState.impactionType = v;
                                            }),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                if (dialogState.problemType == 'Implants')
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 12),

                                      const Text(
                                        'Implant Type',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700),
                                      ),

                                      const SizedBox(height: 6),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: RadioListTile<String>(
                                              value: 'Basal',
                                              groupValue:
                                                  dialogState.implantType,
                                              onChanged: (v) =>
                                                  setStateDialog(() {
                                                dialogState.implantType = v;
                                              }),
                                              title: const Text('Basal',
                                                  style:
                                                      TextStyle(fontSize: 13)),
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                          Expanded(
                                            child: RadioListTile<String>(
                                              value: 'Conventional',
                                              groupValue:
                                                  dialogState.implantType,
                                              onChanged: (v) =>
                                                  setStateDialog(() {
                                                dialogState.implantType = v;
                                              }),
                                              title: const Text('Conventional',
                                                  style:
                                                      TextStyle(fontSize: 13)),
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),

                                      // ───────── Implant Grid (2 rows × 3 columns) ─────────
                                      Column(
                                        children: [
                                          // Row 1
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextFormField(
                                                  controller: dialogState
                                                      .implantWidthCtrl,
                                                  decoration: _dec(
                                                      'Implant Width (mm)'),
                                                  keyboardType:
                                                      TextInputType.number,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: TextFormField(
                                                  controller: dialogState
                                                      .implantLengthCtrl,
                                                  decoration: _dec(
                                                      'Implant Length (mm)'),
                                                  keyboardType:
                                                      TextInputType.number,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: TextFormField(
                                                  controller: dialogState
                                                      .implantCompanyCtrl,
                                                  decoration:
                                                      _dec('Implant Company'),
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 12),

                                          // Row 2
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _implantDatePicker(
                                                  label:
                                                      'Healing Cap Placement',
                                                  icon: Icons.calendar_today,
                                                  date: dialogState
                                                      .healingCapDate,
                                                  onPick: (d) => setStateDialog(
                                                      () => dialogState
                                                          .healingCapDate = d),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: _implantDatePicker(
                                                  label: 'Abutment Placement',
                                                  icon: Icons.calendar_today,
                                                  date:
                                                      dialogState.abutmentDate,
                                                  onPick: (d) => setStateDialog(
                                                      () => dialogState
                                                          .abutmentDate = d),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: _implantDatePicker(
                                                  label: 'Crown Placement',
                                                  icon: Icons.calendar_today,
                                                  date: dialogState.crownDate,
                                                  onPick: (d) => setStateDialog(
                                                      () => dialogState
                                                          .crownDate = d),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                if (dialogState.problemType == 'Root Canal' &&
                                    dialogState.selectedTeeth.isNotEmpty)
                                  Column(
                                    children:
                                        dialogState.selectedTeeth.map((tooth) {
                                      final canals =
                                          dialogState.rctInputs[tooth] ?? {};
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            childAspectRatio: 3.2,
                                            children: [
                                              ...canals.entries.map(
                                                (e) => TextFormField(
                                                  controller: e.value,
                                                  decoration:
                                                      _dec('${e.key} (mm)'),
                                                  keyboardType:
                                                      TextInputType.number,
                                                ),
                                              ),
                                              TextFormField(
                                                controller: dialogState
                                                    .rctOtherInputs[tooth],
                                                decoration:
                                                    _dec('Others (mm / notes)'),
                                              ),
                                            ],
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

                        // ================= FOOTER =================
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  if (dialogState.selectedTeeth.isEmpty ||
                                      dialogState.problemType == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Please select teeth and problem type')),
                                    );
                                    return;
                                  }

                                  setState(() {
                                    String finalNotes = notesCtrl.text.trim();

                                    if (dialogState.problemType ==
                                        'Root Canal') {
                                      finalNotes =
                                          '${dialogState.buildRootCanalPrefix()}$finalNotes'
                                              .trim();
                                    }

                                    if (dialogState.problemType == 'Implants') {
                                      finalNotes =
                                          '${dialogState.buildImplantPrefix()}$finalNotes'
                                              .trim();
                                    }

                                    if (dialogState.problemType ==
                                        'Impaction') {
                                      finalNotes =
                                          '${dialogState.buildImpactionPrefix()}$finalNotes'
                                              .trim();
                                    }

                                    _newProblems.add(_ProblemRow(
                                      teeth: dialogState.selectedTeeth.toList(),
                                      type: dialogState.problemType!,
                                      notes: finalNotes,
                                    ));
                                  });

                                  dialogState.dispose();
                                  Navigator.of(dctx).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 26, vertical: 12),
                                ),
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _impactionRadio({
    required String label,
    required String value,
    required String? group,
    required ValueChanged<String> onChanged,
  }) {
    return Expanded(
      child: RadioListTile<String>(
        value: value,
        groupValue: group,
        onChanged: (v) => onChanged(v!),
        title: Text(label, style: const TextStyle(fontSize: 13)),
        dense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _implantDatePicker({
    required String label,
    required DateTime? date,
    required ValueChanged<DateTime?> onPick,
    required IconData icon,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF6B7280),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w500),
      ),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              date == null
                  ? label
                  : '${DateFormat('dd-MMM-yyyy').format(date)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTableCard({
    required String title,
    required String subtitle,
    required List<Widget> rows,
    EdgeInsets margin = const EdgeInsets.symmetric(vertical: 12), // ✅ ADD
  }) {
    return Container(
      margin: margin, // ✅ USE PARAM
      decoration: BoxDecoration(
        color: _tableBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _tableBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 🔳 HEADER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: _tableHeaderBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: _tableHeaderText, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),

          // 📄 ROWS
          ...rows,
        ],
      ),
    );
  }

  Widget _tableRowItem(
    String label,
    Widget content, {
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: _tableBorder),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _readOnlyHeading,
              ),
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _smallScanGrid(List<Map<String, dynamic>> scans) {
    if (scans.isEmpty) {
      return const Text(
        'No scans',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: scans.map((s) {
        final url = s['imageUrl'] as String?;
        if (url == null) return const SizedBox();

        return SizedBox(
          width: 72,
          height: 72,
          child: _scanThumbnail(url), // reuse your existing logic
        );
      }).toList(),
    );
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

  Widget webImage(String url) {
    final viewType = 'scan-image-${url.hashCode}';

    if (kIsWeb) {
      if (!_registeredViews.contains(viewType)) {
        ui_web.platformViewRegistry.registerViewFactory(
          viewType,
          (int viewId) {
            final img = html.ImageElement()
              ..src = url
              ..style.width = '100%'
              ..style.height = '100%'
              ..style.objectFit = 'contain'
              ..style.backgroundColor = 'black';

            return img;
          },
        );

        _registeredViews.add(viewType);
      }

      // ✅ MUST give size
      return SizedBox.expand(
        child: HtmlElementView(viewType: viewType),
      );
    }

    return Image.network(url, fit: BoxFit.contain);
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

    // Load chief complaint snapshot
  }

  Future<void> _onPatientSelected(String? v) async {
    setState(() {
      _selectedPatientId = v;

      // 🔥 RESET FOLLOW-UP FORM STATE
      _newProblems.clear(); // ✅ THIS WAS MISSING
      _doctorNotesCtrl.clear(); // optional but recommended
      _medicineCart.clear(); // optional but correct
      _selectedScans.clear(); // optional but correct

      _patientHealthSnapshot = null;
      _chiefComplaintSnapshot = [];
      _chiefComplaintDoctorNotes = null;
      _chiefComplaintApptLabel = null;
    });

    if (v == null) return;

    await _loadLatestTreatmentScans(v);

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
          _chiefComplaintSnapshot = [];
          _chiefComplaintApptLabel = null;
        });
      }
    } catch (_) {
      // silently ignore
    } finally {
      if (mounted) setState(() => _loadingHealthSnapshot = false);
    }

    setState(() => _loadingChiefComplaint = true);

    try {
      final treatSnap = await _db
          .collection('treatments')
          .where('patientId', isEqualTo: v)
          .get();

      treatSnap.docs.sort((a, b) {
        final ta = a['treatmentDate'] as Timestamp?;
        final tb = b['treatmentDate'] as Timestamp?;
        return (ta?.millisecondsSinceEpoch ?? 0)
            .compareTo(tb?.millisecondsSinceEpoch ?? 0);
      });

      if (treatSnap.docs.isNotEmpty) {
        final data = treatSnap.docs.first.data();

        final Timestamp? ts = data['treatmentDate'];
        final DateTime? dt = ts?.toDate();

        setState(() {
          final rawProblems = data['problems'];

          _chiefComplaintSnapshot = rawProblems is List
              ? List<Map<String, dynamic>>.from(rawProblems)
              : [];

          _chiefComplaintDoctorNotes =
              (data['doctorNotes'] ?? '').toString().trim();

          _chiefComplaintApptLabel = dt != null
              ? DateFormat('EEEE dd-MMM-yyyy h:mm a').format(dt)
              : 'Unknown time';

          _chiefComplaintMedicines =
              (data['prescribedMedicinesCart'] as List<dynamic>?) ?? [];
        });
      } else {
        _chiefComplaintSnapshot = [];
      }
    } catch (_) {
      _chiefComplaintSnapshot = [];
    } finally {
      if (mounted) setState(() => _loadingChiefComplaint = false);
    }

    setState(() => _loadingFollowUps = true);

    try {
      final followSnap = await _db
          .collection('followups')
          .where('patientId', isEqualTo: v)
          .orderBy('followUpDate', descending: true)
          .get();

      final List<Map<String, dynamic>> enriched = [];

      for (final doc in followSnap.docs) {
        final data = doc.data();

        final scansSnap = await doc.reference.collection('scans').get();

        data['scans'] = scansSnap.docs.map((s) => s.data()).toList();

        enriched.add(data);
      }

      setState(() {
        _previousFollowUps = enriched;
      });
    } catch (_) {
      setState(() => _previousFollowUps = []);
    } finally {
      if (mounted) setState(() => _loadingFollowUps = false);
    }
  }

  Future<void> _loadLatestTreatmentScans(String patientId) async {
    setState(() {
      _loadingScans = true;
      _treatmentScans = [];
    });

    try {
      // 1️⃣ Get latest treatment
      final treatmentSnap = await _db
          .collection('treatments')
          .where('patientId', isEqualTo: patientId)
          .orderBy('treatmentDate', descending: true)
          .limit(1)
          .get();

      if (treatmentSnap.docs.isEmpty) return;

      final treatmentDoc = treatmentSnap.docs.first;

      // 2️⃣ Get scans sub-collection
      final scansSnap = await treatmentDoc.reference.collection('scans').get();

      setState(() {
        _treatmentScans = scansSnap.docs.map((d) => d.data()).toList();
      });
    } catch (_) {
      // silent fail
    } finally {
      if (mounted) setState(() => _loadingScans = false);
    }
  }

  Widget _scansPanel() {
    if (_loadingScans) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }

    if (_treatmentScans.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No scans available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Scans',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _readOnlyHeading,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: _readOnlyDivider, thickness: 0.6),
        const SizedBox(height: 12),

        // 📸 Thumbnails grid
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 900 ? 5 : 3;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _treatmentScans.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1, // ✅ square grid cells
              ),
              itemBuilder: (context, index) {
                final scan = _treatmentScans[index];
                final imageUrl = scan['imageUrl'] as String?;

                if (imageUrl == null || imageUrl.isEmpty) {
                  return _emptyThumbnail();
                }

                return _scanThumbnail(imageUrl);
              },
            );
          },
        ),
      ],
    );
  }

  ImageProvider _networkImage(String url) {
    return NetworkImage(url);
  }

  Widget webThumbnail(String url) {
    final viewType = 'thumb-${url.hashCode}';

    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final img = html.ImageElement()
          ..src = url
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = 'cover'
          ..style.borderRadius = '12px';

        return img;
      },
    );

    return HtmlElementView(viewType: viewType);
  }

  Widget _emptyThumbnail() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey,
          size: 32,
        ),
      ),
    );
  }

  Widget _scanThumbnail(String imageUrl) {
    final safeUrl = imageUrl.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          children: [
            // 🖼️ HTML image (renders correctly)
            Positioned.fill(
              child: kIsWeb
                  ? webThumbnail(safeUrl)
                  : Image.network(
                      safeUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _emptyThumbnail(),
                    ),
            ),

            // 🟦 Invisible tap layer (CRITICAL)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openScanPreview(safeUrl),
                  splashColor: Colors.black12,
                  highlightColor: Colors.transparent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openScanPreview(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero, // 🔥 full-screen dialog
          child: Stack(
            children: [
              // ✅ Perfect center alignment
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  boundaryMargin: const EdgeInsets.all(80),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: size.width * 0.9,
                      maxHeight: size.height * 0.9,
                    ),
                    child: _previewImage(imageUrl),
                  ),
                ),
              ),

              // ❌ Close button (top-right, fixed)
              Positioned(
                top: 24,
                right: 24,
                child: InkWell(
                  onTap: () => Navigator.pop(ctx),
                  child: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String cleanUrl(String url) {
    return Uri.encodeFull(url.trim());
  }

  Widget _previewImage(String imageUrl) {
    return webImage(imageUrl);
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

  Widget _previousFollowUpsPanel() {
    if (_loadingFollowUps) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }

    if (_previousFollowUps.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16), // ✅ top = 8
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ===== HEADER (LIKE PATIENT HEALTH SNAPSHOT) =====
          const Text(
            'Previous Follow-Ups',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _readOnlyHeading,
            ),
          ),
          const SizedBox(height: 4),
          const Divider(color: _readOnlyDivider, thickness: 0.6),

          /// ===== CONTENT =====
          for (final f in _previousFollowUps) ...[
            _infoTableCard(
              title: 'Follow Up',
              subtitle: DateFormat('EEEE dd-MMM-yyyy h:mm a')
                  .format((f['followUpDate'] as Timestamp).toDate()),
              rows: [
                _tableRowItem(
                  'Problems',
                  (f['problems'] != null && (f['problems'] as List).isNotEmpty)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: (f['problems'] as List).map((p) {
                            final teeth = (p['teeth'] as List).join(', ');
                            final type = p['type'] ?? '';
                            final notes = (p['notes'] ?? '').toString().trim();

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _readOnlyText,
                                    height: 1.4,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Teeth: $teeth — $type',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    if (notes.isNotEmpty)
                                      TextSpan(text: ' — $notes'),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        )
                      : const Text(
                          'No new problems',
                          style: TextStyle(color: Colors.grey),
                        ),
                ),
                _tableRowItem(
                  'Notes',
                  Text(
                    f['doctorNotes'] ?? 'No notes',
                    style: const TextStyle(color: _readOnlyText),
                  ),
                ),
                _tableRowItem(
                  'Medicines',
                  Text(
                    (f['prescribedMedicinesCart'] != null &&
                            (f['prescribedMedicinesCart'] as List).isNotEmpty)
                        ? _formatPrescribedMedicines(
                            f['prescribedMedicinesCart'])
                        : 'No medicines prescribed',
                    style: const TextStyle(color: _readOnlyText),
                  ),
                ),
                _tableRowItem(
                  'Scans',
                  _smallScanGrid(
                    (f['scans'] as List<Map<String, dynamic>>?) ?? [],
                  ),
                  isLast: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chiefComplaintSnapshotPanel() {
    if (_loadingChiefComplaint) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }

    // Do not render anything if no patient is selected
    if (_selectedPatientId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8), // ✅ OUTER GAP = 8
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoTableCard(
            title: 'Chief Complaint',
            subtitle: _chiefComplaintApptLabel ?? '',
            margin: const EdgeInsets.symmetric(vertical: 0), // ✅ CRITICAL
            rows: [
              _tableRowItem(
                'Problems',
                _chiefComplaintSnapshot.isEmpty
                    ? const Text('No problems found',
                        style: TextStyle(color: Colors.grey))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _chiefComplaintSnapshot.map((p) {
                          final teeth =
                              (p['teeth'] as List?)?.join(', ') ?? '--';
                          final type = (p['type'] ?? 'Unknown').toString();
                          final notes = (p['notes'] ?? '').toString().trim();

                          final text = notes.isNotEmpty
                              ? 'Teeth: $teeth — $type — $notes'
                              : 'Teeth: $teeth — $type';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _readOnlyText,
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Teeth: $teeth — $type',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  if (notes.isNotEmpty)
                                    TextSpan(text: ' — $notes'),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              _tableRowItem(
                'Notes',
                Text(
                  (_chiefComplaintDoctorNotes?.isNotEmpty ?? false)
                      ? _chiefComplaintDoctorNotes!
                      : 'No notes',
                  style: const TextStyle(color: _readOnlyText),
                ),
              ),
              _tableRowItem(
                'Medicines',
                Text(
                  (_chiefComplaintMedicines?.isNotEmpty ?? false)
                      ? _formatPrescribedMedicines(_chiefComplaintMedicines)
                      : 'No medicines prescribed',
                  style: const TextStyle(color: _readOnlyText),
                ),
              ),
              _tableRowItem(
                'Scans',
                _smallScanGrid(_treatmentScans),
                isLast: true, // ✅ IMPORTANT
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _renderVitals(Map<String, dynamic> v) {
    String safe(dynamic x) => (x == null || x.toString().isEmpty) ? '--' : '$x';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BP : ${safe(v['bpSystolic'])} / ${safe(v['bpDiastolic'])}'),
        Text('HR : ${safe(v['heartRate'])}'),
        Text('BR : ${safe(v['breathingRate'])}'),
        Text('Ht / Wt : ${safe(v['heightCm'])} / ${safe(v['weightKg'])}'),
        Text('BMI : ${safe(v['bmi'])}'),
        Text('FBS / RBS : ${safe(v['fbs'])} / ${safe(v['rbs'])}'),
      ],
    );
  }

  Widget _renderKeyList(Map<dynamic, dynamic> map) {
    final keys = map.entries.where((e) => e.value == true).map((e) => e.key);

    if (keys.isEmpty) {
      return const Text('None', style: TextStyle(color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: keys.map((k) => Text('• $k')).toList(),
    );
  }

  Widget _renderAllergies(Map<String, dynamic> a) {
    String yn(bool? v) => v == true ? 'Yes' : 'No';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Drug : ${yn(a['drug'])}'),
        Text('Food : ${yn(a['food'])}'),
        Text('Latex : ${yn(a['latex'])}'),
        if ((a['notes'] ?? '').toString().isNotEmpty)
          Text('Notes : ${a['notes']}'),
      ],
    );
  }

  Widget _renderConsent(Map<String, dynamic> c) {
    final bool given = c['given'] == true;

    return Text(
      given ? 'Consent Given' : 'Consent Not Given',
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: given ? Colors.green : Colors.red,
      ),
    );
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8), // ✅ bottom = 8
      child: _infoTableCard(
        title: 'Patient Health Snapshot',
        subtitle: apptLabel,
        rows: [
          _tableRowItem(
            'Vitals',
            _renderVitals(vitals),
          ),
          _tableRowItem(
            'Health Conditions',
            _renderKeyList(health),
          ),
          _tableRowItem(
            'Allergies',
            _renderAllergies(allergies),
          ),
          _tableRowItem(
            'Dental History',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _renderKeyList(dental['conditions'] ?? {}),
                if ((dental['notes'] ?? '').toString().isNotEmpty)
                  Text('Notes : ${dental['notes']}'),
              ],
            ),
          ),
          _tableRowItem(
            'Consent',
            _renderConsent(consent),
            isLast: true,
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
      final followUpRef = await _db.collection('followups').add({
        'patientId': _selectedPatientId,

        'followUpDate': Timestamp.fromDate(_selectedDate),

        'doctorNotes': _doctorNotesCtrl.text.trim(),

        // ✅ SAME AS TREATMENT
        'problems': _newProblems
            .map((p) => {
                  'teeth': p.teeth,
                  'type': p.type,
                  'notes': p.notes,
                })
            .toList(),

        // ✅ ALWAYS non-null, ALWAYS a List
        'prescribedMedicinesCart': (_medicineCart ?? [])
            .map((m) => {
                  'medicineId': m['medicineId'] ?? '',
                  'medicineName': m['medicineName'] ?? '',
                  'quantity': (m['quantity'] ?? 1) as int, // 🔒 force int
                })
            .toList(),

        'hasScans': false,
        'scanCount': 0,

        'createdAt': FieldValue.serverTimestamp(),
      });

      await _uploadFollowUpScans(followUpRef: followUpRef);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Follow Up saved successfully')),
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
      _medicineCart.clear();
      _selectedScans.clear();
    });
  }

  Future<void> _uploadFollowUpScans({
    required DocumentReference followUpRef,
  }) async {
    if (_selectedScans.isEmpty) return;

    int uploadedCount = 0;

    for (final scan in _selectedScans) {
      final scanId = const Uuid().v4();
      final storageRef = FirebaseStorage.instance
          .ref('followups/${followUpRef.id}/scans/$scanId.jpg');

      String downloadUrl;

      if (kIsWeb) {
        final bytes = await scan.readAsBytes();
        final task = await storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        downloadUrl = await task.ref.getDownloadURL();
      } else {
        final task = await storageRef.putFile(File(scan.path));
        downloadUrl = await task.ref.getDownloadURL();
      }

      await followUpRef.collection('scans').doc(scanId).set({
        'imageUrl': downloadUrl,
        'fileName': scan.name,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      uploadedCount++;
    }

    await followUpRef.update({
      'hasScans': uploadedCount > 0,
      'scanCount': uploadedCount,
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

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      );

  // ------------------------------
  // Layout constants
  // ------------------------------
  static const Color _bgColor = Color(0xFFF6F7F9);
  static const double _headerFooterRatio = 0.08;
  static const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(24, 24, 24, 32);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bgColor.withOpacity(0.98),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(size),
            _buildScrollableBody(),
            _softDivider(),
            _buildFooter(size),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // HEADER
  // ======================================================
  Widget _buildHeader(Size size) {
    return SizedBox(
      height: size.height * _headerFooterRatio,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Follow Up',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ),
    );
  }

  // ======================================================
  // SCROLLABLE BODY
  // ======================================================
  Widget _buildScrollableBody() {
    return Expanded(
      child: SingleChildScrollView(
          padding: _bodyPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Plug form content here in derived widgets
                // Patient search + date
                Row(
                  children: [
                    Expanded(
                      child: DropdownSearch<_PatientOption>(
                        items: _patientOptions,
                        selectedItem: _selectedPatientId == null
                            ? null
                            : _patientOptions.firstWhere(
                                (p) => p.id == _selectedPatientId,
                              ),
                        itemAsString: (item) => item.label,
                        popupProps: PopupProps.menu(
                          showSearchBox: true,
                          constraints: const BoxConstraints(maxHeight: 280),
                          containerBuilder: (context, popupWidget) {
                            return Material(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.zero, // sharp ERP style
                              elevation: 6,
                              child: popupWidget,
                            );
                          },
                          searchFieldProps: TextFieldProps(
                            decoration: InputDecoration(
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
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          dropdownSearchDecoration: _dec("Select patient"),
                        ),
                        onChanged: (val) {
                          if (val == null) return;
                          _onPatientSelected(val.id);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _pickDate,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        side: const BorderSide(
                            color: Color(0xFFE5E7EB), width: 1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        foregroundColor: const Color(0xFF111827),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 8),
                          Text(_displayDate.format(_selectedDate)),
                        ],
                      ),
                    ),
                  ],
                ),

                // 🔥 PATIENT HEALTH CONDITIONS PANEL
                _patientHealthPanel(),
                _chiefComplaintSnapshotPanel(),
                _previousFollowUpsPanel(),

                // 💊 Medicine Prescription
                _sectionHeader('Medicine Prescription'),
                _buildMedicinePrescriptionTable(),

                const SizedBox(height: 8),

                ElevatedButton.icon(
                  style: _blackActionButtonStyle,
                  onPressed: _openAddMedicineDialog,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Add Medicines'),
                ),

                _sectionHeader('Scans'),

                if (_selectedScans.isEmpty)
                  const Text(
                    'No scans uploaded',
                    style: TextStyle(color: Colors.grey),
                  ),

                if (_selectedScans.isNotEmpty)
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(_selectedScans.length, (index) {
                      final scan = _selectedScans[index];

                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _scanPreview(scan),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedScans.removeAt(index);
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.close,
                                    size: 18, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),

                const SizedBox(height: 8),

                ElevatedButton.icon(
                  style: _blackActionButtonStyle,
                  onPressed: _pickScans,
                  icon: const Icon(Icons.add_a_photo, color: Colors.white),
                  label: const Text('Add Scans'),
                ),

                // ================= NEW PROBLEMS =================
                _sectionHeader('New Problems'),

                for (int i = 0; i < _newProblems.length; i++)
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Teeth: ${_newProblems[i].teeth.join(', ')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _newProblems[i].type,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _newProblems[i].notes,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            onPressed: () =>
                                setState(() => _newProblems.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  ),

                ElevatedButton.icon(
                  style: _blackActionButtonStyle,
                  onPressed: _openAddProblemDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Problem'),
                ),

                _sectionHeader('Doctor Notes'),
                TextFormField(
                  controller: _doctorNotesCtrl,
                  maxLines: 5,
                  decoration: _dec('Doctor notes'),
                ),
              ],
            ),
          )),
    );
  }

  Widget _prescribedMedicinesBlock(List<dynamic>? cart) {
    final bool hasMedicines = cart != null && cart.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 13,
            color: _readOnlyText,
            height: 1.5,
          ),
          children: [
            const TextSpan(
              text: 'Prescribed Medicines: ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: hasMedicines
                  ? '[ ${_formatPrescribedMedicines(cart)} ]'
                  : 'No medicines prescribed',
              style: TextStyle(
                fontStyle: hasMedicines ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrescribedMedicines(List<dynamic>? cart) {
    if (cart == null || cart.isEmpty) return '';

    final items = cart.map((m) {
      final name = (m['medicineName'] ?? '').toString();
      final qty = (m['quantity'] ?? 0).toString();
      return '$name : $qty';
    }).toList();

    return items.join(', ');
  }

  Future<void> _pickScans() async {
    final List<XFile> images = await _imagePicker.pickMultiImage(
      imageQuality: 70, // 🔥 compress (VERY IMPORTANT)
      maxWidth: 1600,
    );

    if (images.isEmpty) return;

    setState(() {
      _selectedScans.addAll(images);
    });
  }

  void _openAddMedicineDialog() {
    final TextEditingController dialogSearchCtrl = TextEditingController();
    String dialogSearch = '';

    final maxWidth = MediaQuery.of(context).size.width * 0.9;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    showDialog(
      context: context,
      builder: (dctx) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ================= HEADER =================
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Add Medicines',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  dialogSearchCtrl.dispose();
                                  Navigator.of(dctx).pop();
                                },
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),

                        // ================= BODY =================
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(14),
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
                                    prefixIcon:
                                        const Icon(Icons.search, size: 18),
                                    hintText: 'Search medicine',
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                /// 📦 STOCK
                                _buildMedicineStockForDialog(
                                  dialogSearch,
                                  setDialogState,
                                ),

                                const SizedBox(height: 16),

                                /// 🛒 CART
                                if (_medicineCart.isNotEmpty)
                                  _buildMedicineCart(setDialogState),
                              ],
                            ),
                          ),
                        ),

                        // ================= FOOTER =================
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  dialogSearchCtrl.dispose();
                                  setState(() {}); // refresh summary
                                  Navigator.of(dctx).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 26, vertical: 12),
                                ),
                                child: const Text('Done'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
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
                          final availableQty =
                              _getAvailableQty(c['medicineId']);
                          final currentQty = c['quantity'];

                          if (currentQty >= availableQty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Only $availableQty quantity available for ${c['medicineName']}',
                                ),
                              ),
                            );
                            return;
                          }

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

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

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

  void _addToCart(Map<String, dynamic> m) {
    final medicineId = m['id'];
    final availableQty = _getAvailableQty(medicineId);

    final index =
        _medicineCart.indexWhere((e) => e['medicineId'] == medicineId);

    final currentQty = index >= 0 ? _medicineCart[index]['quantity'] : 0;

    // 🔥 STOCK VALIDATION
    if (currentQty >= availableQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only $availableQty quantity available for ${m['medicineName']}',
          ),
        ),
      );
      return;
    }

    if (index >= 0) {
      _medicineCart[index]['quantity']++;
    } else {
      _medicineCart.add({
        'medicineId': medicineId,
        'medicineName': m['medicineName'],
        'quantity': 1,
        'price': null,
      });
    }

    setState(() {});
  }

  Widget _scanPreview(XFile scan) {
    return kIsWeb
        ? Image.network(
            scan.path,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, size: 48),
          )
        : Image.file(
            File(scan.path),
            fit: BoxFit.cover,
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
                child:
                    Text('S.No', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: Text('Medicine Name',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'Qty',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(
                width: 40,
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
                  width: 60,
                  child: Text(
                    '${m['quantity']}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),

                // ❌ DELETE BUTTON
                SizedBox(
                  width: 40,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF6B7280),
                    ),
                    tooltip: 'Remove medicine',
                    onPressed: () {
                      setState(() {
                        _medicineCart.removeAt(index);
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ======================================================
  // FOOTER
  // ======================================================
  Widget _buildFooter(Size size) {
    return SizedBox(
      height: size.height * _headerFooterRatio,
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 32),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _pillButton(
              label: _saving ? 'Saving…' : 'Save',
              background: const Color(0xFF111827),
              foreground: Colors.white,
              onPressed: (_saving || _uploadingScans) ? () {} : _onSave,
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // HELPERS
  // ======================================================
  static Divider _softDivider() => const Divider(
        height: 1,
        thickness: 0.6,
        color: Color(0xFFEDEFF2),
      );

  static Widget _pillButton({
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      splashColor: Colors.black12,
      highlightColor: Colors.transparent,
      onTap: onPressed,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
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

class AddProblemDialogState {
  // ---------- IMPLANT STATE ----------
  String? implantType; // Basal / Conventional

  final TextEditingController implantWidthCtrl = TextEditingController();
  final TextEditingController implantLengthCtrl = TextEditingController();
  final TextEditingController implantCompanyCtrl = TextEditingController();

  String buildImpactionPrefix() {
    if (impactionType == null) return '';

    return '[ Impaction – $impactionType ] ';
  }

  // ---------- IMPACTION STATE ----------
  String? impactionType;

  DateTime? healingCapDate;
  DateTime? abutmentDate;
  DateTime? crownDate;

  final Set<int> selectedTeeth = {};
  String? problemType;

  final Map<int, Map<String, TextEditingController>> rctInputs = {};
  final Map<int, TextEditingController> rctOtherInputs = {};

  // ---------- Domain rule ----------
  List<String> getCanalsForTooth(int tooth) {
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

  // ---------- Core reconciliation ----------
  void reconcile() {
    if (problemType != 'Root Canal') {
      _clearAll();
      return;
    }

    // remove orphan teeth
    for (final tooth in rctInputs.keys.toList()) {
      if (!selectedTeeth.contains(tooth)) {
        _disposeTooth(tooth);
      }
    }

    // ensure controllers exist
    for (final tooth in selectedTeeth) {
      if (!rctInputs.containsKey(tooth)) {
        _initTooth(tooth);
      }
    }
  }

  // ---------- Public API ----------
  void toggleTooth(int tooth) {
    selectedTeeth.contains(tooth)
        ? selectedTeeth.remove(tooth)
        : selectedTeeth.add(tooth);
    reconcile();
  }

  void setProblemType(String? type) {
    problemType = type;

    if (type != 'Implants') {
      implantType = null;
      implantWidthCtrl.clear();
      implantLengthCtrl.clear();
      implantCompanyCtrl.clear();
      healingCapDate = null;
      abutmentDate = null;
      crownDate = null;
    }

    if (type != 'Impaction') {
      impactionType = null; // 👈 IMPORTANT
    }

    reconcile();
  }

  String buildImplantPrefix() {
    final List<String> parts = [];

    if (implantType != null) {
      parts.add('Type: $implantType');
    }

    if (implantWidthCtrl.text.isNotEmpty) {
      parts.add('Width: ${implantWidthCtrl.text}mm');
    }

    if (implantLengthCtrl.text.isNotEmpty) {
      parts.add('Length: ${implantLengthCtrl.text}mm');
    }

    if (implantCompanyCtrl.text.isNotEmpty) {
      parts.add('Company: ${implantCompanyCtrl.text}');
    }

    if (healingCapDate != null) {
      parts.add(
        'Healing cap: ${DateFormat('dd-MMM-yyyy').format(healingCapDate!)}',
      );
    }

    if (abutmentDate != null) {
      parts.add(
        'Abutment: ${DateFormat('dd-MMM-yyyy').format(abutmentDate!)}',
      );
    }

    if (crownDate != null) {
      parts.add(
        'Crown: ${DateFormat('dd-MMM-yyyy').format(crownDate!)}',
      );
    }

    if (parts.isEmpty) return '';

    return '[ Implant ${parts.join(', ')} ] ';
  }

  String buildRootCanalPrefix() {
    final buffer = StringBuffer();

    for (final tooth in selectedTeeth.toList()..sort()) {
      final parts = <String>[];

      final canals = rctInputs[tooth];
      if (canals != null) {
        for (final e in canals.entries) {
          if (e.value.text.trim().isNotEmpty) {
            parts.add('${e.key}: ${e.value.text.trim()}mm');
          }
        }
      }

      final other = rctOtherInputs[tooth];
      if (other != null && other.text.trim().isNotEmpty) {
        parts.add('Others: ${other.text.trim()}mm');
      }

      if (parts.isNotEmpty) {
        buffer.write('[ Tooth $tooth – ${parts.join(', ')} ] ');
      }
    }
    return buffer.toString();
  }

  void dispose() {
    implantWidthCtrl.dispose();
    implantLengthCtrl.dispose();
    implantCompanyCtrl.dispose();
    _clearAll();
    selectedTeeth.clear();
  }

  // ---------- Internals ----------
  void _initTooth(int tooth) {
    rctInputs[tooth] = {
      for (final c in getCanalsForTooth(tooth)) c: TextEditingController()
    };
    rctOtherInputs[tooth] = TextEditingController();
  }

  void _disposeTooth(int tooth) {
    rctInputs[tooth]?.values.forEach((c) => c.dispose());
    rctInputs.remove(tooth);
    rctOtherInputs[tooth]?.dispose();
    rctOtherInputs.remove(tooth);
  }

  void _clearAll() {
    for (final tooth in rctInputs.keys.toList()) {
      _disposeTooth(tooth);
    }
  }
}
