#!/bin/bash
# CLT-only Swift Testing 실행 래퍼
#
# CommandLineTools 환경에서는 Testing.framework가 Xcode.app 번들이 아닌
# CLT 경로($DEV/Library/Developer/Frameworks)에 위치한다.
# SwiftPM의 타깃 단위 unsafeFlags(-F)는 생성된 runner.swift 컴파일에
# 전파되지 않으므로, swift test 전체 호출에 -Xswiftc -F 를 넘겨야
# canImport(Testing) == true 가 되어 실제 테스트가 실행된다.
#
# 풀 Xcode 환경(xcode-select -p 가 Xcode.app 내부를 가리키는 경우)에서는
# `swift test` 직접 실행도 가능하다.

set -euo pipefail

DEV=$(xcode-select -p)
FWK="$DEV/Library/Developer/Frameworks"

if [ ! -d "$FWK/Testing.framework" ]; then
    echo "ERROR: Testing.framework not found at $FWK" >&2
    echo "  xcode-select -p = $DEV" >&2
    exit 1
fi

exec swift test \
    -Xswiftc -F"$FWK" \
    -Xlinker -rpath \
    -Xlinker "$FWK" \
    "$@"
