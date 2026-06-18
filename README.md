<div align="center">

# cmd-hanyoung

Tap left ⌘ for English, right ⌘ for Korean — instant input-source switching for macOS

[English](README.md) | [한국어](README.ko.md)

![Release](https://img.shields.io/github/v/release/temeraire97/cmd-hanyoung) ![License](https://img.shields.io/badge/license-MIT-blue) ![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)

</div>

---

## Highlights

- **Left/right ⌘ solo-tap detection** — CGEventTap (listen-only) intercepts bare ⌘ taps without consuming the key event.
- **Command combos 100% preserved** — ⌘C, ⌘V, ⌘Z, ⌘Tab, ⌘Space, cmd+click/drag all work normally.
- **Force input source** — switches directly to ABC or 2-Set Korean via TISSelectInputSource, bypassing the CJKV bounce bug.
- **Menu-bar control** — globe icon in the status bar; per-side source picker, login-item toggle, quit.
- **Sleep/wake recovery** — CGEventTap is automatically restored after system sleep.
- **Single instance** — launching a second copy terminates the previous one automatically.

---

## Install

### Homebrew (recommended)

```bash
brew tap temeraire97/tap
brew trust temeraire97/tap
brew install --cask cmd-hanyoung
```

> `brew trust` is required because Homebrew (2026) blocks casks from third-party taps until trusted.

### Manual

Download the `.zip` from the [Releases](https://github.com/temeraire97/cmd-hanyoung/releases) page, unzip, and move `cmd-hanyoung.app` to `/Applications`.

**First launch — quarantine bypass**

The app is self-signed and not notarized by Apple. macOS will block it on first open. Choose one of:

```bash
xattr -dr com.apple.quarantine /Applications/cmd-hanyoung.app
```

Or on macOS 15 Sequoia: after the blocked-launch alert, go to **System Settings ▸ Privacy & Security** and click **Open Anyway**. (The Finder right-click "Open" bypass was removed on Sequoia.)

---

## Usage

1. **Grant Accessibility permission** — System Settings ▸ Privacy & Security ▸ Accessibility ▸ add `cmd-hanyoung.app` and enable it.
2. Relaunch the app if prompted.
3. **Left ⌘ tap** → switches to ABC (English).  
   **Right ⌘ tap** → switches to 2-Set Korean.
4. **Menu-bar globe icon** — use submenus to change the input source assigned to each side, toggle launch-at-login, or quit.

---

## Requirements

- macOS 14 Sonoma or later
- Both **ABC** and **2-Set Korean** input sources added in System Settings ▸ Keyboard ▸ Input Sources
- Non-sandboxed environment (Accessibility permission required)

---

## Build from source

```bash
./Scripts/bundle.sh
```

This produces `cmd-hanyoung.app` at the repo root. If the `cmd-hanyoung-dev` self-signed certificate exists in your login Keychain, the script signs with it automatically; otherwise it falls back to ad-hoc signing.

---

## Signing & permission persistence

macOS TCC keys the Accessibility permission on the app's **designated requirement (csreq)**, not the binary path. Ad-hoc signing (`codesign --sign -`) generates a new cdhash on every rebuild, causing a csreq mismatch and resetting the permission each time. Signing with a **fixed-CN self-signed certificate** keeps the csreq stable so the permission survives rebuilds.

### One-time setup

```bash
./Scripts/make-signing-cert.sh
```

Or manually in **Keychain Access**: menu ▸ Certificate Assistant ▸ Create a Certificate — name `cmd-hanyoung-dev`, category Code Signing, type Self Signed Root. Create it once in your login Keychain; `./Scripts/bundle.sh` auto-detects it and signs with it on every subsequent build.

| Situation | Signing | Permission after rebuild |
|-----------|---------|--------------------------|
| `cmd-hanyoung-dev` cert present | self-signed cert | **persists** |
| No cert | ad-hoc fallback | must re-grant each time |

**Notes:**
- The cert may appear "not trusted" in Keychain — this does not affect codesign or TCC. Allow keychain access when prompted on the first build.
- Self-signed certs are **local-Mac only**. Distributing to other Macs requires an Apple Developer ID certificate and notarization (planned for a future release; see [Releases](https://github.com/temeraire97/cmd-hanyoung/releases)).

### Reset permission for testing

```bash
tccutil reset Accessibility com.cmdhanyoung.app
```

---

## FAQ

**"App is damaged and can't be opened" / "Apple cannot verify"**

Run the quarantine-clear command above, or use System Settings ▸ Privacy & Security ▸ Open Anyway.

**Accessibility permission resets after every rebuild**

macOS TCC keys Accessibility by designated requirement (csreq). Ad-hoc signing (`--sign -`) changes the cdhash on every build, breaking the csreq match and resetting the permission. Fix: create the `cmd-hanyoung-dev` self-signed certificate once (see [Signing & permission persistence](#signing--permission-persistence) above; 한국어: [README.ko.md](README.ko.md#서명--권한-영속)). With that certificate, csreq stays stable across rebuilds and the permission persists.

**macOS 15 Sequoia — left/right ⌘ shortcut conflict**

Sequoia may assign system-level actions to bare left/right ⌘ taps. If detection is unreliable, go to System Settings ▸ Keyboard ▸ Keyboard Shortcuts, find the conflicting shortcut, and disable it, then relaunch the app.

---

## Contributing

Issues and PRs welcome. Please open an issue before starting substantial changes.

## License

MIT — see [LICENSE](LICENSE).
