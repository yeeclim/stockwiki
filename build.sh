#!/bin/bash
# Flutter 웹 빌드 스크립트

echo "🔧 Flutter 의존성 설치 중..."
flutter pub get

echo "🏗️ Flutter 웹 빌드 중..."
flutter build web --release

echo "✅ 빌드 완료!"

