#!/bin/bash
set -e

# Flutter SDK 다운로드 및 설치
curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.38.1-stable.tar.xz | tar -xJ

# PATH 설정
export PATH="$PWD/flutter/bin:$PATH"

# Git 설정
git config --global --add safe.directory "$PWD/flutter"

# Flutter 설정
flutter config --no-analytics

# 의존성 설치 및 빌드
flutter pub get
flutter build web --release

