import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config/app_config.dart';
import '../models/app_colors.dart';
import '../screens/main_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // uid 활용 로그인
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

  // 유저 정보 넘기는 로직
  Future<bool> _sendUserInfoToBackend(User kakaoUser) async {
    final String backendUrl = '${AppConfig.baseUrl}/api/user/login'; 

    try {
      final String uid = kakaoUser.id.toString(); 
      final String nickname = kakaoUser.kakaoAccount?.profile?.nickname ?? '이름없음';
      
      final String email = kakaoUser.kakaoAccount?.email ?? '정보 없음';
      
      String gender = '정보 없음';
      if (kakaoUser.kakaoAccount?.gender == Gender.male) {
        gender = '남성';
      } else if (kakaoUser.kakaoAccount?.gender == Gender.female) {
        gender = '여성';
      }

      final String birthYear = kakaoUser.kakaoAccount?.birthyear ?? '';
      final String birthDay = kakaoUser.kakaoAccount?.birthday ?? ''; // 예: "0525"
      
      String birth = '정보 없음';
      if (birthYear.isNotEmpty && birthDay.length == 4) {
        birth = '$birthYear.${birthDay.substring(0, 2)}.${birthDay.substring(2, 4)}.';
      }

      final Map<String, dynamic> requestBody = {
        'uid': uid,
        'nickname': nickname,
        'email': email,
        'gender': gender,
        'birth': birth,
      };

      log('[API 통신] 백엔드로 데이터 전송 시작: $requestBody');

      final response = await http.post(
        Uri.parse(backendUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        log('[API 통신] 백엔드 로그인/가입 성공!');
        return true;
      } else {
        log('[API 에러] 백엔드 응답 실패: 상태 코드 ${response.statusCode}');
        log('[API 에러] 에러 상세: ${response.body}');
        return false;
      }
    } catch (e) {
      log('[API 에러] 통신 중 오류 발생: $e');
      return false;
    }
  }
  
  // 카카오 로그인 처리 로직
  Future<void> _loginWithKakao(BuildContext context) async {
    String? origin = await KakaoSdk.origin;
    log('🔑 실제 키해시: $origin');

    try {
      bool isInstalled = await isKakaoTalkInstalled();

      if (isInstalled) {
        try {
          await UserApi.instance.loginWithKakaoTalk();
          log('카카오톡으로 로그인 성공');
        } catch (error) {
          log('카카오톡으로 로그인 실패 $error');
          if (error is PlatformException && error.code == 'CANCELED') {
            return;
          }
          await UserApi.instance.loginWithKakaoAccount();
          log('카카오계정으로 로그인 성공');
        }
      } else {
        await UserApi.instance.loginWithKakaoAccount();
        log('카카오계정으로 로그인 성공');
      }

      User user = await UserApi.instance.me();
      log('사용자 정보 요청 성공 - 회원번호: ${user.id}, 닉네임: ${user.kakaoAccount?.profile?.nickname}');

      AppConfig.currentUserUid = user.id.toString();

      bool isBackendSuccess = await _sendUserInfoToBackend(user);

      if (isBackendSuccess) {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('서버 연동에 실패했습니다. 다시 시도해주세요.')),
          );
        }
      }

    } catch (error) {
      log('카카오 로그인 실패 $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    }
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
                      left: -10,
                      top: -10,
                      child: Container(
                        width: 380,
                        height: 380,
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
              
              // 카카오 로그인
              Material(
                color: const Color(0xFFFFC943),
                borderRadius: BorderRadius.circular(17),
                elevation: 4, 
                shadowColor: const Color(0x3F000000),
                child: InkWell(
                  onTap: () => _loginWithKakao(context),
                  borderRadius: BorderRadius.circular(17),
                  child: Container(
                    width: 352,
                    height: 58,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(width: 10),
                        Text(
                          '카카오 로그인',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 26,
                            fontFamily: 'Paperlogy',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // uid 테스트
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => _showUidDialog(context),
                    child: const Text(
                      'UID 직접 입력 (테스트)',
                      style: TextStyle(
                        color: Colors.black54, 
                        fontSize: 18,
                        fontFamily: 'Paperlogy',
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
