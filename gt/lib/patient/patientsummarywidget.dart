// lib/appointment/patienthistorywidget.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// PatientHistoryWidget
///
/// Shows an overview of a patient's footprints across the system:
/// - Previous Visits
/// - Upcoming Visits
/// - Treatment Summary
/// - Follow Up Summary
/// - Payment Summary
/// - Medication Summary
///
/// NOTE: collection names for treatments/followups/payments/medications are assumed.
/// If your project uses different names, change the collection strings below.
class PatientHistoryWidget extends StatefulWidget {
  const PatientHistoryWidget({super.key});

  @override
  State<PatientHistoryWidget> createState() => _PatientHistoryWidgetState();
}

class _PatientHistoryWidgetState extends State<PatientHistoryWidget> {
  final _db = FirebaseFirestore.instance;

  // patient search controls
  final TextEditingController _searchCtrl = TextEditingController();
  bool _loadingPatients = true;
  List<_PatientOption> _patientOptions = [];
  String? _selectedPatientId;

  // appointment lists
  bool _loadingAppointments = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _previousVisits = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _upcomingVisits = [];

  // other summaries
  bool _loadingSummaries = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _treatments = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _followups = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _payments = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _medications = [];

  // date formatter
  final DateFormat _displayFormatter = DateFormat('EEEE, d MMMM yyyy  h:mm a');

  // Assumed collection names — change if your DB differs
  final String _treatmentsCollection = 'treatments';
  final String _followupsCollection = 'followups';
  final String _paymentsCollection = 'payments';
  final String _medicationsCollection = 'medications';
  final String _appointmentsCollection = 'appointments';

  @override
  void initState() {
    super.initState();
    _loadPatientsForDropdown();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPatientsForDropdown() async {
    setState(() => _loadingPatients = true);
    try {
      final snap = await _db.collection('patients').orderBy('patientId').get();
      final List<_PatientOption> opts = [];
      for (final doc in snap.docs) {
        final data = doc.data();
        final id = (data['patientId'] ?? doc.id).toString();
        final fullName = (data['fullName'] ??
                '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}')
            .toString()
            .trim();
        final label = fullName.isNotEmpty ? '$id  $fullName' : id;
        if (data['isActive'] == false) continue;
        opts.add(_PatientOption(id: id, label: label));
      }
      setState(() {
        _patientOptions = opts;
        _loadingPatients = false;
      });
    } catch (e) {
      setState(() => _loadingPatients = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load patients: $e')));
    }
  }

  void _onPatientSelected(String? val) {
    setState(() {
      _selectedPatientId = val;
      _previousVisits = [];
      _upcomingVisits = [];
      _treatments = [];
      _followups = [];
      _payments = [];
      _medications = [];
    });

    if (val != null && val.isNotEmpty) {
      _loadAllSummaries(val);
    }
  }

  Future<void> _loadAllSummaries(String patientId) async {
    setState(() {
      _loadingAppointments = true;
      _loadingSummaries = true;
    });

    final now = DateTime.now();

    try {
      // Appointments (recent 200)
      final snap = await _db
          .collection(_appointmentsCollection)
          .where('patientId', isEqualTo: patientId)
          .orderBy('appointmentDateTime', descending: true)
          .limit(200)
          .get();

      final prev = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final upcoming = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['appointmentDateTime'];
        DateTime? dt;
        if (ts is Timestamp) dt = ts.toDate();
        else if (ts is DateTime) dt = ts;
        if (dt == null) {
          prev.add(doc as QueryDocumentSnapshot<Map<String, dynamic>>);
        } else if (dt.isBefore(now)) {
          prev.add(doc as QueryDocumentSnapshot<Map<String, dynamic>>);
        } else {
          upcoming.add(doc as QueryDocumentSnapshot<Map<String, dynamic>>);
        }
      }

      // Treatments (most recent 200) — assumed fields: date (Timestamp), summary
      final treatmentsSnap = await _db
          .collection(_treatmentsCollection)
          .where('patientId', isEqualTo: patientId)
          .orderBy('date', descending: true)
          .limit(200)
          .get();

      // Followups (most recent 200) — assumed fields: date, note
      final followupsSnap = await _db
          .collection(_followupsCollection)
          .where('patientId', isEqualTo: patientId)
          .orderBy('date', descending: true)
          .limit(200)
          .get();

      // Payments (most recent 200) — assumed fields: paidAt / date, amount, mode
      final paymentsSnap = await _db
          .collection(_paymentsCollection)
          .where('patientId', isEqualTo: patientId)
          .orderBy('paidAt', descending: true)
          .limit(200)
          .get();

      // Medications (most recent 200) — assumed fields: issuedAt / date, meds (string)
      final medsSnap = await _db
          .collection(_medicationsCollection)
          .where('patientId', isEqualTo: patientId)
          .orderBy('issuedAt', descending: true)
          .limit(200)
          .get();

      setState(() {
        _previousVisits = prev;
        _upcomingVisits = upcoming;
        _treatments = treatmentsSnap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
        _followups = followupsSnap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
        _payments = paymentsSnap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
        _medications = medsSnap.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load history: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _loadingAppointments = false;
          _loadingSummaries = false;
        });
      }
    }
  }

