import 'package:flutter/material.dart';

class Medicine {
  final String name;
  final String id;
  final String group;
  final int stock;
  Medicine(this.name, this.id, this.group, this.stock);
}

class MedicinesListWidget extends StatefulWidget {
  const MedicinesListWidget({super.key});

  @override
  State<MedicinesListWidget> createState() => _MedicinesListWidgetState();
}

class _MedicinesListWidgetState extends State<MedicinesListWidget> {
  // 25 sample items
  final List<Medicine> _all = [
    Medicine('Augmentin 625 Duo Tablet', 'D06ID232435454', 'Generic Medicine', 350),
    Medicine('Azithral 500 Tablet', 'D06ID232435451', 'Generic Medicine', 20),
    Medicine('Ascoril LS Syrup', 'D06ID232435452', 'Diabetes', 85),
    Medicine('Azee 500 Tablet', 'D06ID232435450', 'Generic Medicine', 75),
    Medicine('Allegra 120mg Tablet', 'D06ID232435455', 'Diabetes', 44),
    Medicine('Alex Syrup', 'D06ID232435456', 'Generic Medicine', 65),
    Medicine('Amoxyclav 625 Tablet', 'D06ID232435457', 'Generic Medicine', 150),
    Medicine('Avil 25 Tablet', 'D06ID232435458', 'Generic Medicine', 270),
    Medicine('Calpol 650 Tablet', 'D06ID232435459', 'Fever', 180),
    Medicine('Crocin Pain Relief', 'D06ID232435460', 'Pain Relief', 120),
    Medicine('Dolo 650 Tablet', 'D06ID232435461', 'Fever', 95),
    Medicine('Ecosprin 75 Tablet', 'D06ID232435462', 'Cardiac', 60),
    Medicine('Eldoper Capsule', 'D06ID232435463', 'Gastro', 70),
    Medicine('Gelusil Liquid', 'D06ID232435464', 'Gastro', 110),
    Medicine('Glimisave 1 Tablet', 'D06ID232435465', 'Diabetes', 85),
    Medicine('Levocet M', 'D06ID232435466', 'Allergy', 55),
    Medicine('Metformin 500 Tablet', 'D06ID232435467', 'Diabetes', 130),
    Medicine('Neksium 40 Tablet', 'D06ID232435468', 'Gastro', 40),
    Medicine('Novamox 500 Capsule', 'D06ID232435469', 'Generic Medicine', 75),
    Medicine('Omnacortil 10 Tablet', 'D06ID232435470', 'Steroid', 45),
    Medicine('Pantocid 40 Tablet', 'D06ID232435471', 'Gastro', 160),
    Medicine('Saridon Tablet', 'D06ID232435472', 'Pain Relief', 90),
    Medicine('Shelcal 500 Tablet', 'D06ID232435473', 'Supplements', 140),
    Medicine('Telma 40 Tablet', 'D06ID232435474', 'Cardiac', 100),
    Medicine('Zifi 200 Tablet', 'D06ID232435475', 'Generic Medicine', 66),
  ];

  // ---------- filters/search ----------
  String _query = '';
  String _groupFilter = 'All';

  // ---------- sorting ----------
  String _sortKey = 'name'; // name, id, group, stock
  bool _ascending = true;

  // ---------- pagination ----------
  int _rowsPerPage = 8;
  int _page = 0; // 0-based

  List<String> get _groups => ['All', ...{for (final m in _all) m.group}];

  // Apply search/filter first
  List<Medicine> get _filtered {
    final q = _query.toLowerCase();
    final out = _all.where((m) {
      final matchesText =
          m.name.toLowerCase().contains(q) || m.id.toLowerCase().contains(q);
      final matchesGroup = _groupFilter == 'All' ? true : m.group == _groupFilter;
      return matchesText && matchesGroup;
    }).toList();
    return out;
  }

  // Then sort
  List<Medicine> get _sorted {
    final list = [..._filtered];
    int comp(Comparable a, Comparable b) =>
        _ascending ? a.compareTo(b) : b.compareTo(a);

    list.sort((a, b) {
      switch (_sortKey) {
        case 'id':
          return comp(a.id, b.id);
        case 'group':
          return comp(a.group, b.group);
        case 'stock':
          return comp(a.stock, b.stock);
        default:
          return comp(a.name, b.name);
      }
    });
    return list;
  }

