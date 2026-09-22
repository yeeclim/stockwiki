/// AdSense 디스플레이 광고 배너.
///
/// `dart:ui_web` / `package:web` 은 웹에서만 존재해서, 페이지가 직접 import 하면
/// Android/iOS 빌드와 `flutter test`(VM) 가 로딩 단계에서 통째로 실패한다.
/// 웹 전용 구현은 ad_banner_web.dart 에만 두고 나머지 플랫폼은 스텁을 쓴다.
library;

export 'ad_banner_stub.dart' if (dart.library.js_interop) 'ad_banner_web.dart';
