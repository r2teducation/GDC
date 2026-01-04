import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:gt/homelayout.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gt/homelayout.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

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
  List<Map<String, dynamic>> _medicineCart = [];
  List<Map<String, dynamic>> _medicineStock = [];

  // ---------------- Scans ----------------
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _selectedScans = [];
  bool _uploadingScans = false;

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

  // ---------------- Patient dropdown ----------------
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loadingPatients = true;
  List<_PatientOption> _patientOptions = [];
  String? _selectedPatientId;
  String? _chiefComplaintApptLabel;

  // ---------------- Problems ----------------
  final List<_ProblemRow> _problems = [];

  // ---------------- Doctor Notes ----------------
  final TextEditingController _doctorNotesCtrl = TextEditingController();

  // ---------------- Patient Health Snapshot ----------------
  Map<String, dynamic>? _patientHealthSnapshot;
  bool _loadingHealthSnapshot = false;

  // ---------------- Previous Follow Ups ----------------
  List<Map<String, dynamic>> _previousFollowUps = [];
  bool _loadingFollowUps = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPatientsForDropdown();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _doctorNotesCtrl.dispose();
    super.dispose();
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
          .orderBy('treatmentDate', descending: true)
          .get();

      setState(() {
        _previousFollowUps = followSnap.docs.map((d) => d.data()).toList();
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
      padding: const EdgeInsets.symmetric(vertical: 16),
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
          const SizedBox(height: 8),
          const Divider(color: _readOnlyDivider, thickness: 0.6),
          const SizedBox(height: 12),

          /// ===== CONTENT =====
          for (final f in _previousFollowUps) ...[
            Text(
              DateFormat('EEEE dd-MMM-yyyy h:mm a').format(
                (f['treatmentDate'] as Timestamp).toDate(),
              ),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _readOnlyHeading,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              f['doctorNotes'] ?? '--',
              style: const TextStyle(
                color: _readOnlyText,
                height: 1.5,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                color: _readOnlyDivider,
                thickness: 0.6,
              ),
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== HEADER =====
          const Text(
            'Chief Complaint (Initial Visit)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _readOnlyHeading,
            ),
          ),

          if (_chiefComplaintApptLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              _chiefComplaintApptLabel!,
              style: const TextStyle(
                fontSize: 13,
                color: _readOnlyText,
              ),
            ),
          ],

          const SizedBox(height: 8),
          const Divider(color: _readOnlyDivider, thickness: 0.6),

          // ===== PROBLEMS SECTION =====
          const SizedBox(height: 12),
          const Text(
            'Problems',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _readOnlyHeading,
            ),
          ),
          const SizedBox(height: 8),

          if (_chiefComplaintSnapshot.isEmpty)
            const Text(
              'No problems found',
              style: TextStyle(color: _readOnlyText),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _chiefComplaintSnapshot.map((p) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Teeth: ${(p['teeth'] as List).join(', ')}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        p['type'] ?? '--',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if ((p['notes'] ?? '').toString().isNotEmpty)
                        Text(
                          p['notes'],
                          style: const TextStyle(color: _readOnlyText),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),

          // ===== DOCTOR NOTES SECTION =====
          const SizedBox(height: 8),
          const Text(
            'Doctor Notes',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _readOnlyHeading,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            (_chiefComplaintDoctorNotes == null ||
                    _chiefComplaintDoctorNotes!.isEmpty)
                ? 'No notes found'
                : _chiefComplaintDoctorNotes!,
            style: const TextStyle(
              color: _readOnlyText,
              height: 1.5,
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ===== HEADER (NON-SCROLLABLE) =====
          Text(
            'Patient Health Snapshot at $apptLabel',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _readOnlyHeading,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: _readOnlyDivider, thickness: 0.6),
          const SizedBox(height: 12),

          /// ===== SCROLLABLE CONTENT =====
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionText('Vitals', [
                _kv('BP', '${vitals['bpSystolic']} / ${vitals['bpDiastolic']}'),
                _kv('HR', '${vitals['heartRate']}'),
                _kv('BR', '${vitals['breathingRate']}'),
                _kv('Ht / Wt', '${vitals['heightCm']} / ${vitals['weightKg']}'),
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
                    consent['given'] == true ? 'Consent Given' : 'Not Given',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          consent['given'] == true ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
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
  void _openAddProblemDialog() {
    final Set<int> selectedTeeth = {};
    String? problemType;
    final TextEditingController notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          Widget toothBox(int number) {
            final selected = selectedTeeth.contains(number);
            return InkWell(
              onTap: () {
                setStateDialog(() {
                  selected
                      ? selectedTeeth.remove(number)
                      : selectedTeeth.add(number);
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
      await _db.collection('followups').add({
        'patientId': _selectedPatientId,
        'treatmentDate': Timestamp.fromDate(_selectedDate),
        'doctorNotes': _doctorNotesCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Plug form content here in derived widgets
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
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
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
            _scansPanel(),
            _previousFollowUpsPanel(),

            // 💊 Medicine Prescription
            _sectionHeader('Medicine Prescription'),
            _buildMedicinePrescriptionTable(),

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

            _sectionHeader('Doctor Notes'),
            TextFormField(
              controller: _doctorNotesCtrl,
              maxLines: 5,
              decoration: _dec('Doctor notes'),
            ),
          ],
        ),
      ),
    );
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
              label: 'Close',
              background: const Color(0xFFE5E7EB),
              foreground: const Color(0xFF111827),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeLayoutWidget()),
                  (route) => false, // 🔥 clears back stack
                );
              },
            ),
            const SizedBox(width: 12),
            _pillButton(
              label: 'Save',
              background: const Color(0xFF111827),
              foreground: Colors.white,
              onPressed: () {},
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
