import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/safety_policy.dart';

class AuditEvent {
  AuditEvent(this.message, this.kind) : timestamp = DateTime.now();
  final DateTime timestamp;
  final String message;
  final String kind;
}

class AccessGrant {
  AccessGrant({required this.id, required this.name, required this.role,
    required this.expires, this.revoked = false});
  final int id;
  final String name;
  final AccessRole role;
  final DateTime expires;
  bool revoked;
  bool get active => !revoked && expires.isAfter(DateTime.now());
}

class CommandResult {
  const CommandResult(this.ok, this.message);
  final bool ok;
  final String message;
}

/// Intentionally DEMO ONLY: in-memory state, no radio/network/motor connection.
class DemoDoorController extends ChangeNotifier {
  final SafetyPolicy _policy = const SafetyPolicy();
  final List<AuditEvent> events = [];
  final List<AccessGrant> users = [];

  DoorPosition position = DoorPosition.closed;
  AccessRole currentRole = AccessRole.owner;
  bool appUnlocked = false;
  bool remoteControlLocked = true;
  bool online = true;
  bool feedbackAvailable = true;
  bool safetySensorsHealthy = true;
  bool obstructionDetected = false;
  bool physicalStopEngaged = false;
  bool manualReleaseEngaged = false;
  bool maintenanceMode = false;
  DateTime? lastCommandAt;
  Timer? _motionTimer;
  Timer? _autoLockTimer;
  int _nextId = 1;

  DemoDoorController() {
    log('DEMO controller started. Remote control LOCKED by default.', 'info');
  }

  SafetySnapshot get snapshot => SafetySnapshot(
    position: (online && feedbackAvailable) ? position : DoorPosition.unknown,
    role: currentRole,
    appUnlocked: appUnlocked,
    remoteControlLocked: remoteControlLocked,
    online: online,
    feedbackAvailable: feedbackAvailable,
    safetySensorsHealthy: safetySensorsHealthy,
    obstructionDetected: obstructionDetected,
    physicalStopEngaged: physicalStopEngaged,
    manualReleaseEngaged: manualReleaseEngaged,
    maintenanceMode: maintenanceMode,
    lastCommandAt: lastCommandAt,
  );

  DoorPosition get displayedPosition => snapshot.position;
  bool get moving => position == DoorPosition.opening || position == DoorPosition.closing;
  bool get hazardous => physicalStopEngaged || manualReleaseEngaged ||
      maintenanceMode || !safetySensorsHealthy || obstructionDetected ||
      !feedbackAvailable || !online;

  void log(String message, String kind) {
    events.insert(0, AuditEvent(message, kind));
    if (events.length > 80) events.removeLast();
    notifyListeners();
  }

  void unlockDemo() {
    appUnlocked = true;
    touch();
    log('Demo-only local session unlocked (NOT a real identity verification).', 'warning');
  }

  void unlockAfterDeviceAuth() {
    appUnlocked = true;
    touch();
    log('Device verification accepted for demo app unlock.', 'success');
  }

  void lock() {
    if (appUnlocked) {
      appUnlocked = false;
      _autoLockTimer?.cancel();
      log('App manually/automatically locked.', 'info');
    }
  }

  void touch() {
    if (!appUnlocked) return;
    _autoLockTimer?.cancel();
    _autoLockTimer = Timer(const Duration(seconds: 60), lock);
  }

  void setRole(AccessRole role) {
    currentRole = role;
    lock();
    log('Demo preview role changed to ${role.name}. Session locked.', 'info');
  }

  void setRemoteLock(bool locked) {
    if (currentRole != AccessRole.owner || !appUnlocked) return;
    remoteControlLocked = locked;
    log('DEMO remote-control lock: ${locked ? "ON" : "OFF"}', 'warning');
    touch();
  }

  void updateSafety({
    bool? isOnline,
    bool? feedback,
    bool? sensorsHealthy,
    bool? obstruction,
    bool? physicalStop,
    bool? manualRelease,
    bool? maintenance,
  }) {
    if (isOnline != null) online = isOnline;
    if (feedback != null) feedbackAvailable = feedback;
    if (sensorsHealthy != null) safetySensorsHealthy = sensorsHealthy;
    if (obstruction != null) obstructionDetected = obstruction;
    if (physicalStop != null) physicalStopEngaged = physicalStop;
    if (manualRelease != null) manualReleaseEngaged = manualRelease;
    if (maintenance != null) maintenanceMode = maintenance;
    // In the simulator, a physical stop/release/fault interrupts closing.
    // This does NOT model certified anti-entrapment response/reversal.
    if ((physicalStopEngaged || manualReleaseEngaged || maintenanceMode ||
        obstructionDetected || !safetySensorsHealthy || !feedbackAvailable) && moving) {
      _halt('Demo motion halted by simulated safety state');
    }
    log('Simulated safety/connection input changed.', 'warning');
  }

  CommandResult command(DoorCommand command) {
    final decision = _policy.evaluate(command, snapshot, now: DateTime.now());
    if (!decision.allowed) {
      log('DENIED ${command.label}: ${decision.reason}', 'denied');
      return CommandResult(false, decision.reason);
    }
    if (command == DoorCommand.stop) {
      _halt('STOP request accepted (simulation ONLY)');
      return const CommandResult(true, 'Simulated STOP request accepted. Physical E-stop is separate.');
    }
    lastCommandAt = DateTime.now();
    position = command == DoorCommand.open ? DoorPosition.opening : DoorPosition.closing;
    log('${command.label} accepted by DEMO simulator.', 'success');
    _motionTimer?.cancel();
    _motionTimer = Timer(const Duration(seconds: 4), () {
      if (moving) {
        position = command == DoorCommand.open ? DoorPosition.open : DoorPosition.closed;
        log('DEMO travel finished: ${position.label}', 'success');
      }
    });
    touch();
    notifyListeners();
    return CommandResult(true, 'Simulated ${command.label} started. NO physical motor command sent.');
  }

  void _halt(String reason) {
    _motionTimer?.cancel();
    if (moving) position = DoorPosition.stopped;
    log(reason, 'warning');
  }

  void addUser(String name, AccessRole role, int hours) {
    if (!appUnlocked || currentRole != AccessRole.owner) return;
    users.add(AccessGrant(
      id: _nextId++, name: name, role: role,
      expires: DateTime.now().add(Duration(hours: hours)),
    ));
    log('DEMO grant added: $name (${role.name}, ${hours}h).', 'info');
    touch();
  }

  void revokeUser(int id) {
    if (!appUnlocked || currentRole != AccessRole.owner) return;
    for (final user in users) {
      if (user.id == id) {
        user.revoked = true;
        log('DEMO grant revoked: ${user.name}.', 'warning');
        break;
      }
    }
    touch();
  }

  @override
  void dispose() {
    _motionTimer?.cancel();
    _autoLockTimer?.cancel();
    super.dispose();
  }
}
