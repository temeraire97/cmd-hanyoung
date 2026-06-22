# Phase 1 릴리즈 체크리스트 (외부/수동 작업)

> **참고:** 공식 `homebrew/cask` 등록은 Apple Developer 계정($99/yr) + 공증(notarization) 필요 (Phase 3 범위). 이 문서는 own tap 배포(Phase 1)만 다룬다.

---

- [ ] **1. .app 빌드**

  ```bash
  ./Scripts/bundle.sh
  ```

  ad-hoc 서명 또는 self-signed 인증서로 서명. 결과물: `dist/cmd-hanyoung.app` (또는 `.app` 번들).

- [ ] **2. 배포 zip 생성 + sha256 확인**

  ```bash
  ./Scripts/release.sh
  ```

  출력: `dist/cmd-hanyoung-0.1.2.zip` + sha256 해시. 이 해시를 `Casks/cmd-hanyoung.rb`의 `sha256` 필드에 입력.

- [ ] **3. GitHub Release 생성**

  ```bash
  gh release create v0.1.2 dist/cmd-hanyoung-0.1.2.zip \
    --title "cmd-hanyoung 0.1.2" \
    --generate-notes
  ```

  태그: `v0.1.2`, 에셋: `dist/cmd-hanyoung-0.1.2.zip` 첨부.

- [ ] **4. tap repo 생성 및 Cask 파일 배포**

  ```bash
  gh repo create temeraire97/homebrew-tap --public
  ```

  그 후 이 repo의 `Casks/cmd-hanyoung.rb`에 `dist/cmd-hanyoung.rb` 템플릿을 복사하고, 2단계에서 얻은 실제 sha256 값으로 `REPLACE_WITH_SHA256` 교체.  

- [ ] **5. 설치 검증**

  ```bash
  brew tap temeraire97/tap
  brew trust temeraire97/tap
  brew install --cask cmd-hanyoung
  ```

  정상 설치 및 Accessibility 권한 부여 후 동작 확인.

- [ ] **6. repo 토픽 설정**

  ```bash
  gh repo edit temeraire97/cmd-hanyoung \
    --add-topic macos,keyboard,input-method,korean,hangul,karabiner-alternative,menu-bar,swift
  ```

  > 앱 이름/연도/주언어(예: `swift`, `macos`) 토픽은 GitHub 자동필터에 걸려 검색 노출 제외됨 — 추가 금지.

- [ ] **7. 데모 GIF 녹화**

  Kap으로 녹화 → Gifski로 변환. 저장 위치: `assets/demo.gif`.
  - 길이: 5–15초
  - 폭: ~1000px
  - 파일 크기: 50MB 미만
  - 키스트로크 오버레이 권장

- [ ] **8. Social preview 이미지 설정** (선택, 권장)

  1280×640px 이미지 제작 후 GitHub: Settings ▸ General ▸ Social preview 업로드.
