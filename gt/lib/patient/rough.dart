import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:gt/homelayout.dart';
import 'package:intl/intl.dart';

class PatientSummaryWidget extends StatefulWidget {
  const PatientSummaryWidget({super.key});

  @override
  State<PatientSummaryWidget> createState() => _PatientSummaryWidgetState();
}

class _PatientSummaryWidgetState extends State<PatientSummaryWidget> {
  double _treatmentTotalCost = 0;
  String? _chiefComplaintDoctorNotes;
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;

// ---------------- Payments ----------------
  List<Map<String, dynamic>> _payments = [];

  double _totalPaid = 0;
  double _totalAmount = 0;

  // ---------------- Payments History ----------------
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _loadingPayments = false;

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
    double fetchedTreatmentCost = 0;

    try {
      final treatSnap = await _db
          .collection('treatments')
          .where('patientId', isEqualTo: v)
          .orderBy('treatmentDate', descending: true)
          .limit(1)
          .get();

      // ---- Treatment document ----

      if (treatSnap.docs.isNotEmpty) {
        final data = treatSnap.docs.first.data();
        fetchedTreatmentCost = (data['treatmentAmount'] ?? 0).toDouble();
      }

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
            color: const Color(0xFFE5E7EB),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFB91C1C),
                      Color(0xFFF59E0B),
                      Color(0xFF16A34A),
                    ],
                  ),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  '${(percent * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
          const Divider(color: _readOnlyDivider, thickness: 0.6),
          const SizedBox(height: 12),

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _readOnlyDivider),
      ),
      child: const Row(
        children: [
          SizedBox(width: 40, child: Text('No')),
          Expanded(child: Text('Details')),
          SizedBox(width: 100, child: Text('Purpose')), // 👈 NEW
          SizedBox(width: 90, child: Text('Amount')),
          SizedBox(width: 80, child: Text('Mode')),
          SizedBox(width: 160, child: Text('Paid At')),
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
            'Follow-Ups',
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
            'Chief Complaint',
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

                const SizedBox(width: 16),

                // 💳 Payment Status
                if (_selectedPatientId != null) _paymentStatusBar(),
              ],
            ),

            _chiefComplaintSnapshotPanel(),
            _previousFollowUpsPanel(),
            _paymentsHistoryPanel(),
          ],
        ),
      ),
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

class _PatientOption {
  final String id;
  final String label;
  _PatientOption({required this.id, required this.label});
}