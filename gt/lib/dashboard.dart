import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class DashboardWidget extends StatelessWidget {
  const DashboardWidget({super.key});

  static const Color _bgColor = Color(0xFFF5F5F5);
  static const Color _panelBorder = Color(0xFF2B2B2B);
  static const Color _gridColor = Color(0xFFBDBDBD);
  static const Color _textColor = Colors.black;
  static const Color _valueChipColor = Color(0xFF586E7C);

  // Finance dummy weekly data
  static const List<double> _weeklyAmounts = [
    24000,
    31000,
    25000,
    37000,
    28000,
    42000,
    21000,
  ];

  // Weekly collection detailed breakup (hardcoded for now)
  static const List<DayFinanceBreakdown> _weeklyBreakdown = [
    DayFinanceBreakdown(consultation: 2000, treatment: 21000, medicines: 1000),
    DayFinanceBreakdown(consultation: 3000, treatment: 26000, medicines: 2000),
    DayFinanceBreakdown(consultation: 2500, treatment: 20000, medicines: 2500),
    DayFinanceBreakdown(consultation: 4000, treatment: 30000, medicines: 3000),
    DayFinanceBreakdown(consultation: 3500, treatment: 22000, medicines: 2500),
    DayFinanceBreakdown(consultation: 4500, treatment: 35000, medicines: 2500),
    DayFinanceBreakdown(consultation: 2000, treatment: 18000, medicines: 1000),
  ];

  // Finance dummy monthly data
  static const List<double> _monthlyAmounts = [
    100000,
    145000,
    168000,
    222000,
    228000,
    278000,
  ];

  // Patients dummy weekly data
  static const List<double> _weeklyPatients = [
    32,
    48,
    36,
    60,
    44,
    72,
    28,
  ];

  // Patients dummy monthly data
  static const List<double> _monthlyPatients = [
    120,
    180,
    240,
    310,
    390,
    460,
  ];

  static const List<String> _weekLabels = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  static const List<String> _monthLabels = [
    '1st',
    '5th',
    '10th',
    '15th',
    '20th',
    '31st',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _bgColor,
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                SizedBox(height: 8),

                // Finance Overview
                Text(
                  'Finance Overview',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: _textColor,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 10),
                _HeaderUnderline(),
                SizedBox(height: 26),
                _CollectionLineCard(
                  title: 'Weekly Revenue',
                  values: DashboardWidget._weeklyAmounts,
                  labels: DashboardWidget._weekLabels,
                  maxY: 50000,
                  interval: 10000,
                  xAxisTitle: 'Day',
                  valuePrefix: '₹',
                  isCurrency: true,
                  breakdownData: DashboardWidget._weeklyBreakdown,
                ),
                SizedBox(height: 24),
                _CollectionLineCard(
                  title: 'Monthly Revenue',
                  values: DashboardWidget._monthlyAmounts,
                  labels: DashboardWidget._monthLabels,
                  maxY: 300000,
                  interval: 100000,
                  xAxisTitle: 'Date of Current Month',
                  valuePrefix: '₹',
                  isCurrency: true,
                ),

                SizedBox(height: 44),

                // Patients Overview
                Text(
                  'Patients Overview',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: _textColor,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 10),
                _HeaderUnderline(),
                SizedBox(height: 26),
                _CollectionLineCard(
                  title: 'Weekly Patients Flow',
                  values: DashboardWidget._weeklyPatients,
                  labels: DashboardWidget._weekLabels,
                  maxY: 100,
                  interval: 20,
                  xAxisTitle: 'Day',
                  valuePrefix: '',
                  isCurrency: false,
                ),
                SizedBox(height: 24),
                _CollectionLineCard(
                  title: 'Monthly Patients Flow',
                  values: DashboardWidget._monthlyPatients,
                  labels: DashboardWidget._monthLabels,
                  maxY: 500,
                  interval: 100,
                  xAxisTitle: 'Date of Current Month',
                  valuePrefix: '',
                  isCurrency: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DayFinanceBreakdown {
  final int consultation;
  final int treatment;
  final int medicines;

  const DayFinanceBreakdown({
    required this.consultation,
    required this.treatment,
    required this.medicines,
  });

  int get total => consultation + treatment + medicines;
}

class _HeaderUnderline extends StatelessWidget {
  const _HeaderUnderline();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 520,
      height: 1.4,
      color: Colors.black54,
    );
  }
}

class _CollectionLineCard extends StatelessWidget {
  final String title;
  final List<double> values;
  final List<String> labels;
  final double maxY;
  final double interval;
  final String xAxisTitle;
  final String valuePrefix;
  final bool isCurrency;
  final List<DayFinanceBreakdown>? breakdownData;

  const _CollectionLineCard({
    required this.title,
    required this.values,
    required this.labels,
    required this.maxY,
    required this.interval,
    required this.xAxisTitle,
    required this.valuePrefix,
    required this.isCurrency,
    this.breakdownData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 450,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DashboardWidget._panelBorder, width: 1.1),
      ),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: DashboardWidget._textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            width: 300,
            height: 1.2,
            color: Colors.black54,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
              child: Stack(
                children: [
                  LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: (values.length - 1).toDouble(),
                      minY: 0,
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: interval,
                        verticalInterval: 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: DashboardWidget._gridColor,
                            strokeWidth: 0.8,
                            dashArray: [4, 4],
                          );
                        },
                        getDrawingVerticalLine: (value) {
                          return FlLine(
                            color: DashboardWidget._gridColor,
                            strokeWidth: 0.8,
                            dashArray: [4, 4],
                          );
                        },
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: const Border(
                          left: BorderSide(color: Colors.black, width: 1.4),
                          bottom: BorderSide(color: Colors.black, width: 1.4),
                          right: BorderSide(color: Colors.transparent),
                          top: BorderSide(color: Colors.transparent),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          axisNameWidget: const SizedBox(),
                          axisNameSize: 0,
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: interval,
                            reservedSize: 85,
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  isCurrency
                                      ? _formatAmount(value.toInt())
                                      : value.toInt().toString(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          axisNameWidget: Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Text(
                              xAxisTitle,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          axisNameSize: 38,
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= labels.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  labels[index],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        handleBuiltInTouches: false,
                        touchCallback: (event, response) {
                          if (event is FlTapUpEvent &&
                              response != null &&
                              response.lineBarSpots != null &&
                              response.lineBarSpots!.isNotEmpty) {
                            final spot = response.lineBarSpots!.first;
                            final index = spot.x.toInt();

                            if (breakdownData != null &&
                                index >= 0 &&
                                index < breakdownData!.length) {
                              showDialog(
                                context: context,
                                builder: (_) => _FinanceBreakdownDialog(
                                  day: labels[index],
                                  data: breakdownData![index],
                                ),
                              );
                            }
                          }
                        },
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            values.length,
                            (index) => FlSpot(index.toDouble(), values[index]),
                          ),
                          isCurved: false,
                          color: Colors.black,
                          barWidth: 2.4,
                          isStrokeCapRound: false,
                          belowBarData: BarAreaData(show: false),
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) {
                              return FlDotCirclePainter(
                                radius: 4.2,
                                color: Colors.black,
                                strokeWidth: 0,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  IgnorePointer(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        const leftReserved = 72.0;
                        const rightPadding = 14.0;
                        const topPadding = 8.0;
                        final chartWidth =
                            constraints.maxWidth - leftReserved - rightPadding;
                        final chartHeight = constraints.maxHeight - 30;

                        return Stack(
                          children: List.generate(values.length, (index) {
                            final xRatio = values.length == 1
                                ? 0.0
                                : index / (values.length - 1);
                            final yRatio = values[index] / maxY;

                            final dx = leftReserved + (chartWidth * xRatio);
                            final dy =
                                topPadding + (chartHeight * (1 - yRatio));

                            final chipText = isCurrency
                                ? '$valuePrefix${_formatAmount(values[index].toInt())}'
                                : values[index].toInt().toString();

                            return Positioned(
                              left: _resolveChipLeft(
                                dx: dx,
                                chartWidth: constraints.maxWidth,
                              ),
                              top: (dy - 50)
                                  .clamp(0, constraints.maxHeight - 30),
                              child: _ValueChip(text: chipText),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _resolveChipLeft({
    required double dx,
    required double chartWidth,
  }) {
    const chipWidth = 76.0;
    final proposed = dx - (chipWidth / 2);
    if (proposed < 0) return 0;
    if (proposed > chartWidth - chipWidth) return chartWidth - chipWidth;
    return proposed;
  }
}

class _ValueChip extends StatelessWidget {
  final String text;

  const _ValueChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: DashboardWidget._valueChipColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _FinanceBreakdownDialog extends StatelessWidget {
  final String day;
  final DayFinanceBreakdown data;

  const _FinanceBreakdownDialog({
    required this.day,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$day Collection Details',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _breakdownRow('Consultation', data.consultation),
            const SizedBox(height: 10),
            _breakdownRow('Treatment', data.treatment),
            const SizedBox(height: 10),
            _breakdownRow('Medicines', data.medicines),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _breakdownRow('Total', data.total, isTotal: true),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: const Color(0xFFF2F2F2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _breakdownRow(String label, int amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 15 : 14,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            color: Colors.black,
          ),
        ),
        Text(
          '₹${_formatAmount(amount)}',
          style: TextStyle(
            fontSize: isTotal ? 15 : 14,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

String _formatAmount(int value) {
  final str = value.toString();
  if (str.length <= 3) return str;

  final lastThree = str.substring(str.length - 3);
  final remaining = str.substring(0, str.length - 3);
  final parts = <String>[];

  for (int i = remaining.length; i > 0; i -= 2) {
    final start = (i - 2) < 0 ? 0 : i - 2;
    parts.insert(0, remaining.substring(start, i));
  }

  return '${parts.join(',')},$lastThree';
}