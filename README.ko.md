<div align="center">

# cmd-hanyoung

좌⌘ 탭 → 영문, 우⌘ 탭 → 한글 — macOS 즉시 입력소스 전환

[English](README.md) | [한국어](README.ko.md)

![Release](https://img.shields.io/github/v/release/temeraire97/cmd-hanyoung) ![License](https://img.shields.io/badge/license-MIT-blue) ![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)

</div>

---

## 소개

macOS 상태바 유틸리티. **좌⌘ 단독 탭 → 영문(ABC) 강제**, **우⌘ 단독 탭 → 한글(2-Set) 강제**. 기본 2-Set IME 환경을 전제로 하며, 별도 토글 없이 왼손/오른손 ⌘ 키로 입력 언어를 확정한다.

---

## 기능

- **좌/우 ⌘ 단독 탭 감지** — CGEventTap(listen-only 모드)로 ⌘ 키 입력 감지. **Command 키 기존 동작 100% 보존** (⌘C/V/Z/Tab/Space, cmd+클릭/cmd+드래그 등 Command 조합이 비소비되므로 정상 동작).
- **입력소스 강제** — TISSelectInputSource로 직접 선택. 영문은 ABC 레이아웃 강제, 한글은 CJKV bounce 우회(아이콘만 바뀌는 버그 회피).
- **메뉴바 컨트롤** — 상태바 globe 아이콘 > 좌⌘/우⌘ 대상 입력소스 지정 서브메뉴, 로그인 시 자동 실행 토글, 접근성 권한 경고(권한 부족 시), 종료.
- **입력소스 피커** — 선택 가능한 키보드 소스만 표시 (이모지·팔레트·필기 및 IME 상위 컨테이너 `com.apple.inputmethod.Korean` 자동 제외). 기본값: 좌=ABC, 우=2-Set Korean. UserDefaults에 영속.
- **시스템 회복력** — 슬립/웨이크 후 CGEventTap 자동 복구. 시스템 부하로 탭 비활성화 시 자동 재활성화.
- **단일 인스턴스** — 앱 실행 시 기존 인스턴스 자동 종료.

---

## 설치

### Homebrew (권장)

```bash
brew tap temeraire97/tap
brew trust temeraire97/tap
brew install --cask cmd-hanyoung
```

> `brew trust`는 2026 Homebrew가 서드파티 tap의 cask를 신뢰 전까지 차단하므로 필요.

### 수동 설치

[Releases](https://github.com/temeraire97/cmd-hanyoung/releases) 페이지에서 `.zip`을 받아 압축 해제 후 `cmd-hanyoung.app`을 `/Applications`로 이동.

**최초 실행 — 격리 해제**

앱은 self-signed 서명이며 Apple 공증(notarization) 없이 배포된다. macOS가 최초 실행을 차단하면 아래 중 하나를 선택:

```bash
xattr -dr com.apple.quarantine /Applications/cmd-hanyoung.app
```

또는 macOS 15 Sequoia에서는: 차단 알림 후 **시스템 설정 ▸ 개인정보보호 및 보안 ▸ 그래도 열기**. (Finder 우클릭 "열기" 우회는 Sequoia에서 제거됨)

---

## 사용법

1. **접근성 권한 부여** — 시스템 설정 ▸ 개인정보보호 및 보안 ▸ 손쉬운 사용에서 `cmd-hanyoung.app` 추가 후 허용.
2. 권한 요청 시 앱 재시작.
3. **좌⌘ 탭** → ABC(영문) 전환.  
   **우⌘ 탭** → 2-Set Korean(한글) 전환.
4. **메뉴바 globe 아이콘** — 서브메뉴에서 각 방향 키에 할당할 입력소스 변경, 로그인 시 자동 실행 토글, 종료.

---

## 요구사항

- **macOS 14(Sonoma) 이상**
- **시스템 입력 소스에 ABC + 2-Set Korean 등록** — 시스템 설정 > 키보드 > 입력 소스에서 추가되어 있어야 함.
- **비-샌드박스** 환경 (접근성 권한 필요).

---

## 빌드

```bash
./Scripts/bundle.sh
```

스크립트 실행 후 repo 루트에 `cmd-hanyoung.app` 번들이 생성된다. 로그인 키체인에 `cmd-hanyoung-dev` self-signed 인증서가 있으면 자동 적용, 없으면 ad-hoc 폴백.

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

> **참고:** self-signed 인증서는 키체인에 '신뢰 안 됨'으로 표시될 수 있으나, codesign 서명과 Accessibility 권한 영속(csreq 기반)에는 영향 없다. 최초 1회 codesign 실행 시 키체인 키 접근 허용 여부를 물으면 **"항상 허용"** 을 선택한다.

> **OpenSSL 3 주의:** `make-signing-cert.sh`에서 p12 내보내기 시 OpenSSL 3는 기본적으로 PKCS#8 암호화를 사용한다. macOS Keychain 호환을 위해 `-legacy` 플래그가 필요할 수 있다.

### 동작 요약

| 상황 | 서명 방식 | 리빌드 후 권한 |
|------|----------|--------------|
| `cmd-hanyoung-dev` 인증서 존재 | self-signed 인증서 서명 | **영속** |
| 인증서 없음 | ad-hoc 폴백 | 매번 재허용 필요 |

### Gatekeeper 주의

self-signed 인증서는 **로컬 Mac 전용**이다. 타 Mac에 배포할 경우 Apple Developer ID 인증서 및 공증이 필요하다.

### 권한 초기화 (테스트용)

```bash
tccutil reset Accessibility com.cmdhanyoung.app
```

---

## 테스트

```bash
./Scripts/test.sh
```

CLT(Command Line Tools)-only 환경에서도 Swift Testing 프레임워크가 자동으로 감지되어 순수 로직(SoloTapDetectorCore) 검증이 가능하다.

---

## FAQ

**"앱이 손상되어 열 수 없음" / "Apple이 확인할 수 없음"**

위 격리 해제 명령 실행, 또는 시스템 설정 ▸ 개인정보보호 및 보안 ▸ 그래도 열기.

**접근성 권한이 리빌드 후 초기화됨**

위 **서명 / 권한 영속** 섹션 참고. `cmd-hanyoung-dev` self-signed 인증서를 생성하면 해결된다.

**macOS 15 Sequoia — 좌/우 ⌘ 단축키 충돌**

macOS 15에서는 시스템이 좌⌘/우⌘ 단독 입력을 다른 기능에 할당하거나 충돌을 감지할 수 있다. 시스템 설정 > 키보드 > 키보드 단축키에서 충돌하는 항목을 비활성화한 후 앱을 재시작한다.

---

## 기여

이슈 및 PR 환영. 큰 변경 전에는 먼저 이슈를 열어 논의 부탁.

## 라이선스

MIT — [LICENSE](LICENSE) 참고.
