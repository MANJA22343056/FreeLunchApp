import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:freeluchapp/admin/statistik_page.dart';

class SchoolMealBarChart extends StatefulWidget {
  final List<SchoolMealStats> schoolStats;
  final double maxYValue;

  const SchoolMealBarChart({
    super.key,
    required this.schoolStats,
    required this.maxYValue,
  });

  @override
  State<SchoolMealBarChart> createState() => _SchoolMealBarChartState();
}

class _SchoolMealBarChartState extends State<SchoolMealBarChart> {
  int? touchedGroupIndex;
  int? touchedRodIndex;

  @override
  Widget build(BuildContext context) {
    List<BarChartGroupData> barGroups = [];

    for (int i = 0; i < widget.schoolStats.length; i++) {
      final stat = widget.schoolStats[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: stat.confirmed.toDouble(),
              width: 10,
              borderRadius: BorderRadius.circular(2),
              color: Colors.greenAccent,
            ),
            BarChartRodData(
              toY: stat.unconfirmed.toDouble(),
              width: 10,
              borderRadius: BorderRadius.circular(2),
              color: Colors.redAccent,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (touchedGroupIndex != null && touchedRodIndex != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              () {
                final stat = widget.schoolStats[touchedGroupIndex!];
                final label =
                    touchedRodIndex == 0 ? 'Terkonfirmasi' : 'Belum Konfirmasi';
                final value =
                    touchedRodIndex == 0 ? stat.confirmed : stat.unconfirmed;
                return '${stat.schoolName}\n$label: $value';
              }(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: widget.schoolStats.isEmpty
              ? const Center(
                  child: Text(
                    'Tidak ada data statistik makan per sekolah.',
                    style: TextStyle(color: Colors.white54),
                    textAlign: TextAlign.center,
                  ),
                )
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: widget.maxYValue + (widget.maxYValue * 0.1),
                    barTouchData: BarTouchData(
                      enabled: true,
                      handleBuiltInTouches: true,
                      touchCallback: (event, response) {
                        setState(() {
                          if (event.isInterestedForInteractions &&
                              response != null &&
                              response.spot != null) {
                            touchedGroupIndex =
                                response.spot!.touchedBarGroupIndex;
                            touchedRodIndex =
                                response.spot!.touchedRodDataIndex;
                          } else {
                            touchedGroupIndex = null;
                            touchedRodIndex = null;
                          }
                        });
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= widget.schoolStats.length) {
                              return const SizedBox.shrink();
                            }
                            String schoolName =
                                widget.schoolStats[value.toInt()].schoolName;
                            return SideTitleWidget(
                              space: 5,
                              meta: meta,
                              child: Text(
                                schoolName,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                            );
                          },
                          reservedSize: 30,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10),
                            );
                          },
                          reservedSize: 28,
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white.withOpacity(0.1),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2), width: 1),
                    ),
                    barGroups: barGroups,
                  ),
                ),
        ),
      ],
    );
  }
}