  // UI helpers
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFF111827), fontSize: 14, fontWeight: FontWeight.w600)),
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

  Widget _buildPreviousVisitsSection() {
    if (_loadingAppointments) {
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator());
    }
    if (_previousVisits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text("No Previous Visits", style: TextStyle(color: Colors.grey)),
      );
    }

    return _buildSimpleTable(
      columns: const ['S.No', 'Date & Time', 'Notes'],
      rows: List.generate(_previousVisits.length, (i) {
        final doc = _previousVisits[i];
        final data = doc.data();
        final ts = data['appointmentDateTime'];
        DateTime? dt;
        if (ts is Timestamp) dt = ts.toDate();
        else if (ts is DateTime) dt = ts;
        final dateText = dt != null ? _displayFormatter.format(dt) : '-';
        final notes = (data['notes'] as String?) ?? '';
        return [(i + 1).toString(), dateText, notes];
      }),
    );
  }

  Widget _buildUpcomingVisitsSection() {
    if (_loadingAppointments) {
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator());
    }
    if (_upcomingVisits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text("No Upcoming Visits", style: TextStyle(color: Colors.grey)),
      );
    }

    return _buildSimpleTable(
      columns: const ['S.No', 'Date & Time', 'Notes'],
      rows: List.generate(_upcomingVisits.length, (i) {
        final doc = _upcomingVisits[i];
        final data = doc.data();
        final ts = data['appointmentDateTime'];
        DateTime? dt;
        if (ts is Timestamp) dt = ts.toDate();
        else if (ts is DateTime) dt = ts;
        final dateText = dt != null ? _displayFormatter.format(dt) : '-';
        final notes = (data['notes'] as String?) ?? '';
        return [(i + 1).toString(), dateText, notes];
      }),
    );
  }

  Widget _buildTreatmentSummarySection() {
    if (_loadingSummaries) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator());
    }
    if (_treatments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text("No Treatment records found", style: TextStyle(color: Colors.grey)),
      );
    }

    // For each treatment doc, attempt to extract date & summary
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _treatments.map((doc) {
        final data = doc.data();
        final ts = data['date'] ?? data['treatmentAt'] ?? data['createdAt'];
        DateTime? dt;
        if (ts is Timestamp) dt = ts.toDate();
        else if (ts is DateTime) dt = ts;
        final dateText = dt != null ? DateFormat('d MMM yyyy').format(dt) : '-';
        final summary = (data['summary'] ?? data['notes'] ?? data['details'] ?? '').toString();
        return Column(
          children: [
            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: Text(summary.isNotEmpty ? summary : 'Treatment record', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(dateText),
            ),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildFollowUpSummarySection() {
    if (_loadingSummaries) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator());
    }
    if (_followups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text("No Follow Up records found", style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _followups.map((doc) {
        final data = doc.data();
        final ts = data['date'] ?? data['followUpAt'] ?? data['createdAt'];
        DateTime? dt;
        if (ts is Timestamp) dt = ts.toDate();
        else if (ts is DateTime) dt = ts;
        final dateText = dt != null ? DateFormat('d MMM yyyy').format(dt) : '-';
        final note = (data['note'] ?? data['notes'] ?? '').toString();
        return Column(
          children: [
            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: Text(note.isNotEmpty ? note : 'Follow up', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(dateText),
            ),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPaymentSummarySection() {
    if (_loadingSummaries) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator());
    }
    if (_payments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text("No Payment records found", style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _payments.map((doc) {
        final data = doc.data();
        final ts = data['paidAt'] ?? data['date'] ?? data['createdAt'];
        DateTime? dt;
        if (ts is Timestamp) dt = ts.toDate();
        else if (ts is DateTime) dt = ts;
        final dateText = dt != null ? DateFormat('d MMM yyyy').format(dt) : '-';
        final amount = (data['amount'] ?? data['paidAmount'] ?? '').toString();
        final mode = (data['mode'] ?? data['paymentMode'] ?? '').toString();
        final desc = amount.isNotEmpty ? 'Amount: $amount' + (mode.isNotEmpty ? ' • $mode' : '') : (mode.isNotEmpty ? mode : 'Payment');
        return Column(
          children: [
            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: Text(desc, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(dateText),
            ),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMedicationSummarySection() {
    if (_loadingSummaries) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator());
    }
    if (_medications.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text("No Medication records found", style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _medications.map((doc) {
        final data = doc.data();
        final ts = data['issuedAt'] ?? data['date'] ?? data['createdAt'];
        DateTime? dt;
        if (ts is Timestamp) dt = ts.toDate();
        else if (ts is DateTime) dt = ts;
        final dateText = dt != null ? DateFormat('d MMM yyyy').format(dt) : '-';
        final meds = (data['meds'] ?? data['medication'] ?? data['prescription'] ?? '').toString();
        return Column(
          children: [
            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              title: Text(meds.isNotEmpty ? meds : 'Medication', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(dateText),
            ),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  // generic simple table builder used in visits sections
  Widget _buildSimpleTable({
    required List<String> columns,
    required List<List<String>> rows,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(width: 60, child: Text(columns[0], style: const TextStyle(fontWeight: FontWeight.w600))),
              Expanded(child: Text(columns[1], style: const TextStyle(fontWeight: FontWeight.w600))),
              Expanded(child: Text(columns[2], style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        ),
        const Divider(height: 1),
        ...rows.map((r) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    SizedBox(width: 60, child: Text(r[0])),
                    Expanded(child: Text(r[1])),
                    Expanded(child: Text(r[2], overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Patient History", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                const SizedBox(height: 20),

                // Patient Search
                _label("Patient Search"),
                if (_loadingPatients)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator())
                else
                  DropdownButtonFormField2<String>(
                    isExpanded: true,
                    value: _selectedPatientId,
                    decoration: _dec("Select patient"),
                    items: _patientOptions.map((p) => DropdownMenuItem<String>(value: p.id, child: _buildPatientOptionRow(p))).toList(),
                    onChanged: (v) => _onPatientSelected(v),
                    dropdownStyleData: DropdownStyleData(maxHeight: 280, decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12))),
                    menuItemStyleData: const MenuItemStyleData(height: 44),
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
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      searchMatchFn: (item, searchValue) {
                        final value = item.value ?? '';
                        final opt = _patientOptions.firstWhere((p) => p.id == value, orElse: () => _PatientOption(id: value, label: value));
                        return opt.label.toLowerCase().contains(searchValue.toLowerCase());
                      },
                    ),
                    onMenuStateChange: (isOpen) { if (!isOpen) _searchCtrl.clear(); },
                  ),

                const SizedBox(height: 28),

                // Two-column glance: Previous + Upcoming
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Previous Visits
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Previous Visits", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          _buildPreviousVisitsSection(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right: Upcoming Visits
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Upcoming Visits", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          _buildUpcomingVisitsSection(),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Summaries stacked vertically
                const Text("Treatment Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _buildTreatmentSummarySection(),

                const SizedBox(height: 20),
                const Text("Follow Up Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _buildFollowUpSummarySection(),

                const SizedBox(height: 20),
                const Text("Payment Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _buildPaymentSummarySection(),

                const SizedBox(height: 20),
                const Text("Medication Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _buildMedicationSummarySection(),

                const SizedBox(height: 12),
              ],
            ),
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