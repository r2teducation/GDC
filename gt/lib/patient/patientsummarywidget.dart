import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:gt/homelayout.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// ignore: uri_does_not_exist
import 'dart:ui_web' as ui_web;

class PatientSummaryWidget extends StatefulWidget {
  const PatientSummaryWidget({super.key});

  @override
  State<PatientSummaryWidget> createState() => _PatientSummaryWidgetState();
}

class _PatientSummaryWidgetState extends State<PatientSummaryWidget> {
  String? _chiefComplaintTreatmentType;

  double _treatmentTotalCost = 0;

// ---------------- Payments ----------------
  List<Map<String, dynamic>> _payments = [];

  double _totalPaid = 0;
  double _totalAmount = 0;

  // ---------------- Payments History ----------------
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _loadingPayments = false;

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

  // ---------------- Patient dropdown ----------------
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loadingPatients = true;
  List<_PatientOption> _patientOptions = [];
  String? _selectedPatientId;
  String? _chiefComplaintApptLabel;

  // ---------------- Doctor Notes ----------------
  final TextEditingController _doctorNotesCtrl = TextEditingController();

  // ---------------- Previous Follow Ups ----------------
  List<Map<String, dynamic>> _previousFollowUps = [];
  bool _loadingFollowUps = false;

  @override
  void initState() {
    super.initState();
    _loadPatientsForDropdown();
    _loadMedicines(); // 👈 ADD
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _doctorNotesCtrl.dispose();
    super.dispose();
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
      _chiefComplaintSnapshot = [];
      _chiefComplaintDoctorNotes = null;
      _chiefComplaintApptLabel = null;
      _chiefComplaintTreatmentType = null;
    });

    if (v == null) return;

    await _loadLatestTreatmentScans(v);

    setState(() => _loadingChiefComplaint = true);

    double fetchedTreatmentCost = 0;

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

        fetchedTreatmentCost = (data['treatmentAmount'] ?? 0).toDouble();

        final Timestamp? ts = data['treatmentDate'];
        final DateTime? dt = ts?.toDate();

        setState(() {
          final rawProblems = data['problems'];

          _chiefComplaintSnapshot = rawProblems is List
              ? List<Map<String, dynamic>>.from(rawProblems)
              : [];

          _chiefComplaintTreatmentType =
              (data['treatmentType'] ?? '').toString().trim();

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

    setState(() => _loadingPayments = true);

    try {
      final snap = await _db
          .collection('payments')
          .where('patientId', isEqualTo: v)
          .orderBy('paidAt', descending: true)
          .get();

      final payments = snap.docs.map((d) => d.data()).toList();

      // ---- Calculate Treatment-only totals ----
      double paid = 0;

      for (final p in payments) {
        if (p['paymentFor'] == 'Treatment') {
          paid += (p['amount'] ?? 0).toDouble();
        }
      }

      setState(() {
        _treatmentTotalCost = fetchedTreatmentCost;
        _payments = payments;
        _totalPaid = paid;
        _totalAmount = fetchedTreatmentCost; // ✅ guaranteed correct
      });
    } catch (_) {
      setState(() {
        _payments = [];
        _totalPaid = 0;
        _totalAmount = 0;
      });
    } finally {
      if (mounted) setState(() => _loadingPayments = false);
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
          // const SizedBox(height: 4),
          // const Divider(color: _readOnlyDivider, thickness: 0.6),

          /// ===== CONTENT =====
          for (final f in _previousFollowUps) ...[
            _infoTableCard(
              title: 'Follow Up',
              subtitle: DateFormat('EEEE dd-MMM-yyyy h:mm a')
                  .format((f['followUpDate'] as Timestamp).toDate()),
              rows: [
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
                'Type',
                Text(
                  (_chiefComplaintTreatmentType != null &&
                          _chiefComplaintTreatmentType!.isNotEmpty)
                      ? _chiefComplaintTreatmentType!
                      : '--',
                  style: const TextStyle(color: _readOnlyText),
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
            const SizedBox(height: 10),
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
            'Patient Summary',
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
                    ),

                    const SizedBox(width: 16),

                    // 💳 Payment Status
                    if (_selectedPatientId != null) _paymentStatusBar(),
                  ],
                ),
                const SizedBox(height: 8),
                _chiefComplaintSnapshotPanel(),
                _previousFollowUpsPanel(),
                _paymentsHistoryPanel(),
              ],
            ),
          )),
    );
  }

  Widget _paymentsHistoryPanel() {
    if (_loadingPayments) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      );
    }

    if (_payments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== HEADER =====
          const Text(
            'Payments History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _readOnlyHeading,
            ),
          ),
          const SizedBox(height: 8),
          //const Divider(color: _readOnlyDivider, thickness: 0.6),
          //const SizedBox(height: 12),

          // ===== TABLE HEADER =====
          _paymentsTableHeader(),

          // ===== TABLE ROWS =====
          ...List.generate(_payments.length, (i) {
            final p = _payments[i];
            final bool alt = i.isEven;

            return _paymentsTableRow(
              index: i + 1,
              data: p,
              alternate: alt,
            );
          }),
        ],
      ),
    );
  }

  Widget _paymentsTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: _tableHeaderBg, // ✅ black
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              'No',
              style: TextStyle(
                color: _tableHeaderText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Details',
              style: TextStyle(
                color: _tableHeaderText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              'Purpose',
              style: TextStyle(
                color: _tableHeaderText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              'Amount',
              style: TextStyle(
                color: _tableHeaderText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              'Mode',
              style: TextStyle(
                color: _tableHeaderText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 160,
            child: Text(
              'Paid At',
              style: TextStyle(
                color: _tableHeaderText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentsTableRow({
    required int index,
    required Map<String, dynamic> data,
    required bool alternate,
  }) {
    final Timestamp? ts = data['paidAt'];
    final String paidAt = ts != null
        ? DateFormat('dd-MMM-yyyy hh:mm a').format(ts.toDate())
        : '--';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: alternate ? const Color(0xFFF8FAFC) : Colors.white,
        border: Border(
          bottom: BorderSide(color: _readOnlyDivider),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '$index',
              style: const TextStyle(color: _readOnlyText),
            ),
          ),

          // Details
          Expanded(
            child: Text(
              data['details'] ?? '--',
              style: const TextStyle(color: _readOnlyText),
            ),
          ),

          // Purpose 👈 NEW
          SizedBox(
            width: 100,
            child: Text(
              data['paymentFor'] ?? '--',
              style: const TextStyle(
                color: _readOnlyText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Amount
          SizedBox(
            width: 90,
            child: Text(
              '₹${data['amount'] ?? 0}',
              style: const TextStyle(
                color: _readOnlyText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Mode
          SizedBox(
            width: 80,
            child: Text(
              data['paymentMode'] ?? '--',
              style: const TextStyle(color: _readOnlyText),
            ),
          ),

          // Paid At
          SizedBox(
            width: 160,
            child: Text(
              paidAt,
              style: const TextStyle(color: _readOnlyText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentStatusBar() {
    if (_totalAmount <= 0 || _loadingPayments) {
      return const SizedBox.shrink();
    }

    final double percent = (_totalPaid / _totalAmount).clamp(0, 1);

    const double barWidth = 260;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Labels (LOCKED TO BAR WIDTH) ----
        SizedBox(
          width: barWidth,
          child: Row(
            children: [
              Text(
                'Paid: ₹${_totalPaid.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
              const Spacer(),
              Text(
                'Total: ₹${_totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // ---- Progress Bar ----
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 18,
            width: barWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFF111827),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF111827), // solid black fill
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  '${(percent * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
}

class _PatientOption {
  final String id;
  final String label;
  _PatientOption({required this.id, required this.label});
}
