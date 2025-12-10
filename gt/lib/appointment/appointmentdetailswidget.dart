import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppointmentDetailsWidget extends StatefulWidget {
  const AppointmentDetailsWidget({super.key});

  @override
  State<AppointmentDetailsWidget> createState() =>
      _AppointmentDetailsWidgetState();
}

class _AppointmentDetailsWidgetState extends State<AppointmentDetailsWidget> {
  // --- patient search (same pattern as AppointmentWidget)
  final TextEditingController _searchCtrl = TextEditingController();
  final _db = FirebaseFirestore.instance;

  bool _loadingPatients = true;
  List<_PatientOption> _patientOptions = [];
  String? _selectedPatientId;

  // appointments lists
  bool _loadingAppointments = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _previousVisits = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _upcomingVisits = [];

  // editing state
  bool _editing = false;
  String? _editingAppointmentId;
  DateTime? _editingAppointmentDateTime;
  final TextEditingController _editingAppointmentDateTimeCtrl =
      TextEditingController();
  String? _editingAppointmentType; // 'N' or 'F'
  final TextEditingController _editingNotesCtrl = TextEditingController();
  bool _editSaving = false;

  // date formatter — changed to "Wednesday, 10 December 2025  8:50 AM"
  final DateFormat _displayFormatter =
      DateFormat('EEEE, d MMMM yyyy  h:mm a'); // two spaces before time

  @override
  void initState() {
    super.initState();
    _loadPatientsForDropdown();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _editingAppointmentDateTimeCtrl.dispose();
    _editingNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPatientsForDropdown() async {
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
        final label = fullName.isNotEmpty ? '$id  $fullName' : id.toString();
        opts.add(_PatientOption(id: id, label: label));
      }
      setState(() {
        _patientOptions = opts;
        _loadingPatients = false;
      });
    } catch (e) {
      setState(() => _loadingPatients = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load patients: $e')));
    }
  }

  // called when patient is selected; loads appointments
  void _onPatientSelected(String? val) {
    setState(() {
      _selectedPatientId = val;
      _previousVisits = [];
      _upcomingVisits = [];
      _editing = false;
      _editingAppointmentId = null;
    });

    if (val != null && val.isNotEmpty) {
      _loadAppointmentsForPatient(val);
    }
  }

  Future<void> _loadAppointmentsForPatient(String patientId) async {
    setState(() => _loadingAppointments = true);
    try {
      final snap = await _db
          .collection('appointments')
          .where('patientId', isEqualTo: patientId)
          .orderBy('appointmentDateTime', descending: true)
          .get();

      final now = DateTime.now();

      final prev = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final upcoming = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final ts = data['appointmentDateTime'] as Timestamp?;
        final dt = ts?.toDate();
        if (dt == null) {
          // treat as previous (or skip)
          prev.add(doc as QueryDocumentSnapshot<Map<String, dynamic>>);
        } else if (dt.isBefore(now)) {
          prev.add(doc as QueryDocumentSnapshot<Map<String, dynamic>>);
        } else {
          upcoming.add(doc as QueryDocumentSnapshot<Map<String, dynamic>>);
        }
      }

      setState(() {
        _previousVisits = prev;
        _upcomingVisits = upcoming;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load visits: $e')));
    } finally {
      if (mounted) setState(() => _loadingAppointments = false);
    }
  }

  // Edit flow: open inline form with appointment data loaded
  void _openEditForAppointment(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final ts = data['appointmentDateTime'] as Timestamp?;
    final dt = ts?.toDate();
    setState(() {
      _editing = true;
      _editingAppointmentId = doc.id;
      _editingAppointmentDateTime = dt;
      _editingAppointmentDateTimeCtrl.text =
          dt != null ? _displayFormatter.format(dt) : '';
      _editingAppointmentType = (data['appointmentType'] as String?) ?? 'N';
      _editingNotesCtrl.text = (data['notes'] as String?) ?? '';
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _editingAppointmentId = null;
      _editingAppointmentDateTime = null;
      _editingAppointmentDateTimeCtrl.text = '';
      _editingAppointmentType = null;
      _editingNotesCtrl.clear();
    });
  }

  // pick date & time for edit form
  Future<void> _pickEditAppointmentDateTime() async {
    final now = DateTime.now();
    final initialDate = _editingAppointmentDateTime ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay.fromDateTime(_editingAppointmentDateTime ?? DateTime.now()),
    );
    if (pickedTime == null) return;

    final combined = DateTime(pickedDate.year, pickedDate.month, pickedDate.day,
        pickedTime.hour, pickedTime.minute);

    setState(() {
      _editingAppointmentDateTime = combined;
      _editingAppointmentDateTimeCtrl.text = _displayFormatter.format(combined);
    });
  }

