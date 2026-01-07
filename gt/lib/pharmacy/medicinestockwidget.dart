// lib/medicine_stock_widget.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gt/homelayout.dart';

class MedicineStockWidget extends StatefulWidget {
  const MedicineStockWidget({super.key});

  @override
  State<MedicineStockWidget> createState() => _MedicineStockWidgetState();
}

class _MedicineStockWidgetState extends State<MedicineStockWidget> {
  final _db = FirebaseFirestore.instance;

  // ------------------------------
  // STANDARD TEMPLATE CONSTANTS
  // ------------------------------
  static const Color _bgColor = Color(0xFFF6F7F9);
  static const double _headerFooterRatio = 0.08;
  static const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(24, 24, 24, 32);

  // Search controller
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

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

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _medicinesStream() {
    return _db
        .collection('medicines')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs);
  }

  // ======================================================
  // BUILD
  // ======================================================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bgColor.withOpacity(0.98),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(size),
            _buildBody(),
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
            'Medicine Stock',
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
  // BODY
  // ======================================================
  Widget _buildBody() {
    return Expanded(
      child: SingleChildScrollView(
        padding: _bodyPadding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search + Add
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
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _openAddEditDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                _tableHeader(),
                const SizedBox(height: 8),

                StreamBuilder<
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                  stream: _medicinesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Text('Failed to load medicines: ${snapshot.error}'),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final docs = snapshot.data!;
                    final filtered = _searchQuery.isEmpty
                        ? docs
                        : docs.where((d) {
                            final name = (d.data()['medicineName'] ?? '')
                                .toString()
                                .toLowerCase();
                            return name.contains(_searchQuery.toLowerCase());
                          }).toList();

                    if (filtered.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: Text('No medicines found')),
                      );
                    }

                    return Column(
                      children: filtered.asMap().entries.map((e) {
                        final idx = e.key;
                        final d = e.value;
                        final data = d.data();

                        return InkWell(
                          onTap: () => _openAddEditDialog(doc: d),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(width: 40, child: Text('${idx + 1}')),
                                Expanded(
                                    child: Text(data['medicineName'] ?? '')),
                                SizedBox(
                                    width: 140,
                                    child: Text(
                                        '${data['quantityPurchased'] ?? 0}')),
                                SizedBox(
                                    width: 160,
                                    child: Text(
                                      _dateFmt.formatFromTimestamp(
                                          data['expiryDate']),
                                    )),
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

  

  // ======================================================
  // TABLE HELPERS
  // ======================================================
  Widget _tableHeader() => Container(
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
                child: Text('S.No',
                    style: TextStyle(fontWeight: FontWeight.w600))),
            Expanded(
                child: Text('Medicine Name',
                    style: TextStyle(fontWeight: FontWeight.w600))),
            SizedBox(
                width: 140,
                child: Text('Quantity',
                    style: TextStyle(fontWeight: FontWeight.w600))),
            SizedBox(
                width: 160,
                child: Text('Expiry Date',
                    style: TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );

  // ======================================================
  // ADD / EDIT DIALOG (UNCHANGED)
  // ======================================================
  Future<void> _openAddEditDialog({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final bool isEdit = doc != null;
    final data = doc?.data();

    final TextEditingController nameCtrl =
        TextEditingController(text: data?['medicineName'] ?? '');
    final TextEditingController qtyCtrl =
        TextEditingController(text: '${data?['quantityPurchased'] ?? ''}');
    DateTime? expiryDate = data?['expiryDate'] is Timestamp
        ? (data!['expiryDate'] as Timestamp).toDate()
        : null;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ================= HEADER =================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEdit ? 'Edit Stock' : 'Add Stock',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ================= MEDICINE NAME =================
                      _dialogTextField(
                        controller: nameCtrl,
                        label: 'Medicine Name',
                        readOnly: isEdit, // 🔥 lock name during edit
                      ),

                      const SizedBox(height: 14),

                      // ================= QUANTITY =================
                      _dialogTextField(
                        controller: qtyCtrl,
                        label: 'Quantity',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ================= EXPIRY DATE =================
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                            initialDate: expiryDate ?? DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() => expiryDate = picked);
                          }
                        },
                        child: AbsorbPointer(
                          child: _dialogTextField(
                            controller: TextEditingController(
                              text: expiryDate == null
                                  ? ''
                                  : _dateFmt.format(expiryDate!),
                            ),
                            label: 'Expiry Date',
                            suffixIcon:
                                const Icon(Icons.calendar_today, size: 18),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ================= FOOTER =================
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (nameCtrl.text.trim().isEmpty ||
                                qtyCtrl.text.trim().isEmpty ||
                                expiryDate == null) return;

                            final payload = {
                              'medicineName': nameCtrl.text.trim(),
                              'quantityPurchased':
                                  int.parse(qtyCtrl.text.trim()),
                              'expiryDate': Timestamp.fromDate(expiryDate!),
                              'updatedAt': FieldValue.serverTimestamp(),
                            };

                            if (isEdit) {
                              await doc!.reference.update(payload);
                            } else {
                              await _db.collection('medicines').add({
                                ...payload,
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                            }

                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF111827),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 26, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dialogTextField({
    required TextEditingController controller,
    required String label,
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// ======================================================
class DateFormatHelper {
  String format(DateTime dt) => '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  String formatFromTimestamp(dynamic ts) {
    if (ts is Timestamp) return format(ts.toDate());
    if (ts is DateTime) return format(ts);
    return '';
  }
}
