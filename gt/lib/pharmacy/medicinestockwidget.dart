// lib/medicine_stock_widget.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MedicineStockWidget extends StatefulWidget {
  const MedicineStockWidget({super.key});

  @override
  State<MedicineStockWidget> createState() => _MedicineStockWidgetState();
}

class _MedicineStockWidgetState extends State<MedicineStockWidget> {
  final _db = FirebaseFirestore.instance;

  // Search controller for dynamic search by medicine name
  final TextEditingController _searchCtrl = TextEditingController();

  // Local state
  String _searchQuery = '';
  bool _loading = false;

  // Date format helper
  final _dateFmt = DateFormatHelper();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Fetch stream of medicines; apply client-side filter by name for simplicity.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _medicinesStream() {
    // We'll fetch ordered by createdAt descending (if present), fallback to medicineName
    final q = _db.collection('medicines').orderBy('createdAt', descending: true).snapshots();
    // convert in widget build via StreamBuilder
    return q.map((snap) => snap.docs);
  }

  // Opens Add/Edit dialog. If doc == null -> add, else update.
  Future<void> _openAddEditDialog({QueryDocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final parentContext = context; // capture parent context to show snackbars reliably
    final isEdit = doc != null;
    final formKey = GlobalKey<FormState>();

    // controllers (local to dialog). NOTE: we DO NOT dispose them manually to avoid
    // a race where framework still updates a text field while controller is disposed.
    final medicineNameCtrl = TextEditingController(text: isEdit ? (doc!.data()['medicineName'] ?? '') : '');
    final distributorCtrl = TextEditingController(text: isEdit ? (doc!.data()['distributorName'] ?? '') : '');
    final purchaseDateCtrl = TextEditingController(
        text: isEdit ? _dateFmt.formatFromTimestamp(doc!.data()['purchaseDate']) : '');
    DateTime? purchaseDate = isEdit ? _dateFmt.parseFromTimestamp(doc!.data()['purchaseDate']) : null;

    final qtyCtrl = TextEditingController(text: isEdit ? (doc!.data()['quantityPurchased']?.toString() ?? '') : '');
    final expiryDateCtrl = TextEditingController(
        text: isEdit ? _dateFmt.formatFromTimestamp(doc!.data()['expiryDate']) : '');
    DateTime? expiryDate = isEdit ? _dateFmt.parseFromTimestamp(doc!.data()['expiryDate']) : null;

    final remarksCtrl = TextEditingController(text: isEdit ? (doc!.data()['remarks'] ?? '') : '');

    bool saving = false;

    Future<void> pickPurchaseDate() async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: parentContext,
        initialDate: purchaseDate ?? now,
        firstDate: DateTime(now.year - 10),
        lastDate: DateTime(now.year + 10),
      );
      if (picked != null) {
        purchaseDate = picked;
        purchaseDateCtrl.text = _dateFmt.format(picked);
      }
    }

