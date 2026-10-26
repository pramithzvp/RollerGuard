/// Safety preflight for the demonstration application.
/// IMPORTANT: This is NOT a certified safety controller. Physical safety devices
/// and server-side authorization must make independent decisions.
enum DoorPosition { closed, open, opening, closing, stopped, unknown }
enum DoorCommand { open, close, stop }
enum AccessRole { owner, operator, viewer }

extension DoorCommandLabel on DoorCommand {
  String get label => switch (this) {
    DoorCommand.open => 'OPEN',
    DoorCommand.close => 'CLOSE',
    DoorCommand.stop => 'REQUEST STOP',
  };
}

extension DoorPositionLabel on DoorPosition {
  String get label => switch (this) {
    DoorPosition.closed => 'Closed',
    DoorPosition.open => 'Open',
    DoorPosition.opening => 'Opening',
    DoorPosition.closing => 'Closing',
    DoorPosition.stopped => 'Stopped',
    DoorPosition.unknown => 'Unknown',
  };
}

class SafetySnapshot {
  const SafetySnapshot({
    required this.position,
    required this.role,
    required this.appUnlocked,
    required this.remoteControlLocked,
    required this.online,
    required this.feedbackAvailable,
    required this.safetySensorsHealthy,
    required this.obstructionDetected,
    required this.physicalStopEngaged,
    required this.manualReleaseEngaged,
    required this.maintenanceMode,
    required this.lastCommandAt,
  });

  final DoorPosition position;
  final AccessRole role;
  final bool appUnlocked;
  final bool remoteControlLocked;
  final bool online;
  final bool feedbackAvailable;
  final bool safetySensorsHealthy;
  final bool obstructionDetected;
  final bool physicalStopEngaged;
  final bool manualReleaseEngaged;
  final bool maintenanceMode;
  final DateTime? lastCommandAt;
}

class PolicyDecision {
  const PolicyDecision.allowed() : allowed = true, reason = 'Allowed';
  const PolicyDecision.denied(this.reason) : allowed = false;
  final bool allowed;
  final String reason;
}

class SafetyPolicy {
  const SafetyPolicy();

  PolicyDecision evaluate(
    DoorCommand command,
    SafetySnapshot s, {
    required DateTime now,
  }) {
    // A stop request is deliberately independent of the app lock, role, and
    // motion preflight. Unlike a physical E-stop, this is BEST-EFFORT only.
    if (command == DoorCommand.stop) {
      if (!s.online) {
        return const PolicyDecision.denied('Controller offline. Use the physical emergency stop.');
      }
      return const PolicyDecision.allowed();
    }

    if (!s.online) {
      return const PolicyDecision.denied('Offline: motion requests blocked.');
    }
    if (s.physicalStopEngaged) {
      return const PolicyDecision.denied('Physical emergency stop engaged. Reset at the gate.');
    }
    if (s.manualReleaseEngaged) {
      return const PolicyDecision.denied('Manual release engaged. Remote movement disabled.');
    }
    if (s.maintenanceMode) {
      return const PolicyDecision.denied('Maintenance mode enabled. Remote movement disabled.');
    }
    if (s.remoteControlLocked) {
      return const PolicyDecision.denied('Remote-control lock is ON.');
    }
    if (!s.appUnlocked) {
      return const PolicyDecision.denied('Unlock the app to use door controls.');
    }
    if (s.role == AccessRole.viewer) {
      return const PolicyDecision.denied('Viewer role cannot move the door.');
    }
    if (!s.feedbackAvailable ||
        s.position == DoorPosition.unknown || s.position == DoorPosition.stopped) {
      return const PolicyDecision.denied('Unverified door position: movement blocked.');
    }
    if (s.lastCommandAt != null &&
        now.difference(s.lastCommandAt!).inMilliseconds < 1800) {
      return const PolicyDecision.denied('Command cooldown: please avoid repeated taps.');
    }
    if (s.position == DoorPosition.opening || s.position == DoorPosition.closing) {
      return const PolicyDecision.denied('Door already moving. Use REQUEST STOP first.');
    }
    if (command == DoorCommand.close) {
      if (!s.safetySensorsHealthy) {
        return const PolicyDecision.denied('Safety sensor fault: closing blocked.');
      }
      if (s.obstructionDetected) {
        return const PolicyDecision.denied('Obstruction detected: closing blocked.');
      }
      if (s.position == DoorPosition.closed) {
        return const PolicyDecision.denied('Door is already closed.');
      }
    }
    if (command == DoorCommand.open && s.position == DoorPosition.open) {
      return const PolicyDecision.denied('Door is already open.');
    }
    return const PolicyDecision.allowed();
  }
}
