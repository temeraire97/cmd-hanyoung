#!/bin/bash
# make-icon.sh
# macOS 앱 아이콘 전체 파이프라인:
#   1. swift 스크립트로 마스터 PNG 생성
#   2. sips로 전 사이즈 iconset 생성
#   3. iconutil로 .icns 컴파일
#
# 사용: ./Scripts/make-icon.sh (repo 루트에서 실행해도 동일)
set -euo pipefail

# 스크립트 위치 기준 repo 루트로 이동
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

MASTER="Resources/icon-master.png"
ICONSET="AppIcon.iconset"
OUTPUT="Resources/AppIcon.icns"

# ── 1. 마스터 PNG 생성
echo "==> 마스터 PNG 생성 중..."
swift Scripts/make-icon.swift
echo "    완료: $MASTER"

# ── 2. iconset 디렉터리 초기화
echo "==> iconset 생성 중..."
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

# iconutil이 요구하는 정확한 파일명 목록
# 파일명 형식: icon_<논리크기>[@2x].png
# 논리크기 → 실제 픽셀: 1x=논리, 2x=논리×2
sips -z 16   16   "$MASTER" --out "$ICONSET/icon_16x16.png"         >/dev/null
sips -z 32   32   "$MASTER" --out "$ICONSET/icon_16x16@2x.png"      >/dev/null
sips -z 32   32   "$MASTER" --out "$ICONSET/icon_32x32.png"         >/dev/null
sips -z 64   64   "$MASTER" --out "$ICONSET/icon_32x32@2x.png"      >/dev/null
sips -z 128  128  "$MASTER" --out "$ICONSET/icon_128x128.png"       >/dev/null
sips -z 256  256  "$MASTER" --out "$ICONSET/icon_128x128@2x.png"    >/dev/null
sips -z 256  256  "$MASTER" --out "$ICONSET/icon_256x256.png"       >/dev/null
sips -z 512  512  "$MASTER" --out "$ICONSET/icon_256x256@2x.png"    >/dev/null
sips -z 512  512  "$MASTER" --out "$ICONSET/icon_512x512.png"       >/dev/null
sips -z 1024 1024 "$MASTER" --out "$ICONSET/icon_512x512@2x.png"    >/dev/null

echo "    iconset 파일 목록:"
ls "$ICONSET/"

# ── 3. iconutil로 .icns 컴파일
echo "==> iconutil 컴파일 중..."
iconutil -c icns "$ICONSET" -o "$OUTPUT"
echo "    완료: $OUTPUT"

# ── 4. 임시 iconset 제거
echo "==> 임시 iconset 정리..."
rm -rf "$ICONSET"

echo ""
echo "아이콘 파이프라인 완료!"
echo "  마스터:  $MASTER"
echo "  결과물:  $OUTPUT"
ls -lh "$OUTPUT"