    Future<void> pickExpiryDate() async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: parentContext,
        initialDate: expiryDate ?? now,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 20),
      );
      if (picked != null) {
        expiryDate = picked;
        expiryDateCtrl.text = _dateFmt.format(picked);
      }
    }

    // Show dialog
    await showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dctx) {
        return StatefulBuilder(builder: (dialogContext, setStateDialog) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isEdit ? 'Edit Medicine' : 'Add Medicine',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),

                      // Medicine Name
                      _label('Medicine Name *'),
                      TextFormField(
                        controller: medicineNameCtrl,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          return null;
                        },
                        decoration: _dec('Enter medicine name'),
                      ),
                      const SizedBox(height: 12),

                      // Distributor & Purchase Date row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Distributor Name'),
                                TextFormField(
                                  controller: distributorCtrl,
                                  decoration: _dec('Distributor / Supplier'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 220,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Purchase Date'),
                                OutlinedButton(
                                  onPressed: () async {
                                    final prev = purchaseDate;
                                    await pickPurchaseDate();
                                    if (purchaseDate != prev) setStateDialog(() {});
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                    backgroundColor: const Color(0xFFF8FAFC),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(purchaseDateCtrl.text.isEmpty ? 'Pick date' : purchaseDateCtrl.text),
                                      const Icon(Icons.calendar_today, size: 16),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Quantity & Expiry row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Quantity Purchased *'),
                                TextFormField(
                                  controller: qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Required';
                                    final n = int.tryParse(v.trim());
                                    if (n == null) return 'Enter a valid number';
                                    if (n < 0) return 'Must be zero or more';
                                    return null;
                                  },
                                  decoration: _dec('Total units added to stock'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 220,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Expiry Date'),
                                OutlinedButton(
                                  onPressed: () async {
                                    final prev = expiryDate;
                                    await pickExpiryDate();
                                    if (expiryDate != prev) setStateDialog(() {});
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                    backgroundColor: const Color(0xFFF8FAFC),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(expiryDateCtrl.text.isEmpty ? 'Pick date' : expiryDateCtrl.text),
                                      const Icon(Icons.calendar_today, size: 16),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Remarks
                      _label('Remarks / Notes'),
                      TextFormField(
                        controller: remarksCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: _dec('Any special instructions or comments'),
                      ),
                      const SizedBox(height: 18),

                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: saving
                                ? null
                                : () {
                                    Navigator.of(dctx).pop();
                                  },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: const Text('Close'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;
                                    setStateDialog(() => saving = true);
                                    try {
                                      final payload = <String, dynamic>{
                                        'medicineName': medicineNameCtrl.text.trim(),
                                        'distributorName': distributorCtrl.text.trim(),
                                        'purchaseDate': purchaseDate == null ? null : Timestamp.fromDate(purchaseDate!),
                                        'quantityPurchased': int.tryParse(qtyCtrl.text.trim()) ?? 0,
                                        'expiryDate': expiryDate == null ? null : Timestamp.fromDate(expiryDate!),
                                        'remarks': remarksCtrl.text.trim(),
                                        'updatedAt': FieldValue.serverTimestamp(),
                                      };
                                      if (isEdit) {
                                        await _db.collection('medicines').doc(doc!.id).set(payload, SetOptions(merge: true));
                                        // set saving false to update dialog UI before closing
                                        setStateDialog(() => saving = false);
                                        ScaffoldMessenger.of(parentContext).showSnackBar(const SnackBar(content: Text('Medicine updated')));
                                      } else {
                                        payload['createdAt'] = FieldValue.serverTimestamp();
                                        await _db.collection('medicines').add(payload);
                                        setStateDialog(() => saving = false);
                                        ScaffoldMessenger.of(parentContext).showSnackBar(const SnackBar(content: Text('Medicine added')));
                                      }
                                      // close dialog after showing snack bar (snack will appear in parent scaffold)
                                      Navigator.of(dctx).pop();
                                    } catch (e) {
                                      // ensure dialog spinner stops if there is an error
                                      setStateDialog(() => saving = false);
                                      ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(content: Text('Failed: $e')));
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: saving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(isEdit ? 'Update' : 'Add', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        });
      },
    );

    // NOTE: do NOT manually dispose the dialog-local controllers here.
    // Disposing them immediately after dialog pop can race with framework updates
    // which caused the "used after disposed" exception you saw.
    //
    // medicineNameCtrl.dispose();
    // distributorCtrl.dispose();
    // purchaseDateCtrl.dispose();
    // qtyCtrl.dispose();
    // expiryDateCtrl.dispose();
    // remarksCtrl.dispose();
  }

  // Decoration and label helpers reused from your patient widget style
  InputDecoration _dec(String hint) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Medicine Stock', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),

                // Top row: search and Add button (Add button on upper-right)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 20),
                          hintText: 'Search by medicine name',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _openAddEditDialog();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5A4),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE6E6E6)),
                  ),
                  child: Row(
                    children: const [
                      SizedBox(width: 40, child: Text('S.No', style: TextStyle(fontWeight: FontWeight.w600))),
                      Expanded(child: Text('Medicine Name', style: TextStyle(fontWeight: FontWeight.w600))),
                      SizedBox(width: 140, child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600))),
                      SizedBox(width: 160, child: Text('Expiry Date', style: TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // StreamBuilder shows table rows
                StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                  stream: _medicinesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Failed to load medicines: ${snapshot.error}'),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final docs = snapshot.data!;
                    // Apply client-side filter by name (case-insensitive)
                    final filtered = _searchQuery.isEmpty
                        ? docs
                        : docs.where((d) {
                            final name = (d.data()['medicineName'] ?? '').toString().toLowerCase();
                            return name.contains(_searchQuery.toLowerCase());
                          }).toList();

                    if (filtered.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(child: Text('No medicines found')),
                      );
                    }

                    return Column(
                      children: filtered.asMap().entries.map((e) {
                        final idx = e.key;
                        final d = e.value;
                        final data = d.data();
                        final medName = (data['medicineName'] ?? '').toString();
                        final qty = (data['quantityPurchased'] ?? 0).toString();
                        final expiry = _dateFmt.formatFromTimestamp(data['expiryDate']);

                        return InkWell(
                          onTap: () async {
                            // Open edit dialog with this doc
                            await _openAddEditDialog(doc: d);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                            ),
                            child: Row(
                              children: [
                                SizedBox(width: 40, child: Text('${idx + 1}')),
                                Expanded(child: Text(medName, style: const TextStyle(fontSize: 14))),
                                SizedBox(width: 140, child: Text(qty)),
                                SizedBox(width: 160, child: Text(expiry)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple helper to format timestamps and DateTimes. Keeps logic compact.
class DateFormatHelper {
  // Format a DateTime to yyyy-MM-dd
  String format(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  // Accepts either Timestamp, DateTime or null
  String formatFromTimestamp(dynamic ts) {
    if (ts == null) return '';
    try {
      if (ts is Timestamp) {
        return format(ts.toDate());
      } else if (ts is DateTime) {
        return format(ts);
      } else if (ts is String) {
        // try parse
        final parsed = DateTime.tryParse(ts);
        if (parsed != null) return format(parsed);
      }
    } catch (_) {}
    return '';
  }

  DateTime? parseFromTimestamp(dynamic ts) {
    if (ts == null) return null;
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    if (ts is String) {
      return DateTime.tryParse(ts);
    }
    return null;
  }
}