  // Finally paginate
  List<Medicine> get _paged {
    final list = _sorted;
    final start = _page * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, list.length);
    if (start >= list.length) return const [];
    return list.sublist(start, end);
  }

  void _setSort(String key) {
    setState(() {
      if (_sortKey == key) {
        _ascending = !_ascending;
      } else {
        _sortKey = key;
        _ascending = true;
      }
      _page = 0; // reset to first page on sort
    });
  }

  void _resetToFirstPage() => setState(() => _page = 0);

  @override
  Widget build(BuildContext context) {
    final total = _sorted.length;
    final start = total == 0 ? 0 : _page * _rowsPerPage + 1;
    final end = total == 0
        ? 0
        : ((_page + 1) * _rowsPerPage).clamp(1, total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
        Row(
          children: [
            Text(
              'Inventory  ›  List of Medicines ($total)',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Add New Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('List of medicines available for sales.',
            style: TextStyle(color: Color(0xFF6B7280))),
        const SizedBox(height: 16),

        // Search + Filter row
        Row(
          children: [
            // Search
            SizedBox(
              width: 360,
              child: TextField(
                onChanged: (v) {
                  _query = v;
                  _resetToFirstPage();
                },
                decoration: const InputDecoration(
                  hintText: 'Search Medicine Inventory..',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Filter
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _groupFilter,
                  icon: const Icon(Icons.expand_more),
                  items: _groups
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) {
                    _groupFilter = v ?? 'All';
                    _resetToFirstPage();
                  },
                ),
              ),
            ),
            const Spacer(),
            // Rows per page
            Row(
              children: [
                const Text('Rows per page  ',
                    style: TextStyle(color: Color(0xFF6B7280))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _rowsPerPage,
                      items: const [8, 15, 25]
                          .map((n) =>
                              DropdownMenuItem<int>(value: n, child: Text('$n')))
                          .toList(),
                      onChanged: (n) {
                        if (n == null) return;
                        setState(() {
                          _rowsPerPage = n;
                          _page = 0;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Table
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  // header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        _Hdr(
                          'Medicine Name',
                          flex: 3,
                          active: _sortKey == 'name',
                          ascending: _ascending,
                          onTap: () => _setSort('name'),
                        ),
                        _Hdr(
                          'Medicine ID',
                          flex: 2,
                          active: _sortKey == 'id',
                          ascending: _ascending,
                          onTap: () => _setSort('id'),
                        ),
                        _Hdr(
                          'Group Name',
                          flex: 2,
                          active: _sortKey == 'group',
                          ascending: _ascending,
                          onTap: () => _setSort('group'),
                        ),
                        _Hdr(
                          'Stock in Qty',
                          flex: 1,
                          right: true,
                          active: _sortKey == 'stock',
                          ascending: _ascending,
                          onTap: () => _setSort('stock'),
                        ),
                        const _Hdr('Action', flex: 2, right: true, sortable: false),
                      ],
                    ),
                  ),
                  // rows
                  Expanded(
                    child: _paged.isEmpty
                        ? const Center(
                            child: Text('No results',
                                style: TextStyle(color: Color(0xFF6B7280))),
                          )
                        : ListView.separated(
                            itemCount: _paged.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                            itemBuilder: (context, i) {
                              final m = _paged[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    _Cell(m.name, flex: 3, weight: FontWeight.w600),
                                    _Cell(m.id, flex: 2),
                                    _Cell(m.group, flex: 2),
                                    _Cell('${m.stock}', flex: 1, right: true),
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () {},
                                          child: const Text('View Full Detail  »»'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  // footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Showing $start - $end of $total',
                          style: const TextStyle(color: Color(0xFF6B7280)),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _page > 0
                              ? () => setState(() => _page--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                          tooltip: 'Previous',
                        ),
                        const SizedBox(width: 4),
                        Text('Page ${total == 0 ? 0 : _page + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: ((_page + 1) * _rowsPerPage) < total
                              ? () => setState(() => _page++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                          tooltip: 'Next',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Hdr extends StatelessWidget {
  final String text;
  final int flex;
  final bool right;
  final bool sortable;
  final bool active;
  final bool ascending;
  final VoidCallback? onTap;

  const _Hdr(
    this.text, {
    this.flex = 1,
    this.right = false,
    this.sortable = true,
    this.active = false,
    this.ascending = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final arrow = !sortable
        ? null
        : active
            ? (ascending ? Icons.arrow_drop_up : Icons.arrow_drop_down)
            : Icons.unfold_more;

    final label = Row(
      mainAxisAlignment: right ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(width: 6),
        if (arrow != null) Icon(arrow, size: 18, color: const Color(0xFF9CA3AF)),
      ],
    );

    final content = sortable
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: label,
            ),
          )
        : label;

    return Expanded(flex: flex, child: content);
  }
}

class _Cell extends StatelessWidget {
  final String text;
  final int flex;
  final bool right;
  final FontWeight? weight;
  const _Cell(
    this.text, {
    this.flex = 1,
    this.right = false,
    this.weight,
  });

  @override
  Widget build(BuildContext context) {
    final child = Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: const Color(0xFF374151),
        fontWeight: weight ?? FontWeight.w500,
      ),
    );
    return Expanded(
      flex: flex,
      child: right
          ? Align(alignment: Alignment.centerRight, child: child)
          : child,
    );
  }
}