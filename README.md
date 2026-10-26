# RollerGuard — iOS-ready Flutter Source Project (DEMO)

**Run on iPhone / iOS simulator / Android with Flutter 3.41+.** This is a safety-first **offline simulator**. It does **not** control a real roller door.

## Quick start on Mac

```bash
unzip RollerGuard_iOS_Ready.zip
cd RollerGuard_iOS_Ready
chmod +x setup_ios.command
./setup_ios.command
open ios/Runner.xcworkspace
```

In Xcode choose your Apple developer team / unique bundle ID and enable automatic signing. Connect your iPhone, enable Developer Mode, then `flutter devices` and `flutter run -d <ID>`.

**Read [IOS_SETUP_SINHALA_ENGLISH.md](IOS_SETUP_SINHALA_ENGLISH.md) before installing.**

### Included features
- Face ID / phone authentication app unlock (plus conspicuous DEMO bypass)
- OPEN / CLOSE / STOP simulator + CLOSE confirmation
- push-to-talk voice commands using microphone/speech recognition
- iOS permission setup (Face ID / Microphone / Speech Recognition)
- remote app lock, role simulation, simulated faults, denied-action logs
- Android support from same Flutter codebase
- safety-policy unit tests

### Build boundaries
No Xcode/Flutter tools are available in the pack-generation environment, so the physical iPhone build is **not verified**. The generated Xcode project is created by Flutter on **your Mac** when running `setup_ios.command`. No IPA is included. **Do not connect to gate hardware as-is.**
