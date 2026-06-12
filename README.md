# GRMR
2026-1 파란학기 갈래말래팀 프로젝트


firebase console 앱 배포
배포 전에 pubspec.yaml 에서 버전 올리기

# Android
flutter build apk --release

firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk --app 1:584756386654:android:3e65fa886251b4dc554dcf --testers "이메일" --release-notes "업데이트 내용"

# iOS (iPhone 연결 상태에서)
flutter build ios --release

mkdir -p build/ios/iphoneos/Payload && cp -r build/ios/iphoneos/Runner.app build/ios/iphoneos/Payload/

cd build/ios/iphoneos && zip -r Runner.ipa Payload/

firebase appdistribution:distribute Runner.ipa --app 1:584756386654:ios:58655aed3cdcf24b554dcf --testers "이메일" --release-notes "업데이트 내용"

flutter run --release
