#!/usr/bin/env python3
"""Idempotent macOS/iOS (plus Android) post-`flutter create` config.

Generated iOS project is intentionally created with the user's installed Flutter
SDK rather than bundling version-specific generated Xcode project files.
"""
from pathlib import Path
import plistlib
import re
import sys

root = Path(__file__).resolve().parents[1]
ios = root / 'ios/Runner/Info.plist'
android = root / 'android/app/src/main/AndroidManifest.xml'
if not ios.exists():
    sys.exit('Missing ios/Runner/Info.plist. Run flutter create --platforms=ios,android --org com.rollerguard . on your Mac first.')

with ios.open('rb') as f:
    plist = plistlib.load(f)
plist.update({
    'CFBundleDisplayName': 'RollerGuard',
    'NSFaceIDUsageDescription': 'Face ID or device authentication helps protect access to the RollerGuard demo app.',
    'NSMicrophoneUsageDescription': 'Microphone access is used only when you tap the push-to-talk voice command button.',
    'NSSpeechRecognitionUsageDescription': 'Recognize explicit short voice commands for the RollerGuard simulator.',
})
with ios.open('wb') as f:
    plistlib.dump(plist, f, fmt=plistlib.FMT_XML, sort_keys=False)

proj = root / 'ios/Runner.xcodeproj/project.pbxproj'
if proj.exists():
    project = proj.read_text()
    # Preserve higher deployment targets; ensure iOS 13 minimum for local_auth.
    def min_ios(m):
        n = m.group(1)
        return 'IPHONEOS_DEPLOYMENT_TARGET = 13.0;' if float(n) < 13.0 else m.group(0)
    project = re.sub(r'IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([0-9]+(?:\.[0-9]+)?);', min_ios, project)
    proj.write_text(project)

podfile = root / 'ios/Podfile'
if podfile.exists():
    s = podfile.read_text()
    pattern = r'^\s*#?\s*platform\s+:ios,\s*[\"\']([0-9.]+)[\"\'].*$'
    if re.search(pattern, s, re.M):
        def min_pod(m):
            try: return "platform :ios, '13.0'" if float(m.group(1)) < 13.0 else m.group(0)
            except ValueError: return m.group(0)
        s = re.sub(pattern, min_pod, s, count=1, flags=re.M)
    else:
        s = "platform :ios, '13.0'\n" + s
    podfile.write_text(s)

if android.exists():
    s = android.read_text()
    needed = ['android.permission.USE_BIOMETRIC',
              'android.permission.RECORD_AUDIO',
              'android.permission.INTERNET']
    additions = ''.join('    <uses-permission android:name="'+name+'" />\n' for name in needed if name not in s)
    if additions:
        s = re.sub(r'(<manifest\b[^>]*>)',lambda m: m.group(1)+'\n'+additions,s,count=1)
    if '<queries>' not in s:
        s = s.replace('<application', """<queries>
        <intent><action android:name="android.speech.RecognitionService" /></intent>
    </queries>
    <application""",1)
    android.write_text(s)
    for kt in (root/'android/app/src/main').rglob('MainActivity.kt'):
        k = kt.read_text().replace('io.flutter.embedding.android.FlutterActivity',
            'io.flutter.embedding.android.FlutterFragmentActivity')
        k = k.replace('extends FlutterActivity()', 'extends FlutterFragmentActivity()')
        k = k.replace(': FlutterActivity()', ': FlutterFragmentActivity()')
        kt.write_text(k)
    for gradle in (root/'android/app/build.gradle.kts', root/'android/app/build.gradle'):
        if gradle.exists():
            k = gradle.read_text().replace('minSdk = flutter.minSdkVersion', 'minSdk = 24')
            k = k.replace('minSdkVersion flutter.minSdkVersion','minSdkVersion 24')
            gradle.write_text(k)
print('iOS: Runner display name, Face ID, microphone, speech recognition and deployment target configured.')
print('Android: manifest and FragmentActivity configured where generated.')
print('IMPORTANT: Xcode team / bundle ID signing must be selected by the owner on their Mac.')
