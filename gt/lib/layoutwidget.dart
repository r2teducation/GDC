import 'package:flutter/material.dart';

class LayoutWidget extends StatefulWidget {
  const LayoutWidget({super.key});

  @override
  State<LayoutWidget> createState() => _LayoutWidgetState();
}

class _LayoutWidgetState extends State<LayoutWidget> {
  int _activeTab = -1; // -1 = Home
  bool _showSubTabs = false;

  double _subTabLeft = 0;
  double _subTabWidth = 0;

  final List<GlobalKey> _tabKeys =
      List.generate(5, (_) => GlobalKey());

  final Map<int, List<String>> _subTabs = {
    0: ['Sub Tab 1.1', 'Sub Tab 1.2', 'Sub Tab 1.3', 'Sub Tab 1.4', 'Sub Tab 1.5'],
    1: ['Sub Tab 2.1', 'Sub Tab 2.2', 'Sub Tab 2.3', 'Sub Tab 2.4', 'Sub Tab 2.5'],
    2: ['Sub Tab 3.1', 'Sub Tab 3.2', 'Sub Tab 3.3', 'Sub Tab 3.4', 'Sub Tab 3.5'],
    3: ['Sub Tab 4.1', 'Sub Tab 4.2', 'Sub Tab 4.3', 'Sub Tab 4.4', 'Sub Tab 4.5'],
    4: ['Sub Tab 5.1', 'Sub Tab 5.2', 'Sub Tab 5.3', 'Sub Tab 5.4', 'Sub Tab 5.5'],
  };

  // ───────────────── TAB OPEN (MEASURE POSITION + WIDTH) ─────────────────

  void _openSubTabs(int index) {
    final key = _tabKeys[index];
    final box = key.currentContext!.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    setState(() {
      _activeTab = index;
      _subTabLeft = offset.dx;
      _subTabWidth = box.size.width; // 🔥 match tab width
      _showSubTabs = true;
    });
  }

  // ───────────────── HOME CLICK ─────────────────

  void _goHome() {
    setState(() {
      _activeTab = -1;
      _showSubTabs = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9).withOpacity(0.98),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _topBar(),
                _softDivider(),
                Expanded(child: _content()),
              ],
            ),

            // ───────── SUB TABS (PERFECTLY ALIGNED + SAME WIDTH) ─────────
            if (_showSubTabs && _activeTab >= 0)
              Positioned(
                top: 56,
                left: _subTabLeft,
                child: _subTabsPanel(),
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────── TOP BAR ─────────────────

  Widget _topBar() {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            const Text(
              'GDC',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 16),

            _homeIcon(),

            const SizedBox(width: 20),

            Expanded(
              child: Row(
                children: List.generate(
                  5,
                  (i) => Expanded(child: _tabBox('Tab ${i + 1}', i)),
                ),
              ),
            ),

            const SizedBox(width: 20),

            _logoutIcon(),
          ],
        ),
      ),
    );
  }

  // ───────────────── TAB BOX ─────────────────

  Widget _tabBox(String label, int index) {
    final isActive = _activeTab == index;

    return InkWell(
      key: _tabKeys[index],
      onTap: () => _openSubTabs(index),
      splashColor: Colors.black12,
      highlightColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFE5E7EB)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 4),
            if (isActive)
              Container(
                height: 2,
                width: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────── SUB TABS PANEL ─────────────────

  Widget _subTabsPanel() {
    final items = _subTabs[_activeTab]!;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: _subTabWidth, // 🔥 matches main tab width
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map(_subTabItem).toList(),
        ),
      ),
    );
  }

  Widget _subTabItem(String label) {
    return InkWell(
      onTap: () => setState(() => _showSubTabs = false),
      splashColor: Colors.black12,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  // ───────────────── CONTENT ─────────────────

  Widget _content() {
    if (_activeTab == -1) {
      return const Center(
        child: Text(
          'Home in Progress',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
      );
    }

    return const Center(
      child: Text(
        'Content',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    );
  }

  // ───────────────── ICONS ─────────────────

  Widget _homeIcon() {
    return InkWell(
      onTap: _goHome,
      splashColor: Colors.black12,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(
          Icons.home_outlined,
          size: 22,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  Widget _logoutIcon() {
    return InkWell(
      onTap: () {},
      splashColor: Colors.black12,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(
          Icons.power_settings_new,
          size: 22,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _softDivider() => const Divider(
        height: 1,
        thickness: 0.6,
        color: Color(0xFFEDEFF2),
      );
}