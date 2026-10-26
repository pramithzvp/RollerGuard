import 'package:flutter_test/flutter_test.dart';
import 'package:roller_guard/core/safety_policy.dart';

void main() {
  const policy = SafetyPolicy();
  final now = DateTime.utc(2026, 10, 24, 13);

  SafetySnapshot setup({
    DoorPosition position = DoorPosition.open,
    AccessRole role = AccessRole.owner,
    bool appUnlocked = true,
    bool remoteControlLocked = false,
    bool online = true,
    bool feedback = true,
    bool sensors = true,
    bool obstruction = false,
    bool estop = false,
    bool manual = false,
    bool maintenance = false,
    DateTime? last,
  }) => SafetySnapshot(
    position: position,
    role: role,
    appUnlocked: appUnlocked,
    remoteControlLocked: remoteControlLocked,
    online: online,
    feedbackAvailable: feedback,
    safetySensorsHealthy: sensors,
    obstructionDetected: obstruction,
    physicalStopEngaged: estop,
    manualReleaseEngaged: manual,
    maintenanceMode: maintenance,
    lastCommandAt: last,
  );

  test('close requires sensors and an obstruction-free doorway', () {
    expect(policy.evaluate(DoorCommand.close, setup(sensors: false), now: now).allowed, false);
    expect(policy.evaluate(DoorCommand.close, setup(obstruction: true), now: now).allowed, false);
    expect(policy.evaluate(DoorCommand.close, setup(), now: now).allowed, true);
  });

  test('unknown state never gets a motion request', () {
    expect(policy.evaluate(DoorCommand.open,
      setup(position: DoorPosition.unknown), now: now).allowed, false);
    expect(policy.evaluate(DoorCommand.close,
      setup(feedback: false), now: now).allowed, false);
  });

  test('app lock, remote lock, viewer role, and physical stop block commands', () {
    expect(policy.evaluate(DoorCommand.open, setup(appUnlocked: false), now: now).allowed, false);
    expect(policy.evaluate(DoorCommand.open, setup(remoteControlLocked: true), now: now).allowed, false);
    expect(policy.evaluate(DoorCommand.open, setup(role: AccessRole.viewer), now: now).allowed, false);
    expect(policy.evaluate(DoorCommand.open, setup(estop: true), now: now).allowed, false);
  });

  test('manual release, maintenance, and offline deny remote movement', () {
    for (final snapshot in [setup(manual: true), setup(maintenance: true), setup(online: false)]) {
      expect(policy.evaluate(DoorCommand.close, snapshot, now: now).allowed, false);
    }
  });

  test('stop request allowed despite app lock, but not when offline', () {
    expect(policy.evaluate(DoorCommand.stop,
      setup(appUnlocked: false, role: AccessRole.viewer), now: now).allowed, true);
    expect(policy.evaluate(DoorCommand.stop, setup(online: false), now: now).allowed, false);
  });

  test('rate limiter rejects repeated commands', () {
    expect(policy.evaluate(DoorCommand.close,
      setup(last: now.subtract(const Duration(milliseconds: 600))), now: now).allowed, false);
  });
}
