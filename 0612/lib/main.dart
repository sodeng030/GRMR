import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';
import '../config/app_config.dart';

void main() async { 
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final savedUid = prefs.getString('uid') ?? '';
  AppConfig.currentUserUid = savedUid;

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
      
      // home: AppConfig.currentUserUid.isEmpty
      //   ? const LoginScreen()
      //   : const MainScreen(),

      home: const LoginScreen(),
    );
  }
}
