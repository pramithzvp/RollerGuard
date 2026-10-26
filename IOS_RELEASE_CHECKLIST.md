# iOS installation acceptance checklist (DEMO)

- [ ] `flutter doctor -v` shows compatible Flutter, Xcode, CocoaPods
- [ ] `./setup_ios.command` runs successfully
- [ ] `python3 scripts/verify_ios.py` shows all four keys
- [ ] `flutter test` passes on the Mac
- [ ] Xcode automatic signing configured with correct Team and a unique Bundle Identifier
- [ ] iPhone recognized in `flutter devices` and Developer Mode enabled
- [ ] `flutter run -d <ID>` successfully opens app on physical iPhone
- [ ] Face ID/passcode unlock works (only protects local simulator)
- [ ] Denying mic permission prevents voice but leaves manual buttons working
- [ ] 'open door', 'close door', 'stop door' only work when voice button tapped
- [ ] CLOSE requires confirmation
- [ ] Simulated Obstruction or Sensor Fault blocks CLOSE
- [ ] App is locked in background and remote lock defaults to ON
- [ ] Phone airplane mode does not falsely claim a real gate status: UI explicitly labelled SIMULATOR
- [ ] No real door or physical control hardware is connected
