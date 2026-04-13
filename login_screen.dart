import 'package:flutter/material.dart';
import 'main.dart';

String uid = '';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _showUidDialog(BuildContext context) {
    TextEditingController uidController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFFBF1), 
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
                uid = uidController.text.trim(); 
                
                Navigator.pop(dialogContext);                
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MainScreen()),
                );
              },
              child: const Text('확인', style: TextStyle(color: Color(0xFFEF9666), fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFEEC6),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              
              SizedBox(
                width: 360,
                height: 350,
                child: Stack(
                  children: [
                    Positioned(
                      left: 25,
                      top: 0, 
                      child: SizedBox(
                        width: 320,
                        height: 320,
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/circle2.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      top: 71.7, 
                      child: Transform(
                        transform: Matrix4.rotationZ(-0.26),
                        child: const Text(
                          '갈래',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF331F07),
                            fontSize: 106,
                            fontFamily: 'RiaSans',
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                    const Positioned(
                      right: 10,
                      top: 146, 
                      child: Text(
                        '말래',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF331F07),
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
                color: const Color(0xFFFFAC4B),
                borderRadius: BorderRadius.circular(17),
                elevation: 4, 
                shadowColor: const Color(0x3F000000),
                child: InkWell(
                  onTap: () {
                    _showUidDialog(context);
                  },
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
                    onTap: () {
                    },
                    child: const Text(
                      '아이디 찾기',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontFamily: 'Paperlogy',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '|',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontFamily: 'Paperlogy',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // 비밀번호 찾기 동작
                    },
                    child: const Text(
                      '비밀번호 찾기',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontFamily: 'Paperlogy',
                        fontWeight: FontWeight.w400,
                      ),
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