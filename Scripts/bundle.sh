#!/bin/bash
# cmd-hanyoung.app 번들 생성 스크립트
# 사용자가 수동으로 실행할 것 — CI/자동화에서 직접 호출 금지
set -euo pipefail

# 스크립트 위치 기준 repo 루트로 이동
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "==> Release 빌드 시작..."
swift build -c release

APP="cmd-hanyoung.app"

# 기존 .app 번들 제거
echo "==> 기존 $APP 제거..."
rm -rf "$APP"

# 번들 디렉터리 구조 생성
echo "==> 번들 디렉터리 생성..."
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# 바이너리 복사
echo "==> 바이너리 복사..."
cp ".build/release/cmd-hanyoung" "$APP/Contents/MacOS/cmd-hanyoung"

# Info.plist 복사
echo "==> Info.plist 복사..."
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

# 코드 서명 — self-signed 인증서 우선, 없으면 ad-hoc 폴백
IDENTITY="${CODESIGN_IDENTITY:-cmd-hanyoung-dev}"

echo "==> 코드 서명..."
if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    echo "    '$IDENTITY' 인증서로 서명 (권한 영속)"
    codesign --force --sign "$IDENTITY" --identifier com.cmdhanyoung.app "$APP"
else
    echo "⚠️  경고: '$IDENTITY' self-signed 인증서 없음 → ad-hoc 서명 적용."
    echo "    리빌드마다 '손쉬운 사용' 권한 재허용이 필요합니다."
    echo "    권한 영속을 원하면: ./Scripts/make-signing-cert.sh 를 1회 실행하세요."
    codesign --force --sign - --identifier com.cmdhanyoung.app "$APP"
fi

echo ""
echo "빌드 완료: $(pwd)/$APP"
echo "손쉬운 사용 권한 설정: 시스템 설정 > 개인정보보호 및 보안 > 손쉬운 사용"
