import 'package:flutter/material.dart';
import 'left_sos_screen.dart';
import 'right_settings_screen.dart';
import 'top_taxi_screen.dart';
import 'bottom_naviate_screen.dart';

class BlindHomeScreen extends StatelessWidget {
  const BlindHomeScreen({super.key});

  void _handleSwipe(BuildContext context, DragEndDetails details, Offset velocity) {
    final vx = velocity.dx;
    final vy = velocity.dy;

    if (vx.abs() > vy.abs()) {
      if (vx > 0) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RightSettingsScreen()));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LeftSosScreen()));
      }
    } else {
      if (vy > 0) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const BottomNavigateScreen()));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const TopTaxiScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          '시각장애인 홈',
          style: TextStyle(color: Color(0xFFFFD400)),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xFFFFD400)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.topCenter,
            child: Text(
              '시각장애인 전용 서비스',
              style: TextStyle(
                color: Color(0xFFFFE51F),
                fontSize: 20,
              ),
            ),
          ),
          const Spacer(),
          Center(
            child: GestureDetector(
              onPanEnd: (details) {
                _handleSwipe(context, details, details.velocity.pixelsPerSecond);
              },
              child: Container(
                width: screenWidth * 0.8,
                height: screenHeight * 2 / 3,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE51F),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
