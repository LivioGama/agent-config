---
root: false
targets: ["*"]
description: "Platform: macOS app builds — stable signing so TCC/permissions persist"
globs: ["**/*"]
---

# Platform Conventions

## macOS app builds — sign ONCE, never re-prompt for password/permissions (HARD RULE)

When building/compiling a macOS app, the user must NOT be re-asked for their password or to re-grant macOS (TCC) permissions (Screen Recording, Accessibility, Camera, Files, etc.) on every rebuild. macOS keys those grants to the app's **bundle id + code-signing designated requirement** — if either changes between builds, every grant resets and the user is prompted again. So:

- **Use a STABLE signing identity and a STABLE bundle id across all builds.** Never let them vary build-to-build (no random/timestamped bundle ids, no switching between ad-hoc and a cert).
- **Pick one signing mode and keep it:**
  - Dev/local: stable **ad-hoc** signature — `codesign --force --deep --options runtime --sign - <App>.app` (the `-` identity is stable as long as you always use it). OR
  - A persistent self-signed / Developer ID cert in the login keychain, referenced by the SAME `CODE_SIGN_IDENTITY` every time.
- **Keep the same `Info.plist` bundle id** (`CFBundleIdentifier`) and the same team/identity — this is what TCC remembers.
- **Don't strip/replace entitlements between builds** in a way that changes the designated requirement.
- For keychain access prompts: sign stably so the keychain ACL trusts the same binary identity instead of treating each rebuild as a new app.
- After the FIRST build, the user grants permissions once; every subsequent rebuild must reuse identity+bundle-id so macOS recognizes it as the same app and stays silent.

**Make this hard to break:** bake the stable identity + bundle id into the build script/Xcode config (not passed ad-hoc on the command line), and verify with `codesign -dv --verbose=4 <App>.app` that the identity and bundle id are unchanged before declaring a build done.
