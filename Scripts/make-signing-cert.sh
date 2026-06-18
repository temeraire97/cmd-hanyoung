#!/bin/bash
# make-signing-cert.sh — "cmd-hanyoung-dev" self-signed code-signing 인증서를 로그인 키체인에 1회 생성.
#
# 실행 방법:
#   ./Scripts/make-signing-cert.sh
#
# 이 스크립트는 사용자가 직접 1회만 실행한다. 자동화/CI에서 호출 금지.
#
# [GUI 대안] Keychain Access 앱 → 메뉴 > 키체인 접근 > 인증서 지원 > 인증서 생성
#   - 이름: cmd-hanyoung-dev
#   - 인증서 유형: 자체 서명 루트
#   - 인증서 범주: 코드 서명
#
# 스크립트가 실패할 경우 위 GUI 방법으로 직접 생성하면 더 안정적일 수 있다.
set -euo pipefail

CERT_NAME="cmd-hanyoung-dev"
# p12 내부 암호 (스크립트 내부 전용 — 키체인 임포트 후 불필요)
P12PW="cmd-hanyoung-cert-pw"

# 이미 존재하면 스킵
# 참고: self-signed 미신뢰 인증서는 -v(valid) 목록에 안 나오므로 -v 생략
if security find-identity -p codesigning | grep -q "$CERT_NAME"; then
    echo "인증서 '$CERT_NAME'이 이미 로그인 키체인에 존재합니다. 스킵."
    exit 0
fi

echo "==> '$CERT_NAME' self-signed code-signing 인증서 생성 중..."

# 임시 작업 디렉터리
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

KEY_FILE="$TMPDIR/key.pem"
CERT_FILE="$TMPDIR/cert.pem"
P12_FILE="$TMPDIR/cert.p12"
EXT_FILE="$TMPDIR/ext.cnf"

# OpenSSL 확장 설정 파일
cat > "$EXT_FILE" <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_codesign
prompt = no

[req_distinguished_name]
CN = $CERT_NAME

[v3_codesign]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF

# RSA 키 + self-signed 인증서 생성 (유효기간 3650일 ≈ 10년)
openssl req \
    -newkey rsa:2048 \
    -nodes \
    -keyout "$KEY_FILE" \
    -x509 \
    -days 3650 \
    -out "$CERT_FILE" \
    -config "$EXT_FILE" \
    -extensions v3_codesign \
    2>/dev/null

# .p12 번들로 묶기
# -legacy -keypbe/-certpbe PBE-SHA1-3DES -macalg sha1: macOS security import 호환 알고리즘
# OpenSSL 3.x 기본 알고리즘(AES-256-CBC + SHA-256 MAC)은 macOS security가 읽지 못함
openssl pkcs12 \
    -export \
    -out "$P12_FILE" \
    -inkey "$KEY_FILE" \
    -in "$CERT_FILE" \
    -passout pass:"$P12PW" \
    -legacy -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
    2>/dev/null

# 로그인 키체인에 임포트 — codesign 사용 허가
LOGIN_KEYCHAIN="$(security login-keychain | tr -d '[:space:]"')"

if ! security import "$P12_FILE" \
        -k "$LOGIN_KEYCHAIN" \
        -T /usr/bin/codesign \
        -P "$P12PW" \
        2>/dev/null; then
    echo ""
    echo "[실패] security import 오류 발생."
    echo "GUI 대안: Keychain Access > 인증서 지원 > 인증서 생성"
    echo "  이름: $CERT_NAME  /  인증서 범주: 코드 서명  /  유형: 자체 서명 루트"
    exit 1
fi

# 신뢰(trust) 설정 생략 — 의도적
# set-certificate-trust 는 admin 프롬프트를 유발하며 서명·권한 영속에 불필요.
# self-signed 인증서는 키체인에서 "(CSSMERR_TP_NOT_TRUSTED)"로 표시되나,
# codesign 서명과 TCC Accessibility 권한 영속(csreq 기반)에는 영향 없음.

# 성공 검증 — -v 는 신뢰된 인증서만 표시하므로 생략
if security find-identity -p codesigning | grep -q "$CERT_NAME"; then
    echo ""
    echo "완료: '$CERT_NAME' 인증서가 로그인 키체인에 추가되었습니다."
    echo "이후 ./Scripts/bundle.sh 실행 시 자동으로 이 인증서로 서명됩니다."
    echo ""
    echo "주의: 이 인증서는 로컬 전용입니다. 타 Mac 배포 시 Apple Developer ID 인증서가 필요합니다."
    echo "참고: 키체인에 '신뢰 안 됨'으로 표시될 수 있으나 codesign 서명·권한 영속엔 무관합니다."
else
    echo ""
    echo "[실패] 임포트 후 인증서를 확인할 수 없습니다."
    echo "GUI 대안: Keychain Access > 인증서 지원 > 인증서 생성"
    echo "  이름: $CERT_NAME  /  인증서 범주: 코드 서명  /  유형: 자체 서명 루트"
    exit 1
fi
