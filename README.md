# cmd-hanyoung

## 소개

macOS 상태바 유틸리티. **좌⌘ 단독 입력 → 영문 강제**, **우⌘ 단독 입력 → 한글(2-Set) 강제**.
기본 2-Set IME 환경을 전제로 하며, 별도 토글 없이 왼손/오른손 ⌘ 키로 입력 언어를 확정한다.

> Phase 1 스코프: 앱 번들 구조 + 상태바 아이콘 표시 (walking skeleton).

---

## 빌드

```bash
./Scripts/bundle.sh
```

스크립트 실행 후 repo 루트에 `cmd-hanyoung.app` 번들이 생성된다.

---

## 설치 및 권한

1. `cmd-hanyoung.app`을 `/Applications`(또는 원하는 위치)에 복사.
2. 앱 최초 실행 후 **시스템 설정 > 개인정보보호 및 보안 > 손쉬운 사용**에서 `cmd-hanyoung.app`을 추가하고 허용.
3. 리빌드(`./Scripts/bundle.sh` 재실행) 후 바이너리 서명이 변경되면 접근성 권한 재허용이 필요할 수 있다. 이 경우 위 항목을 목록에서 제거 후 다시 추가한다.

---

## 서명 / 권한 영속

macOS TCC는 **designated requirement(csreq)** 기반으로 Accessibility 권한을 키잉한다. ad-hoc 서명(`--sign -`)은 리빌드마다 cdhash가 변경되어 csreq 불일치 → 권한이 초기화된다. **고정 CN의 self-signed 인증서**로 서명하면 csreq가 안정적으로 유지되어 리빌드 후에도 권한이 영속된다.

### 최초 1회 — 인증서 생성

```bash
./Scripts/make-signing-cert.sh
```

또는 **Keychain Access GUI**: 메뉴 > 인증서 지원 > 인증서 생성
- 이름: `cmd-hanyoung-dev` / 인증서 범주: 코드 서명 / 유형: 자체 서명 루트

인증서는 로그인 키체인에 1회만 생성하면 된다. 이후 `./Scripts/bundle.sh`가 자동으로 이 인증서를 감지하여 서명한다.

### 동작 요약

| 상황 | 서명 방식 | 리빌드 후 권한 |
|------|----------|--------------|
| `cmd-hanyoung-dev` 인증서 존재 | self-signed 인증서 서명 | **영속** |
| 인증서 없음 | ad-hoc 폴백 | 매번 재허용 필요 |

### Gatekeeper 주의

self-signed 인증서는 **로컬 Mac 전용**이다. 타 Mac에 배포할 경우 Apple Developer ID 인증서가 필요하다.

### 단일 인스턴스

앱 실행 시 구버전 프로세스를 자동으로 종료하고 새 인스턴스를 시작한다.

### 권한 초기화 (테스트용)

```bash
tccutil reset Accessibility com.cmdhanyoung.app
```

---

## 주의 사항

### macOS 15 Sequoia — 좌/우 ⌘ modifier-only 단축키 충돌 (R-6)

macOS 15(Sequoia)에서는 시스템이 좌⌘ / 우⌘ 단독 입력을 다른 기능에 이미 할당했거나 충돌을 감지할 수 있다.
이 경우 **시스템 설정 > 키보드 > 키보드 단축키**에서 충돌하는 시스템 단축키를 찾아 비활성화한 후 앱을 재시작한다.

---

## 라이선스

미정 / 개인 사용
