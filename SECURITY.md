# Security Policy

## Supported Versions

| Version | Supported          |
|---------|:------------------:|
| 0.1.x   | ✅ Latest release  |
| < 0.1   | ❌                 |

Only the latest release (0.1.x) receives security updates. Users are encouraged to update regularly.

---

## Reporting a Vulnerability

**Please report security vulnerabilities privately** using GitHub's security advisory feature:

1. Go to the [cmd-hanyoung GitHub repository](https://github.com/temeraire97/cmd-hanyoung)
2. Navigate to **Security** tab ▸ **"Report a vulnerability"**
3. Provide details of the vulnerability

**Do not open public issues for security concerns.**

**Response time:** As this is a solo-maintained project, you can expect an initial response within a few days.

---

## Scope

This app requires **Accessibility permission** to intercept command-key events via CGEventTap (listen-only mode).

**Security notes:**
- The app does **not** capture or transmit keystrokes anywhere. It only detects solo left/right ⌘ taps and switches input sources locally.
- The app runs as a menu-bar utility without sandbox restrictions, requiring explicit Accessibility grant.
- Reports about local privilege escalation, permission persistence, or input-handling correctness are welcome and will be reviewed promptly.

---

## License

This project is released under the [MIT License](LICENSE). Security considerations related to the self-signed code signature and Accessibility permission are documented in the [README](README.md#signing--permission-persistence).
