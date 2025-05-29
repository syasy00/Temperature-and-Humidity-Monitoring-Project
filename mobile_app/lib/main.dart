import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/sensor_home_page.dart';

void main() => runApp(SenseViewApp());

class SenseViewApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: Color(0xFF1E285F),
        ),
      ),
      home: SensorHomePage(),
    );
  }
}
