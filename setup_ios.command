#!/bin/bash
# Double-click from macOS Finder (or run ./setup_ios.command).
set -euo pipefail
cd "$(dirname "$0")"
printf '\n====== RollerGuard iOS setup (DEMO ONLY) ======\n'
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS build tools require a Mac. Use this script on macOS with Xcode."
  exit 1
fi
if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter was not found in PATH. Install Flutter 3.41+ and restart Terminal."
  echo "Guide: https://docs.flutter.dev/get-started/install/macos/mobile-ios"
  exit 1
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Xcode developer tools not found. Install Xcode from Apple, open it once, then run xcodebuild -runFirstLaunch."
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo 'python3 is required to configure Info.plist.'
  exit 1
fi
if ! command -v pod >/dev/null 2>&1; then
  echo 'NOTE: CocoaPods not found. You may need to install it to compile iOS Flutter plugins.'
  echo 'See https://docs.flutter.dev/platform-integration/ios/setup'
fi
flutter --version
printf '\n1/5 Create native iOS + Android scaffolding (without replacing lib/)\n'
flutter create --platforms=ios,android --project-name roller_guard --org com.rollerguard .
printf '\n2/5 Configure iOS privacy descriptions + Android permissions\n'
python3 scripts/configure_platforms.py
printf '\n3/5 Get Flutter dependencies\n'
flutter pub get
printf '\n4/5 Run safety-policy tests\n'
flutter test
printf '\n5/5 Static iOS configuration checks\n'
python3 scripts/verify_ios.py
printf '\nSource setup complete. Physical-device iOS build / signing not yet validated.\n'
printf 'NEXT: open ios/Runner.xcworkspace; choose Signing & Capabilities > Team and unique Bundle Identifier.\n'
printf 'Connect iPhone, enable Developer Mode, trust this Mac, run: flutter devices; flutter run -d YOUR_DEVICE_ID\n'
printf 'SIMULATOR: open -a Simulator (or open -a DeviceHub for Xcode 27); flutter run -d YOUR_SIMULATOR_ID\n'
printf 'NOTE: This is a no-hardware demo. Open/close/stop do NOT contact a motor.\n'
