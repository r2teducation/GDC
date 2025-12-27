import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateAppointmentWidget extends StatefulWidget {
  final DateTime date;
  const CreateAppointmentWidget({super.key, required this.date});

  @override
  State<CreateAppointmentWidget> createState() =>
      _CreateAppointmentWidgetState();
}

class _CreateAppointmentWidgetState extends State<CreateAppointmentWidget> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? selectedPatientId;
  TimeOfDay? selectedTime;
  String appointmentType = 'N';

  final notesCtrl = TextEditingController();
  final searchCtrl = TextEditingController();

  List<DropdownMenuItem<String>> patientItems = [];

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
  final snap = await _db.collection('patients').get();

  setState(() {
    patientItems = snap.docs.map<DropdownMenuItem<String>>((d) {
      final patientId = (d['patientId'] ?? '').toString();
      final fullName = (d['fullName'] ?? patientId).toString();

      return DropdownMenuItem<String>(
        value: patientId,
        child: Text(fullName),
      );
    }).toList();
  });
}

  Future<void> _save() async {
    if (selectedPatientId == null || selectedTime == null) return;

    final dt = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    await _db.collection('appointments').add({
      'patientId': selectedPatientId,
      'appointmentDateTime': Timestamp.fromDate(dt),
      'appointmentType': appointmentType,
      'notes': notesCtrl.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Appointment'),
        leading:
            IconButton(icon: const Icon(Icons.close), onPressed: () {
          Navigator.pop(context);
        }),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField2(
                    items: patientItems,
                    onChanged: (v) => selectedPatientId = v,
                    decoration:
                        const InputDecoration(labelText: 'Patient'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now());
                      if (t != null) setState(() => selectedTime = t);
                    },
                    child: Text(selectedTime == null
                        ? 'Select Time'
                        : selectedTime!.format(context)),
                  ),
                  RadioListTile(
                    value: 'N',
                    groupValue: appointmentType,
                    title: const Text('New'),
                    onChanged: (v) =>
                        setState(() => appointmentType = v!),
                  ),
                  RadioListTile(
                    value: 'F',
                    groupValue: appointmentType,
                    title: const Text('Follow Up'),
                    onChanged: (v) =>
                        setState(() => appointmentType = v!),
                  ),
                  TextField(
                    controller: notesCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Notes'),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close')),
                const SizedBox(width: 8),
                ElevatedButton(
                    onPressed: _save, child: const Text('Create')),
              ],
            ),
          )
        ],
      ),
    );
  }
}