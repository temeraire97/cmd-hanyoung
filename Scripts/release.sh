#!/bin/bash
# cmd-hanyoung 배포용 zip 패키징 스크립트
# 사용자가 수동으로 실행할 것 — CI/자동화에서 직접 호출 금지
# 사전 조건: ./Scripts/bundle.sh 를 먼저 실행하여 cmd-hanyoung.app 을 생성해 두어야 합니다.
set -euo pipefail

# 스크립트 위치 기준 repo 루트로 이동
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

APP="cmd-hanyoung.app"

# .app 번들 존재 여부 확인
if [ ! -d "$APP" ]; then
    echo "오류: $APP 이 없습니다. 먼저 ./Scripts/bundle.sh 를 실행하세요." >&2
    exit 1
fi

# Info.plist 에서 버전 읽기
echo "==> 버전 확인..."
VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)"
echo "    버전: $VERSION"

# dist/ 디렉터리 생성
mkdir -p dist

ZIP="dist/cmd-hanyoung-${VERSION}.zip"

# ditto 로 번들 구조 보존 zip 생성
echo "==> zip 패키징: $ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

# sha256 계산 및 출력
echo "==> sha256 계산..."
SHA256_LINE="$(shasum -a 256 "$ZIP")"
SHA256="$(echo "$SHA256_LINE" | awk '{print $1}')"

# sha256 사이드카 파일 생성 (supply-chain 검증용)
SHA256_FILE="${ZIP}.sha256"
echo "$SHA256_LINE" > "$SHA256_FILE"
echo "==> sha256 파일 저장: $SHA256_FILE"

echo ""
echo "============================================================"
echo "배포 준비 완료"
echo "------------------------------------------------------------"
echo "zip 경로    : $(pwd)/$ZIP"
echo "sha256 파일 : $(pwd)/$SHA256_FILE"
echo "sha256      : $SHA256"
echo "------------------------------------------------------------"
echo "다음 단계:"
echo "  1. GitHub 릴리스 태그 v${VERSION} 에 아래 두 파일을 모두 첨부하세요:"
echo "       $(pwd)/$ZIP"
echo "       $(pwd)/$SHA256_FILE"
echo "  2. homebrew-tap Cask 파일에서 아래 두 필드를 갱신하세요:"
echo "       version  \"${VERSION}\""
echo "       sha256   \"${SHA256}\""
echo "============================================================"
