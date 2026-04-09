import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'config/app_config.dart';
//import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // 우리는 웹(PWA) 기반으로 홈 화면에 추가할 거니까 웹 설정을 기본으로 씁니다!
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: AppConfig.apiKey,
    appId: AppConfig.appId,
    messagingSenderId: AppConfig.messagingSenderId,
    projectId: AppConfig.projectId,
    authDomain: AppConfig.authDomain,
    storageBucket: AppConfig.storageBucket,
  );
}