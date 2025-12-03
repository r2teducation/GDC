import 'package:flutter/material.dart';
import 'package:gt/dashboard.dart';
import 'package:gt/patient/profilewidget.dart';

class AutoCareApp extends StatelessWidget {
  const AutoCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AutoCare',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        fontFamily: 'SF Pro',
        inputDecorationTheme: const InputDecorationTheme(
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFFD1D5DB)),
          ),
        ),
      ),
      home: const AutoCareHome(),
    );
  }
}

class AutoCareHome extends StatefulWidget {
  const AutoCareHome({super.key});
  @override
  State<AutoCareHome> createState() => _AutoCareHomeState();
}

class _AutoCareHomeState extends State<AutoCareHome> {
  int selected = 0;
  bool tab4Open = true;

  String? _route; // null -> dashboard

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selected: selected,
            tab4Open: tab4Open,
            onSelect: (i) {
              setState(() {
                selected = i;
                _route = (i == 0) ? 'dashboard' : null;
              });
            },
            onToggle4: () => setState(() => tab4Open = !tab4Open),
            onOpenSub4_1: () => setState(() => _route = 'sub4_1'),
            onOpenSub4_2: () => setState(() => _route = 'sub4_2'),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 0), // 🔥 Top bar removed completely

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: switch (_route) {
                      'dashboard' => const DashboardWidget(),
                      'sub4_1' => const ProfileWidget(),
                      'sub4_2' =>
                        const Center(child: Text('Development in Progress')),
                      _ => const DashboardWidget(),
                    },
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  final bool tab4Open;
  final VoidCallback onToggle4;
  final VoidCallback onOpenSub4_1;
  final VoidCallback onOpenSub4_2;

  const _Sidebar({
    required this.selected,
    required this.onSelect,
    required this.tab4Open,
    required this.onToggle4,
    required this.onOpenSub4_1,
    required this.onOpenSub4_2,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0F172A);
    const active = Color(0xFF14B8A6);

    return Container(
      width: 280,
      color: bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand bar
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(color: Color(0xFF0B1220)),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/gtlogo.png',
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Global Dental Clinic',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Profile card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundImage: AssetImage('assets/images/akshara.png'),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ramesh',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          _Dot(color: Color(0xFF22C55E)),
                          SizedBox(width: 6),
                          Text('Super Admin',
                              style: TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                      onPressed: () {},
                      icon:
                          const Icon(Icons.more_vert, color: Color(0xFF9CA3AF)))
                ],
              ),
            ),

            Expanded(
              child: ListView(
                children: [
                  _SideItem(
                    icon: Icons.space_dashboard_outlined,
                    label: 'Dashboard',
                    active: selected == 0,
                    onTap: () => onSelect(0),
                  ),
                  const SizedBox(height: 6),

                  // PATIENT GROUP
                  _Collapsible(
                    icon: Icons.people_alt_outlined,
                    label: 'Patient',
                    open: tab4Open,
                    onToggle: onToggle4,
                    children: [
                      _SideSubItem(
                        label: 'Profile',
                        onTap: onOpenSub4_1,
                      ),
                      _SideSubItem(
                        label: 'Visits',
                        onTap: onOpenSub4_2,
                      ),
                      _SideSubItem(label: 'Medical', onTap: () {}),
                      _SideSubItem(label: 'Dental', onTap: () {}),
                      _SideSubItem(label: 'Examination', onTap: () {}),
                      _SideSubItem(label: 'Records', onTap: () {}),
                    ],
                  ),

                  const SizedBox(height: 6),
                  const _SideItem(icon: Icons.map_outlined, label: 'Tab 5'),
                  const _SideItem(icon: Icons.help_outline, label: 'Tab 6'),

                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text('Powered by Gutta © 2022',
                            style: TextStyle(
                                color: Color(0xFF6B7280), fontSize: 12)),
                        Spacer(),
                        Text('v 1.1.2',
                            style: TextStyle(
                                color: Color(0xFF6B7280), fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _SideItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFF0D2630) : Colors.transparent;
    final borderColor = active ? const Color(0xFF14B8A6) : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: borderColor, width: 4)),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      )),
                ),
                if (active)
                  const Icon(Icons.check, size: 16, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Collapsible extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool open;
  final VoidCallback? onToggle;
  final List<Widget> children;
  final Widget? trailingBadge;

  const _Collapsible({
    required this.icon,
    required this.label,
    required this.open,
    this.onToggle,
    required this.children,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onToggle,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (trailingBadge != null) trailingBadge!,
                    Icon(
                      open ? Icons.expand_more : Icons.chevron_right,
                      color: const Color(0xFF9CA3AF),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (open)
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Column(children: children),
          ),
      ],
    );
  }
}

class _SideSubItem extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _SideSubItem({
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 8),
      child: Material(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const SizedBox(width: 4),
                Text(
                  label,
                  style:
                      const TextStyle(color: Color(0xFFE5E7EB), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}