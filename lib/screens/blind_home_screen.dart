import 'package:flutter/material.dart';

class BlindHomeScreen extends StatelessWidget {
  const BlindHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 화면 높이 가져오기
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black, // 배경색 블랙
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
                color: Color(0xFFFFD400),
                fontSize: 20,
              ),
            ),
          ),
          const Spacer(),
          Center(
            child: Container(
              width: screenWidth * 0.8,  // 가로는 화면의 80%
              height: screenHeight * 2 / 3,  // 세로는 화면의 2/3
              decoration: BoxDecoration(
                color: const Color(0xFFFFD400),
                borderRadius: BorderRadius.circular(16), // 모서리 둥글게
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
