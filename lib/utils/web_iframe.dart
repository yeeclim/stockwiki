/// srcdoc iframe 를 Flutter 뷰로 띄우는 헬퍼.
///
/// `dart:html` / `dart:ui_web` 은 웹에서만 존재해서, 페이지 파일이 직접 import 하면
/// Android/iOS 빌드와 `flutter test`(VM) 가 로딩 단계에서 통째로 실패했다.
/// 웹 전용 코드는 web_iframe_web.dart 에만 두고 나머지 플랫폼은 스텁을 쓴다.
library;

export 'web_iframe_stub.dart'
    if (dart.library.js_interop) 'web_iframe_web.dart';
