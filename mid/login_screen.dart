import 'package:flutter/material.dart';
import 'dart:developer';

import '../config/app_config.dart';
import '../models/app_colors.dart';
import '../screens/main_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _showUidDialog(BuildContext context) {
    TextEditingController uidController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            'UID 입력',
            style: TextStyle(fontFamily: 'Paperlogy', fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: uidController,
            decoration: InputDecoration(
              hintText: '본인의 UID를 입력하세요',
              hintStyle: TextStyle(color: Colors.black.withAlpha(100)),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFEF9666)),
              ),
            ),
            cursorColor: const Color(0xFFEF9666),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), 
              child: const Text('취소', style: TextStyle(color: Colors.black)),
            ),
            TextButton(
              onPressed: () {
                String inputUid = uidController.text.trim();
                if (inputUid.isNotEmpty) {
                  AppConfig.currentUserUid = inputUid;
                  
                  Navigator.pop(dialogContext);                
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MainScreen()),
                  );
                } else {
                  log('UID를 입력해주세요.');
                }
              },
              child: const Text(
                '확인', 
                style: TextStyle(color: Color(0xFFEF9666), fontWeight: FontWeight.w700)
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              
              SizedBox(
                width: 380,
                height: 370,
                child: Stack(
                  children: [
                    Positioned(
                      left: -10,        // 왼쪽으로 더 확장
                      top: -10,         // 위로 더 확장
                      child: Container(
                        width: 380,     // 더 크게
                        height: 380,    // 더 크게
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.5,
                            colors: [
                              const Color(0xFFFFCC55),
                              const Color(0xFFFFCC55).withValues(alpha: 0.7),
                              const Color(0xFFFFCC55).withValues(alpha: 0.3),
                              const Color(0xFFFFCC55).withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.35, 0.65, 1.0],
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      left: 20,
                      top: 95.7, 
                      child: Transform(
                        transform: Matrix4.rotationZ(-0.26),
                        child: const Text(
                          '갈래',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textMain,
                            fontSize: 106,
                            fontFamily: 'RiaSans',
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      right: 20,
                      top: 178, 
                      child: Text(
                        '말래',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMain,
                          fontSize: 106,
                          fontFamily: 'RiaSans',
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(flex: 3),
              
              Material(
                color: AppColors.accentMeal,
                borderRadius: BorderRadius.circular(17),
                elevation: 4, 
                shadowColor: const Color(0x3F000000),
                child: InkWell(
                  onTap: () => _showUidDialog(context),
                  borderRadius: BorderRadius.circular(17),
                  child: Container(
                    width: 352,
                    height: 58,
                    alignment: Alignment.center,
                    child: const Text(
                      '로그인',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 36,
                        fontFamily: 'Paperlogy',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 15),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      '아이디 찾기',
                      style: TextStyle(color: Colors.black, fontSize: 24),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('|', style: TextStyle(color: Colors.black, fontSize: 24)),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      '비밀번호 찾기',
                      style: TextStyle(color: Colors.black, fontSize: 24),
                    ),
                  ),
                ],
              ),
              
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}