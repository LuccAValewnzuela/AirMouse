# Mac Checklist — Build & Run MobileMouse

Goal: minimal time on the Mac. All code, the project spec, and the Info.plist keys live in this repo; the Mac only builds, signs, and deploys.

## One-time setup (~10 min)

1. Install Xcode from the App Store. Open it once, accept the license, let it install components
2. Install Homebrew if missing (brew.sh), then: `brew install xcodegen`
3. Get this repo onto the Mac (clone or copy)

## Generate & open (~2 min)

4. Terminal, repo root: `xcodegen` — creates `MobileMouse.xcodeproj` and writes `xcode/app-info.plist` / `xcode/tests-info.plist`
5. `open MobileMouse.xcodeproj`

## Signing (~2 min)

6. Xcode → Settings → Accounts → add your Apple ID (free personal team is enough)
7. Project → target `MobileMouse` → Signing & Capabilities → check "Automatically manage signing" → Team: your Personal Team (also set it on the `MobileMouseTests` target)
8. Plug in the iPhone, tap Trust on the phone
9. iOS 16+: Settings → Privacy & Security → Developer Mode → on → reboot (the toggle appears once the phone has been paired with Xcode)

## Before first run

10. Check `mobile_app/networking/web_socket_client.swift` line 8 — `serverURL` must be `ws://<your-pc-ip>:8765`, and the PC must be running `python -m server.app` with the firewall open on 8765

## Build, test, run (~5 min)

11. `Cmd+B` — should build clean
12. `Cmd+U` — the 9 MessageBuilder tests (simulator is fine)
13. Destination: your iPhone → `Cmd+R` → first "Start tracking" triggers the camera permission prompt

## On-device verification (Phase 6)

- [ ] Connect → green dot (first connect triggers the iOS local-network permission prompt)
- [ ] Start tracking → slide phone on desk: cursor moves (sideways = x, forward = z)
- [ ] Hold phone still → server log goes quiet (deadband working)
- [ ] Left button: press & hold → drag on PC; release → `button_up` in server log
- [ ] Kill the server → status drops; restart it → auto-reconnect, cursor catches up on accumulated movement
- [ ] Cover the camera → tracking-lost banner; uncover → banner clears

## Notes

- After changing `project.yml` or adding/removing source files: re-run `xcodegen`. Never edit `MobileMouse.xcodeproj` by hand — it's generated
- Error code `-1022` = ATS blocking cleartext `ws://` — check `NSAppTransportSecurity` in the generated `xcode/app-info.plist`, then re-run `xcodegen`
- ARKit world tracking does **not** work in the Simulator — device only (the WebSocket/UI parts do work in the simulator)
- Free provisioning: apps expire after 7 days, just rebuild and re-run
- Tests use `@testable import MobileMouse` — the module name comes from the target name in `project.yml`