  Future<void> _onUpdateAppointment() async {
    if (_editingAppointmentId == null) return;

    if (_editingAppointmentDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select appointment date & time')));
      return;
    }

    if (_editingAppointmentType == null || _editingAppointmentType!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select appointment type')));
      return;
    }

    setState(() => _editSaving = true);

    try {
      final data = {
        'appointmentDateTime': Timestamp.fromDate(_editingAppointmentDateTime!),
        'appointmentType': _editingAppointmentType,
        'notes': _editingNotesCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _db
          .collection('appointments')
          .doc(_editingAppointmentId)
          .set(data, SetOptions(merge: true));

      // refresh lists
      if (_selectedPatientId != null) {
        await _loadAppointmentsForPatient(_selectedPatientId!);
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Appointment updated')));

      // exit edit
      _cancelEdit();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _editSaving = false);
    }
  }

  // --- UI helpers

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
              color: Color(0xFF111827), fontSize: 14, fontWeight: FontWeight.w600),
        ),
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
        child: Text(
          "No Previous Visits History",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return _buildSimpleTable(
      columns: const ['S.No', 'Date & Time', 'Notes'],
      rows: List.generate(_previousVisits.length, (i) {
        final doc = _previousVisits[i];
        final d = doc.data();
        final ts = d['appointmentDateTime'] as Timestamp?;
        final dt = ts?.toDate();
        final dateText = dt != null ? _displayFormatter.format(dt) : '-';
        final notes = (d['notes'] as String?) ?? '';
        return [ (i + 1).toString(), dateText, notes ];
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
        child: Text(
          "No Upcoming Visits, Please Book An Appointment",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Build rows including an edit icon button
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // header row
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: const [
              SizedBox(width: 60, child: Text('S.No', style: TextStyle(fontWeight: FontWeight.w600))),
              Expanded(child: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.w600))),
              Expanded(child: Text('Notes', style: TextStyle(fontWeight: FontWeight.w600))),
              SizedBox(width: 72, child: Text('', textAlign: TextAlign.center)), // edit col
            ],
          ),
        ),
        const Divider(height: 1),
        ...List.generate(_upcomingVisits.length, (i) {
          final doc = _upcomingVisits[i];
          final d = doc.data();
          final ts = d['appointmentDateTime'] as Timestamp?;
          final dt = ts?.toDate();
          final dateText = dt != null ? _displayFormatter.format(dt) : '-';
          final notes = (d['notes'] as String?) ?? '';

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    SizedBox(width: 60, child: Text((i + 1).toString())),
                    Expanded(child: Text(dateText)),
                    Expanded(child: Text(notes, overflow: TextOverflow.ellipsis)),
                    SizedBox(
                      width: 72,
                      child: Center(
                        child: Material(
                          elevation: 2,
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _openEditForAppointment(doc),
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Icon(Icons.edit, size: 20, color: Colors.blueGrey[700]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
          );
        }),
      ],
    );
  }

  // simple table builder for previous visits
  Widget _buildSimpleTable({
    required List<String> columns,
    required List<List<String>> rows,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // header row
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
            child: _editing ? _buildEditForm() : _buildMainView(),
          ),
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Appointment Details",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 24),

        // Patient Search
        _label("Patient Search"),
        if (_loadingPatients)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator())
        else
          DropdownButtonFormField2<String>(
            isExpanded: true,
            value: _selectedPatientId,
            decoration: _dec("Select patient"),
            items: _patientOptions
                .map((p) => DropdownMenuItem<String>(value: p.id, child: _buildPatientOptionRow(p)))
                .toList(),
            onChanged: (v) => _onPatientSelected(v),
            dropdownStyleData: DropdownStyleData(
              maxHeight: 280,
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16)),
            ),
            menuItemStyleData: const MenuItemStyleData(height: 44, padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
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
            onMenuStateChange: (isOpen) {
              if (!isOpen) _searchCtrl.clear();
            },
          ),

        const SizedBox(height: 28),

        // Previous Visits
        const Text("Previous Visits", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _buildPreviousVisitsSection(),
        const SizedBox(height: 24),

        // Upcoming Visits
        const Text("Upcoming Visits", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _buildUpcomingVisitsSection(),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Edit Appointment", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
        const SizedBox(height: 24),

        // Appointment Date & Time (picker)
        _label("Appointment Date & Time *"),
        TextFormField(
          controller: _editingAppointmentDateTimeCtrl,
          readOnly: true,
          onTap: _pickEditAppointmentDateTime,
          decoration: _dec("Wednesday, 10 December 2025  h:mm AM/PM"),
        ),
        const SizedBox(height: 16),

        // Appointment Type (radio)
        _label("Appointment Type *"),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: const Text("New"),
                value: 'N',
                groupValue: _editingAppointmentType,
                onChanged: (v) => setState(() => _editingAppointmentType = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: const Text("Follow Up"),
                value: 'F',
                groupValue: _editingAppointmentType,
                onChanged: (v) => setState(() => _editingAppointmentType = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Notes
        _label("Notes"),
        TextFormField(
          controller: _editingNotesCtrl,
          maxLines: 5,
          maxLength: 300,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Enter notes (optional, up to 300 chars)',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            ElevatedButton(
              onPressed: _editSaving ? null : _onUpdateAppointment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _editSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Update", style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _editSaving ? null : _cancelEdit,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Cancel"),
            ),
          ],
        ),
      ],
    );
  }
}

class _PatientOption {
  final String id;
  final String label;
  _PatientOption({required this.id, required this.label});
}