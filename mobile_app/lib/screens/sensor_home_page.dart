import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sensor_reading.dart';

enum ChartFilter { last10min, last1hour, all }

extension ChartFilterExtension on ChartFilter {
  String get label {
    switch (this) {
      case ChartFilter.last10min:
        return "Last 10 min";
      case ChartFilter.last1hour:
        return "Last 1 hour";
      case ChartFilter.all:
        return "All";
    }
  }
}

class SensorHomePage extends StatefulWidget {
  @override
  State<SensorHomePage> createState() => _SensorHomePageState();
}

class _SensorHomePageState extends State<SensorHomePage> {
  List<SensorReading> readings = [];
  bool loading = true;
  String? error;
  Timer? _autoRefreshTimer;
  bool _isFirstLoad = true;
  ChartFilter _selectedFilter = ChartFilter.last10min;

  static const double tempThreshold = 26;
  static const double humThreshold = 70;

  @override
  void initState() {
    super.initState();
    fetchReadings(isFirstLoad: true);
    _autoRefreshTimer = Timer.periodic(
      Duration(seconds: 10),
      (_) => fetchReadings(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchReadings({bool isFirstLoad = false}) async {
    if (isFirstLoad) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final url =
          Uri.parse('https://humancc.site/syasyaaina/sensor_api/fetch.php');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        if (!mounted) return;
        setState(() {
          readings = jsonData
              .map((e) => SensorReading.fromJson(e))
              .toList()
              .reversed
              .toList();
          loading = false;
          error = null;
          _isFirstLoad = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          error = 'HTTP ${response.statusCode}: Failed to load data';
          loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Error: $e';
        loading = false;
      });
    }
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[800])),
      ],
    );
  }

  Widget _relayStatus(bool isRelayOn) {
    final color = isRelayOn ? Colors.red : Colors.green;
    final icon = isRelayOn ? Icons.flash_on : Icons.flash_off;
    final text = isRelayOn ? "ON" : "OFF";
    return Container(
      margin: EdgeInsets.only(bottom: 8, top: 8),
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 6),
          Text(
            "Relay Status: ",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  List<SensorReading> _getFilteredReadings() {
    if (readings.isEmpty) return [];
    final now = DateTime.now();
    switch (_selectedFilter) {
      case ChartFilter.last10min:
        return readings
            .where(
                (r) => r.timestamp.isAfter(now.subtract(Duration(minutes: 10))))
            .toList();
      case ChartFilter.last1hour:
        return readings
            .where((r) => r.timestamp.isAfter(now.subtract(Duration(hours: 1))))
            .toList();
      case ChartFilter.all:
        return readings;
    }
  }

  Widget _sensorChart(List<SensorReading> readings) {
    if (readings.isEmpty) return Center(child: Text("No chart data"));

    final tempGradient =
        LinearGradient(colors: [Colors.redAccent, Colors.orangeAccent]);
    final humGradient =
        LinearGradient(colors: [Colors.blueAccent, Colors.cyanAccent]);

    int total = readings.length;
    int labelCount = 9;
    List<int> labelIndexes = [];

    if (total <= labelCount) {
      labelIndexes = List.generate(total, (i) => i);
    } else {
      double step = (total - 1) / (labelCount - 1);
      for (int i = 0; i < labelCount; i++) {
        labelIndexes.add((i * step).round());
      }
    }

    return Container(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFe7e6fb), Color.fromARGB(255, 254, 254, 255)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 10,
                  verticalInterval: 2,
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color.fromARGB(104, 255, 255, 255)
                        .withOpacity(0.18),
                    strokeWidth: 1.3,
                  ),
                  getDrawingVerticalLine: (value) => FlLine(
                    color: const Color.fromARGB(104, 255, 255, 255)
                        .withOpacity(0.15),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: 10,
                      getTitlesWidget: (value, meta) => Text(
                        "${value.toInt()}",
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF1E285F)),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 1, // required but not used
                      getTitlesWidget: (value, meta) {
                        int i = value.round();
                        if (!labelIndexes.contains(i) || i < 0 || i >= total)
                          return Container();
                        final t = readings[i].timestamp;
                        return Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}",
                            style: TextStyle(
                                fontSize: 10, color: Color(0xFF1E285F)),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.22),
                    width: 2,
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: readings
                        .asMap()
                        .entries
                        .map((e) =>
                            FlSpot(e.key.toDouble(), e.value.temperature))
                        .toList(),
                    isCurved: true,
                    gradient: tempGradient,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.redAccent.withOpacity(0.11),
                          Colors.transparent
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: readings
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value.humidity))
                        .toList(),
                    isCurved: true,
                    gradient: humGradient,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color.fromARGB(255, 164, 192, 239)
                              .withOpacity(0.12),
                          Colors.transparent
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.black.withOpacity(0.82),
                    tooltipRoundedRadius: 10,
                    getTooltipItems: (spots) {
                      return spots.map((touchedSpot) {
                        final reading = readings[touchedSpot.x.toInt()];
                        final timeLabel =
                            "${reading.timestamp.hour.toString().padLeft(2, '0')}:${reading.timestamp.minute.toString().padLeft(2, '0')}:${reading.timestamp.second.toString().padLeft(2, '0')}";
                        return LineTooltipItem(
                          touchedSpot.bar.gradient?.colors.first ==
                                  Colors.redAccent
                              ? "Temp: ${reading.temperature}°C\nTime: $timeLabel"
                              : "Humidity: ${reading.humidity}%\nTime: $timeLabel",
                          TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyTable(List<SensorReading> readings) {
    if (readings.isEmpty) {
      return Center(child: Text("No history data"));
    }
    int displayCount = 15;
    final data = readings.length > displayCount
        ? readings.sublist(readings.length - displayCount)
        : readings;

    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "History",
            style: GoogleFonts.inter(
              color: Color(0xFF1E285F),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF8FAFF),
                  Color(0xFFE6EEFA),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12.0, horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Time",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF1E285F),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Temp (°C)",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          "Humidity (%)",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                ...data.map((r) => Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "${r.timestamp.hour.toString().padLeft(2, '0')}:${r.timestamp.minute.toString().padLeft(2, '0')}:${r.timestamp.second.toString().padLeft(2, '0')}",
                              style: TextStyle(
                                  fontSize: 13, color: Colors.black87),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              r.temperature.toStringAsFixed(1),
                              style: TextStyle(
                                  fontSize: 13, color: Colors.black87),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              r.humidity.toStringAsFixed(1),
                              style: TextStyle(
                                  fontSize: 13, color: Colors.black87),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    )),
                if (readings.length > displayCount)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Center(
                      child: Text(
                        "…",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latest = readings.isNotEmpty ? readings.last : null;

    bool highTemp = false;
    bool highHum = false;
    bool hasData = latest != null;

    if (hasData) {
      highTemp = latest!.temperature > tempThreshold;
      highHum = latest.humidity > humThreshold;
    }

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (!hasData) {
      statusText = "Status: --";
      statusColor = Colors.grey;
      statusIcon = Icons.help_outline;
    } else if (highTemp && highHum) {
      statusText = "Status: High Temperature & Humidity!";
      statusColor = Colors.red;
      statusIcon = Icons.warning_amber_rounded;
    } else if (highTemp) {
      statusText = "Status: High Temperature!";
      statusColor = Colors.red;
      statusIcon = Icons.warning_amber_rounded;
    } else if (highHum) {
      statusText = "Status: High Humidity!";
      statusColor = Colors.red;
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusText = "Status: Normal";
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    }

    String latestTimestamp = latest != null
        ? "${latest.timestamp.hour.toString().padLeft(2, '0')}:${latest.timestamp.minute.toString().padLeft(2, '0')}:${latest.timestamp.second.toString().padLeft(2, '0')}  ${latest.timestamp.day.toString().padLeft(2, '0')}/${latest.timestamp.month.toString().padLeft(2, '0')}/${latest.timestamp.year}"
        : "--";

    final filteredReadings = _getFilteredReadings();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text('SmartSense',
            style: TextStyle(
                color: Color(0xFF293980),
                fontWeight: FontWeight.bold,
                fontSize: 24)),
        centerTitle: true,
      ),
      body: loading && _isFirstLoad
          ? Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : readings.isEmpty
                  ? Center(child: Text('No sensor data'))
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: LinearGradient(
                              colors: [Colors.white, Color(0xFFe3eafe)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.symmetric(
                              vertical: 18, horizontal: 22),
                          margin: EdgeInsets.only(bottom: 14),
                          child: Column(
                            children: [
                              Text(
                                'Sensor Data',
                                style: GoogleFonts.inter(
                                  color: Color(0xFF1E285F),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _infoTile(
                                      icon: Icons.thermostat,
                                      label: "Temperature",
                                      value:
                                          "${latest?.temperature.toStringAsFixed(1) ?? "--"}°C",
                                      color: Colors.red),
                                  Container(
                                      width: 1,
                                      height: 36,
                                      color: Colors.grey.shade300),
                                  _infoTile(
                                      icon: Icons.water_drop,
                                      label: "Humidity",
                                      value:
                                          "${latest?.humidity.toStringAsFixed(1) ?? "--"}%",
                                      color: Colors.blue),
                                ],
                              ),
                              SizedBox(height: 10),
                              _relayStatus(hasData && (highTemp || highHum)),
                              AnimatedContainer(
                                duration: Duration(milliseconds: 350),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.13),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 10,
                                  children: [
                                    Icon(statusIcon,
                                        color: statusColor, size: 20),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Icon(Icons.access_time,
                                        color: Colors.grey, size: 18),
                                    Text(
                                      latestTimestamp,
                                      style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('View:',
                                style: TextStyle(
                                    fontSize: 14, color: Color(0xFF1E285F))),
                            SizedBox(width: 8),
                            DropdownButton<ChartFilter>(
                              value: _selectedFilter,
                              underline: SizedBox(),
                              items: ChartFilter.values
                                  .map(
                                    (f) => DropdownMenuItem<ChartFilter>(
                                      value: f,
                                      child: Text(
                                        f.label,
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedFilter = value!;
                                });
                              },
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: 4.0, left: 6, right: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.thermostat,
                                  color: Colors.redAccent, size: 20),
                              SizedBox(width: 4),
                              Text(
                                "Temperature",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(width: 18),
                              Icon(Icons.water_drop,
                                  color: Colors.blueAccent, size: 20),
                              SizedBox(width: 4),
                              Text(
                                "Humidity",
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          padding:
                              EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                          height: 340,
                          child: _sensorChart(filteredReadings),
                        ),
                        _historyTable(filteredReadings),
                        SizedBox(height: 24),
                      ],
                    ),
    );
  }
}
