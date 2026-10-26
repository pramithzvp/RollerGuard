# RollerGuard iPhone + Android — Setup Guide

**Build:** Safety-first Flutter simulator, not a real gate controller.  **Target:** iOS 13+ / Android API 24+ with a compatible Flutter toolchain.

## 1) Mac prerequisites

- macOS computer, current **Flutter 3.41+**, **Xcode**, **CocoaPods** and an **Apple ID** for iPhone signing. Check with `flutter doctor -v`.
- If Xcode tools are not yet selected, use: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` then `sudo xcodebuild -runFirstLaunch`. Accept Apple license if prompted.
- For hardware builds, iPhone USB cable (or already configured wireless Xcode pairing).
- Physical iPhone cannot install this ZIP itself. You first build and sign it on a Mac.

Official guide: https://docs.flutter.dev/platform-integration/ios/setup

## 2) One-click iOS project setup

ZIP extract කරලා Mac Terminal එකෙන්:

```bash
cd /path/to/RollerGuard_iOS_Ready
chmod +x setup_ios.command
./setup_ios.command
```

This creates `ios/` and `android/` from the **Flutter SDK installed on your Mac**, adds permissions, downloads dependencies, and runs unit tests. The source project ZIP intentionally omits generated `ios/` and `android/` folders to prevent stale native build templates. Do not interpret successful setup as signed/installed iPhone build.

### iOS `Info.plist` (automatically set)

- `CFBundleDisplayName` = RollerGuard
- `NSFaceIDUsageDescription` = Face ID unlock explanation
- `NSMicrophoneUsageDescription` = push-to-talk permission
- `NSSpeechRecognitionUsageDescription` = voice recognition permission
- iOS deployment target at least 13.0, do **not** request microphone/audio permissions until the user taps voice.
- The app requests no background microphone access.

## 3) Install on your own iPhone (Mac required)

1. Connect iPhone to Mac, tap **Trust this Computer**.
2. On iPhone, enable **Settings > Privacy & Security > Developer Mode** (restart if requested).
3. `open ios/Runner.xcworkspace`
4. In **Xcode > Runner > Signing & Capabilities**, select your **Team** (Apple ID) and enable **Automatically manage signing**. Change Bundle Identifier to a unique value such as `com.yourname.rollerguard` — replace `yourname` with your own, and don't claim a reserved bundle ID.
5. From Terminal, `flutter devices` and `flutter run -d <YOUR_IPHONE_DEVICE_ID>` (replace the placeholder with the actual shown device ID).
6. If asked to trust the installed developer profile, go to iPhone **Settings > General > VPN & Device Management** and trust your own signing certificate.
7. Allow Face ID, Microphone, Speech Recognition only if you want those features. Use an actual iPhone for testing Face ID and voice.

A free personal Apple developer account can be used for device testing; distributing via TestFlight/App Store needs the paid Apple Developer Program and appropriate review/signing.

## 4) Simulator

`open -a Simulator` (or on Xcode 27, `open -a DeviceHub`) then `flutter devices` and `flutter run -d <SIMULATOR_ID>`.

Simulator Face ID and microphone/speech features may not behave like a real phone. Validate on hardware before relying on them.

## 5) Troubleshooting

- `flutter: command not found`: install Flutter SDK and put its bin folder on your Terminal PATH.
- `No valid code signing certificates`: choose Team, Unique Bundle Identifier and automatic signing in Xcode.
- CocoaPods errors: update CocoaPods, try `flutter clean && flutter pub get`, then `cd ios && pod install && cd ..` when Podfile exists.
- iPhone missing: unlock, trust Mac, check cable, use `flutter devices`; enable Developer Mode.
- Privacy crashes: run `python3 scripts/configure_platforms.py`, verify with `python3 scripts/verify_ios.py`, then rebuild.
- Old Flutter SDK: update to Flutter 3.41+; packages `local_auth 3.0.2` and `speech_to_text 7.4.0` are pinned for this sample.

## 6) What is actually implemented

- Flutter UI, simulated open/close/stop; close confirmation; online/offline and position states
- Device-local Face ID/biometric/passcode app unlock, demo bypass, activity, demo user roles / remote lock
- Push-to-talk English voice commands via iOS speech service
- Permission configuration script and native platform scaffold generation

**Not implemented:** physical motor control, real gateway, cloud identity and persistent roles/audit log, controller-side relay wiring, Siri Shortcuts, release-signing/IPA/TestFlight. App display only represents a simulator and cannot replace gate safety equipment.

**Electrical installation:** do not connect the simulator directly to a roller-door motor. A qualified technician must review the specific existing controller, independent hardware safety sensors, anti-entrapment and manual release before any real remote control integration.

## 7) Future release

After testing and adding secure production backend/hardware integration, follow https://docs.flutter.dev/deployment/ios for signing, TestFlight, App Store requirements. An `.ipa` cannot be generated/signed in this environment.
