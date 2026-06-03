import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:goornot/config/app_config.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer';

import 'login_screen.dart';
import 'firebase_options.dart';

Future<void> setupFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // 알림 권한 요청 (아이폰 및 최신 안드로이드 필수)
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 알림 권한 요청, APNS 대기
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? apnsToken = await messaging.getAPNSToken();

      int retryCount = 0;
      while (apnsToken == null && retryCount < 10) {
        await Future.delayed(const Duration(seconds: 1));
        apnsToken = await messaging.getAPNSToken();
        retryCount++;
      }

      String? token = await messaging.getToken();
      log('🔥 내 기기의 FCM 토큰: $token');

      if (token != null) {
        await _sendTokenToServer (token);
      }
    }
  }
}

Future<void> _sendTokenToServer(String token) async {
  final String uid = AppConfig.currentUserUid;
  if (uid.isEmpty) {
    return;
  }

  final String url = '${AppConfig.baseUrl}/api/user/fcm-token';

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'uid': uid,
        'fcm_token': token,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      log('✅ 백엔드 서버로 FCM 토큰 전송 성공!');
    } else {
      log('❌ 서버 응답 에러: ${response.statusCode} (본문: ${response.body})');
    }
  } catch (e) {
    log('❌ 네트워크 에러: FCM 토큰을 서버로 보내지 못했습니다. $e');
  }
}

void main() async { 
  WidgetsFlutterBinding.ensureInitialized();

  // 파이어베이스 초기화 
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,);

  // 알림 권한 및 토큰 발급 함수 실행
  await setupFCM();

  KakaoSdk.init(
    nativeAppKey: 'b43a52345e4765f218532d7f5b06ecd1',
  );

  await FlutterNaverMap().init(
    clientId: '7wk3yroi5c', 
    onAuthFailed: (ex) {
      debugPrint("네이버 지도 인증 실패: $ex");
    },
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      
      theme: ThemeData(
        fontFamily: 'Paperlogy',
        scaffoldBackgroundColor: Colors.white,
      ),
      
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
      ],
      
      home: const LoginScreen(), 
    );
  }
}
