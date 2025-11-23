import 'package:flutter/material.dart';

class DashboardWidget extends StatelessWidget {
  const DashboardWidget({super.key});

  // Palette
  static const _bg = Color(0xFFF3F4F6);
  static const _title = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _cardBorder = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            const Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _title,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'A quick data overview of the inventory.',
              style: TextStyle(color: _muted, fontSize: 16),
            ),
            const SizedBox(height: 18),

            // KPI CARDS (square, colored outline + pastel bottom bar)
            LayoutBuilder(
              builder: (context, c) {
                final max = c.maxWidth;
                final size = _squareSize(max);
                return Wrap(
                  spacing: 16, // keep in sync with _squareSize()
                  runSpacing: 16,
                  children: [
                    _KpiCard(
                      size: size,
                      border: const Color(0xFF22C55E),
                      bottomFill: const Color(0xFF22C55E).withOpacity(.20),
                      icon: Icons.verified_user_outlined,
                      title: 'Good',
                      subtitle: 'Inventory Status',
                      actionText: 'View Detailed Report',
                    ),
                    _KpiCard(
                      size: size,
                      border: const Color(0xFFEAB308),
                      bottomFill: const Color(0xFFFDE68A),
                      icon: Icons.payments_outlined,
                      title: 'Rs. 8,55,875',
                      subtitle: 'Revenue  ·  Jan 2022',
                      actionText: 'View Detailed Report',
                    ),
                    _KpiCard(
                      size: size,
                      border: const Color(0xFF38BDF8),
                      bottomFill: const Color(0xFF93C5FD),
                      icon: Icons.medical_services_outlined,
                      title: '298',
                      subtitle: 'Medicines Available',
                      actionText: 'Visit Inventory',
                    ),
                    _KpiCard(
                      size: size,
                      border: const Color(0xFFEF4444),
                      bottomFill: const Color(0xFFFECACA),
                      icon: Icons.warning_amber_rounded,
                      title: '01',
                      subtitle: 'Medicine Shortage',
                      actionText: 'Resolve Now',
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // SUMMARY ROWS (unchanged)
            LayoutBuilder(
              builder: (_, c) {
                final max = c.maxWidth;
                final twoCol = max > 1024;
                return Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: [
                    _PanelCard(
                      width: twoCol ? (max - 18) / 2 : max,
                      title: 'Inventory',
                      trailingAction: 'Go to Configuration',
                      sides: const [
                        _Metric(label: 'Total no of Medicines', value: '298'),
                        _Metric(label: 'Medicine Groups', value: '24'),
                      ],
                    ),
                    _PanelCard(
                      width: twoCol ? (max - 18) / 2 : max,
                      title: 'Quick Report',
                      trailingAction: 'January 2022',
                      sides: const [
                        _Metric(
                            label: 'Qty of Medicines Sold', value: '70,856'),
                        _Metric(label: 'Invoices Generated', value: '5,288'),
                      ],
                    ),
                    _PanelCard(
                      width: twoCol ? (max - 18) / 2 : max,
                      title: 'My Pharmacy',
                      trailingAction: 'Go to User Management',
                      sides: const [
                        _Metric(label: 'Total no of Suppliers', value: '04'),
                        _Metric(label: 'Total no of Users', value: '05'),
                      ],
                    ),
                    _PanelCard(
                      width: twoCol ? (max - 18) / 2 : max,
                      title: 'Customers',
                      trailingAction: 'Go to Customers Page',
                      sides: const [
                        _Metric(label: 'Total no of Customers', value: '845'),
                        _Metric(
                            label: 'Frequently bought Item',
                            value: 'Adalimumab'),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Responsive square size helper:
  /// - 4 columns for >= 840px (desktop & large tablets)
  /// - 3 columns for 640–839px
  /// - 2 columns for 440–639px
  /// - 1 column below 440px
  /// Then shrink a bit (-8) to make them look “cute” and leave comfy gutters.
  static double _squareSize(double max) {
    const gap = 16.0;
    int cols;
    if (max >= 840) {
      cols = 4;
    } else if (max >= 640) {
      cols = 3;
    } else if (max >= 440) {
      cols = 2;
    } else {
      cols = 1;
    }
    final base = (max - gap * (cols - 1)) / cols;
    return (base - 8)
        .clamp(120.0, 9999.0); // small “cute” shrink with a sane min
  }
}

class _KpiCard extends StatelessWidget {
  final double size; // width == height
  final Color border; // colored outline + icon color
  final Color bottomFill; // pastel bottom bar fill
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionText;

  const _KpiCard({
    required this.size,
    required this.border,
    required this.bottomFill,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionText,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 12.0;

    return SizedBox(
      width: size,
      height: size, // perfect square
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: border, width: 1.2),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // top content
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: border, size: 34),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            // Bottom filled action bar (rounded bottom corners + thin top rule)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(radius),
                bottomRight: Radius.circular(radius),
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: bottomFill,
                  border: Border(
                    top: BorderSide(color: border, width: 1.2),
                  ),
                ),
                child: TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.chevron_right,
                      size: 18, color: Color(0xFF374151)),
                  label: Text(
                    actionText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: border,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(radius),
                        bottomRight: Radius.circular(radius),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCardStyle {
  static const muted = Color(0xFF6B7280);
  static const cardBorder = Color(0xFFE5E7EB);
}

class _PanelCard extends StatelessWidget {
  final double width;
  final String title;
  final String trailingAction;
  final List<_Metric> sides;

  const _PanelCard({
    required this.width,
    required this.title,
    required this.trailingAction,
    required this.sides,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _DashboardCardStyle.cardBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: _DashboardCardStyle.cardBorder)),
              ),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _DashboardCardStyle.muted,
                    ),
                  ),
                  const Spacer(),
                  Text(trailingAction,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right,
                      size: 18, color: _DashboardCardStyle.muted),
                ],
              ),
            ),
            // content (two columns)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Expanded(child: _MetricBlock(metric: sides[0])),
                  const SizedBox(width: 18),
                  Expanded(child: _MetricBlock(metric: sides[1])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});
}

class _MetricBlock extends StatelessWidget {
  final _Metric metric;
  const _MetricBlock({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _DashboardCardStyle.muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(metric.label,
            style: const TextStyle(color: _DashboardCardStyle.muted)),
      ],
    );
  }
}
