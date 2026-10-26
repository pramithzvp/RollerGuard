#!/usr/bin/env python3
"""Static check of generated iOS configuration (not an iOS build check)."""
import plistlib
from pathlib import Path
import sys
root = Path(__file__).resolve().parents[1]
plist_path = root / 'ios/Runner/Info.plist'
if not plist_path.exists():
    sys.exit('FAIL: iOS Runner is missing. Run ./setup_ios.command on a Mac.')
with plist_path.open('rb') as f:
    info = plistlib.load(f)
for key in ('CFBundleDisplayName', 'NSFaceIDUsageDescription',
            'NSMicrophoneUsageDescription', 'NSSpeechRecognitionUsageDescription'):
    if not info.get(key):
        sys.exit('FAIL: Missing iOS key ' + key)
    print('PASS:', key)
if not (root / 'ios/Runner.xcodeproj/project.pbxproj').exists():
    sys.exit('FAIL: Runner.xcodeproj is missing.')
print('PASS: Xcode Runner project found.')
print('NOTE: This does not verify signing, compiling, Face ID or voice on a real iPhone.')
