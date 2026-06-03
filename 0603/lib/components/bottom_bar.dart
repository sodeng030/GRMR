import 'package:flutter/material.dart';

import '../screens/storage_screen.dart';
import '../screens/profile_screen.dart';

class CustomBottomNavBar extends StatelessWidget {
  // 0: 보관함, 1: 메인, 2: 프로필, -1: 상세화면
  final int currentIndex;

  const CustomBottomNavBar({super.key, this.currentIndex = -1});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x4CFFEAB5),
            blurRadius: 30,
            offset: Offset(0, -20),
            spreadRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 보관함 버튼
          GestureDetector(
            onTap: () {
              if (currentIndex == 0) return;
              
              Navigator.popUntil(context, (route) => route.isFirst);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StorageScreen()),
              );
            },
            child: _buildBottomNavImage('assets/images/box.png', 70),
          ),

          // 메인 화면 버튼
          GestureDetector(
            onTap: () {
              if (currentIndex == 1) return;
              
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: _buildBottomNavImage('assets/images/main.png', 70),
          ),

          // 프로필 버튼
          GestureDetector(
            onTap: () {
              if (currentIndex == 2) return;
              
              Navigator.popUntil(context, (route) => route.isFirst);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: _buildBottomNavImage('assets/images/profile.png', 70),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavImage(String imagePath, double imageSize) {
    return SizedBox(
      height: 70,
      child: Center(
        child: Image.asset(
          imagePath,
          height: imageSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
        ),
      ),
    );
  }
}
