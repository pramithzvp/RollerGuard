import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'core/safety_policy.dart';
import 'services/demo_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RollerGuardApp());
}

class RollerGuardApp extends StatelessWidget {
  const RollerGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF42DAB6),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'RollerGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colors,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF090F1C),
        cardTheme: CardThemeData(
          color: const Color(0xFF152136),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final DemoDoorController controller = DemoDoorController();
  final LocalAuthentication deviceAuth = LocalAuthentication();
  final stt.SpeechToText speech = stt.SpeechToText();
  int tabIndex = 0;
  bool isListening = false;
  String lastHeard = 'Say: open door, close door, or stop door';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_onControllerChange);
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) controller.lock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(_onControllerChange);
    controller.dispose();
    speech.stop();
    super.dispose();
  }

  void tell(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> authenticateDevice(String reason) async {
    try {
      final supported = await deviceAuth.isDeviceSupported();
      if (!supported) return false;
      return await deviceAuth.authenticate(localizedReason: reason);
    } catch (error) {
      tell('Device authentication not available: $error');
      return false;
    }
  }

  Future<void> unlockDevice() async {
    final verified = await authenticateDevice('Unlock RollerGuard demonstration');
    if (!mounted) return;
    if (verified) {
      controller.unlockAfterDeviceAuth();
      tell('App unlocked for 60 seconds of inactivity.');
    } else {
      tell('Device authentication unavailable or cancelled. DEMO bypass is separate.');
    }
  }

  Future<void> issue(DoorCommand command, {bool fromVoice = false}) async {
    controller.touch();
    // Tell the user how to unlock FIRST; only prompt for CLOSE confirmation
    // when the current snapshot allows requesting CLOSE. The controller
    // rechecks the safety policy at the actual command boundary.
    if (command != DoorCommand.stop) {
      final preflight = const SafetyPolicy().evaluate(
        command, controller.snapshot, now: DateTime.now());
      if (!preflight.allowed) {
        final denied = controller.command(command); // preserves audit trail
        tell(denied.message);
        return;
      }
    }
    if (command == DoorCommand.close) {
      bool acknowledged = false;
      final agreed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) => AlertDialog(
            title: const Text('Confirm CLOSE request'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('A closing roller door can crush or trap a person. '
                    'In a real installation, independent monitored safety devices are essential.'),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: acknowledged,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I have verified the doorway is clear.'),
                  onChanged: (value) => update(() => acknowledged = value ?? false),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
              FilledButton(
                onPressed: acknowledged
                  ? () => Navigator.pop(dialogContext, true) : null,
                child: const Text('Confirm close'),
              ),
            ],
          ),
        ),
      );
      if (agreed != true || !mounted) return;
    }
    final result = controller.command(command);
    tell(result.message);
  }

  Future<void> microphone() async {
    if (isListening) {
      await speech.stop();
      if (mounted) setState(() => isListening = false);
      return;
    }
    try {
      final available = await speech.initialize(
        onStatus: (status) {
          if (mounted && (status == 'done' || status == 'notListening')) {
            setState(() => isListening = false);
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() => isListening = false);
            tell('Voice recognition error: ${error.errorMsg}');
          }
        },
      );
      if (!available) {
        tell('Speech recognition unavailable. Check microphone permissions.');
        return;
      }
      setState(() => isListening = true);
      await speech.listen(
        listenFor: const Duration(seconds: 10),
        onResult: (result) {
          if (!mounted) return;
          setState(() => lastHeard = result.recognizedWords);
          if (result.finalResult) _handleVoice(result.recognizedWords);
        },
      );
    } catch (error) {
      if (mounted) setState(() => isListening = false);
      tell('Voice is unavailable: $error');
    }
  }

  void _handleVoice(String raw) {
    // Exact phrases only. Never allow "don't open door" or a long sentence
    // containing a command to trigger physical movement.
    final phrase = raw.toLowerCase()
        .replaceAll(RegExp(r'[^a-z ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ').trim();
    DoorCommand? command;
    if (phrase == 'stop door' || phrase == 'stop gate') {
      command = DoorCommand.stop;
    } else if (phrase == 'close door' || phrase == 'close gate') {
      command = DoorCommand.close;
    } else if (phrase == 'open door' || phrase == 'open gate') {
      command = DoorCommand.open;
    }
    if (command == null) {
      tell('No matching command. Try "open door", "close door", or "stop door".');
    } else {
      issue(command, fromVoice: true);
    }
  }

  Color positionColor(DoorPosition position) => switch (position) {
    DoorPosition.closed => Colors.greenAccent,
    DoorPosition.open => Colors.lightBlueAccent,
    DoorPosition.opening || DoorPosition.closing => Colors.amberAccent,
    DoorPosition.stopped || DoorPosition.unknown => Colors.orangeAccent,
  };

  Widget tag(String text, Color color, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
      border: Border.all(color: color.withValues(alpha: 0.35)),
      borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 5)],
      Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget section(String title, {String? hint}) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      if (hint != null) Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(hint, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ),
    ]),
  );

  // A calm, two-tab interface: important daily actions are on one screen.
  // Advanced simulation features remain available under More.
  static const Color mint = Color(0xFF52E3C3);
  static const Color violet = Color(0xFF9FA5FF);
  static const Color panel = Color(0xFF142137);
  static const Color muted = Color(0xFFA6B6CC);

  Widget _smallPill(String label, {required bool positive, IconData? symbol}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: positive ? mint.withValues(alpha: 0.12) :
          const Color(0xFFFFC86B).withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(symbol ?? (positive ? Icons.check_circle : Icons.info_outline),
          size: 14, color: positive ? mint : const Color(0xFFFFCF87)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(
          color: positive ? mint : const Color(0xFFFFCF87),
          fontSize: 12, fontWeight: FontWeight.w700,
        )),
      ]),
    );

  Widget _actionTile({
    required String name,
    required String note,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) => Expanded(
    child: Semantics(
      button: true, label: '$name door – demo only',
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.09),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 33, color: const Color(0xFF111B2A)),
              ),
              const SizedBox(height: 13),
              Text(name, style: const TextStyle(
                color: Color(0xFF0B1827), fontSize: 20,
                fontWeight: FontWeight.w800,
              )),
              const SizedBox(height: 3),
              Text(note, style: const TextStyle(
                color: Color(0xFF233346), fontSize: 12,
              )),
            ]),
          ),
        ),
      ),
    ),
  );

  Widget home() {
    final state = controller.displayedPosition;
    final safe = !controller.hazardous;
    final statusColor = positionColor(state);
    final ready = controller.appUnlocked &&
      !controller.remoteControlLocked &&
      controller.currentRole != AccessRole.viewer;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(children: [
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Garage', style: TextStyle(
                fontSize: 29, fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              )),
              SizedBox(height: 4),
              Text('Simple control. Peace of mind.',
                style: TextStyle(color: muted, fontSize: 14)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF26314A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(children: [
              Icon(Icons.science_outlined, size: 16, color: Color(0xFFFFD082)),
              SizedBox(width: 5),
              Text('DEMO', style: TextStyle(
                fontWeight: FontWeight.w800, letterSpacing: 0.6,
                fontSize: 12, color: Color(0xFFFFD082))),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF203F65), Color(0xFF142A48), Color(0xFF18233E)],
            ),
            border: Border.all(color: const Color(0xFF3B587A)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 19, 22, 20),
          child: Column(children: [
            Row(children: [
              const Expanded(child: Text('ROLLER DOOR 01',
                style: TextStyle(color: Color(0xFFBCD5F0),
                  letterSpacing: 1.2, fontWeight: FontWeight.w700,
                  fontSize: 11))),
              _smallPill(controller.online ? 'Simulator online' : 'Offline',
                positive: controller.online, symbol: Icons.wifi),
            ]),
            const SizedBox(height: 10),
            Icon(Icons.garage_rounded, size: 104, color: statusColor),
            const SizedBox(height: 5),
            Text(state.label.toUpperCase(),
              style: TextStyle(color: statusColor,
                fontSize: 29, fontWeight: FontWeight.w900,
                letterSpacing: 1.0)),
            const SizedBox(height: 5),
            Text(state == DoorPosition.unknown
                ? 'Sensor status cannot be verified'
                : 'Simulated door position',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFD4DCE9), fontSize: 13)),
            const SizedBox(height: 16),
            Wrap(alignment: WrapAlignment.center,
              spacing: 8, runSpacing: 8, children: [
              _smallPill(safe ? 'Sensors OK' : 'Check safety', positive: safe,
                symbol: Icons.shield_outlined),
              _smallPill(controller.remoteControlLocked
                  ? 'Remote locked' : 'Remote enabled',
                positive: !controller.remoteControlLocked,
                symbol: Icons.lock_outline),
            ]),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('Control your door', style: TextStyle(
          fontSize: 19, fontWeight: FontWeight.w800,
        )),
        const SizedBox(height: 5),
        const Text('Tap a button to request an action.',
          style: TextStyle(color: muted, fontSize: 13)),
        const SizedBox(height: 13),
        Row(children: [
          _actionTile(name: 'OPEN', note: 'Raise the door',
            icon: Icons.keyboard_double_arrow_up_rounded, color: mint,
            onTap: () => issue(DoorCommand.open)),
          const SizedBox(width: 12),
          _actionTile(name: 'CLOSE', note: 'Lower the door',
            icon: Icons.keyboard_double_arrow_down_rounded, color: violet,
            onTap: () => issue(DoorCommand.close)),
        ]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: () => issue(DoorCommand.stop),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFF7D88), width: 1.3),
            foregroundColor: const Color(0xFFFF919B),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          ),
          icon: const Icon(Icons.stop_circle_outlined, size: 23),
          label: const Text('STOP REQUEST',
            style: TextStyle(fontWeight: FontWeight.w800)),
        )),
        const SizedBox(height: 6),
        const Text('App STOP is not a physical emergency stop.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: muted)),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(color: panel,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFF2D3B54))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(ready ? Icons.verified_user : Icons.lock_outline,
                size: 21, color: ready ? mint : const Color(0xFFFFD082)),
              const SizedBox(width: 9),
              Expanded(child: Text(
                ready ? 'Controls are ready' : 'Unlock to control',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 5),
            Text(
              !controller.appUnlocked
                ? 'Step 1: verify with Face ID or device passcode.'
                : controller.remoteControlLocked
                  ? 'Step 2: enable remote control below.'
                  : 'Commands still need permission and safety checks.',
              style: const TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 13),
            if (!controller.appUnlocked)
              SizedBox(width: double.infinity,
                child: FilledButton.icon(
                  onPressed: unlockDevice,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Unlock with Face ID / Passcode'),
                  style: FilledButton.styleFrom(
                    backgroundColor: mint, foregroundColor: const Color(0xFF102233),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              )
            else ...[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: mint,
                title: const Text('Allow remote control',
                  style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Turn off when not in use',
                  style: TextStyle(color: muted, fontSize: 12)),
                value: !controller.remoteControlLocked,
                onChanged: controller.currentRole == AccessRole.owner
                  ? (on) => controller.setRemoteLock(!on)
                  : null,
              ),
              TextButton.icon(onPressed: controller.lock,
                icon: const Icon(Icons.lock_outline, size: 16),
                label: const Text('Lock app now')),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        Material(
          color: panel,
          borderRadius: BorderRadius.circular(21),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(children: [
              Container(
                decoration: BoxDecoration(color: violet.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.mic_rounded, color: violet, size: 25),
              ),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Voice control',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(isListening ? 'Listening…' : lastHeard,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: muted)),
                ],
              )),
              IconButton.filledTonal(
                tooltip: isListening ? 'Stop listening' : 'Speak a command',
                onPressed: microphone,
                icon: Icon(isListening ? Icons.mic_off : Icons.mic),
              ),
            ]),
          ),
        ),
        if (controller.hazardous) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF4A2D2E),
              borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFCB84)),
              const SizedBox(width: 10),
              const Expanded(child: Text(
                'Safety warning in demo. Check More → Safety tests.',
                style: TextStyle(fontSize: 12))),
              TextButton(onPressed: () => setState(() => tabIndex = 4),
                child: const Text('View')),
            ]),
          ),
        ],
        const SizedBox(height: 15),
        const Center(child: Text(
          'DEMO ONLY • No hardware or real gate connected',
          style: TextStyle(color: muted, fontSize: 11),
        )),
      ],
    );
  }

  Widget more() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
    children: [
      const Text('More', style: TextStyle(
        fontSize: 30, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      const Text('Extra features, only when you need them.',
        style: TextStyle(color: muted)),
      const SizedBox(height: 18),
      Card(child: Column(children: [
        ListTile(
          leading: const Icon(Icons.people_alt_outlined, color: mint),
          title: const Text('Authorized users'),
          subtitle: const Text('Invite & manage access (demo)'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => setState(() => tabIndex = 2),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.history_rounded, color: violet),
          title: const Text('Activity history'),
          subtitle: const Text('See what happened in the app'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => setState(() => tabIndex = 3),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.health_and_safety_outlined,
            color: Color(0xFFFFC776)),
          title: const Text('Safety tests'),
          subtitle: const Text('Simulate sensors and test access roles'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => setState(() => tabIndex = 4),
        ),
      ])),
      const SizedBox(height: 18),
      const Text('App security',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Card(child: Column(children: [
        ListTile(
          leading: Icon(controller.appUnlocked
              ? Icons.lock_open : Icons.lock_outline),
          title: Text(controller.appUnlocked ? 'App unlocked' : 'App locked'),
          subtitle: const Text('Auto-locks when in the background'),
          trailing: controller.appUnlocked
            ? TextButton(onPressed: controller.lock,
                child: const Text('Lock'))
            : TextButton(onPressed: unlockDevice,
                child: const Text('Unlock')),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.science_outlined,
            color: Color(0xFFFFC776)),
          title: const Text('Test unlock (DEMO ONLY)'),
          subtitle: const Text('Bypasses biometrics only in this simulator'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            controller.unlockDemo();
            tell('Demo session unlocked. Not valid for real hardware.');
          },
        ),
      ])),
      const SizedBox(height: 15),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 6),
        child: Text('This app is a simulator. Real users, logs, safety sensors, '
          'physical stop devices and authorization must be implemented and '
          'tested on dedicated hardware and a secure gateway.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.5))),
    ],
  );

  Widget userManagement() {
    final canManage = controller.appUnlocked && controller.currentRole == AccessRole.owner;
    return ListView(padding: const EdgeInsets.all(16), children: [
      section('Authorized users', hint: 'Role-based access · expiring grants · revoke access'),
      const Card(child: ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('This page is a local simulation'),
        subtitle: Text('Real user accounts, identity verification, and revocation must be enforced '
          'by a secure server/gateway, not a list stored in the app.'),
      )),
      Card(child: Column(children: [
        const ListTile(
          leading: CircleAvatar(child: Icon(Icons.star)),
          title: Text('Demo Owner'),
          subtitle: Text('Owner · simulated local session'),
          trailing: Icon(Icons.verified, color: Colors.greenAccent),
        ),
        ...controller.users.map((user) => ListTile(
          leading: CircleAvatar(child: Text(user.name.substring(0, 1).toUpperCase())),
          title: Text(user.name),
          subtitle: Text('${user.role.name.toUpperCase()} · '
            '${user.active ? "Active" : (user.revoked ? "Revoked" : "Expired")} · '
            'Expires ${formatTime(user.expires)}'),
          trailing: user.revoked ? const Icon(Icons.block) : IconButton(
            tooltip: 'Revoke demo grant',
            icon: const Icon(Icons.person_remove_outlined),
            onPressed: canManage ? () => controller.revokeUser(user.id) : null,
          ),
        )),
      ])),
      const SizedBox(height: 10),
      FilledButton.icon(
        onPressed: canManage ? inviteUser : null,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add a DEMO access grant'),
      ),
      section('Access rules'),
      const Card(child: Column(children: [
        ListTile(leading: Icon(Icons.shield), title: Text('Owner'),
          subtitle: Text('Control, manage users and remote lock.')),
        Divider(height: 1),
        ListTile(leading: Icon(Icons.settings_remote), title: Text('Operator'),
          subtitle: Text('Open / close only when safety checks pass.')),
        Divider(height: 1),
        ListTile(leading: Icon(Icons.visibility_outlined), title: Text('Viewer'),
          subtitle: Text('Read-only. Motion requests are blocked.')),
      ])),
    ]);
  }

  Future<void> inviteUser() async {
    final name = TextEditingController();
    AccessRole role = AccessRole.viewer;
    int hours = 24;
    final create = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          title: const Text('Add demo grant'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, maxLength: 40, decoration: const InputDecoration(
              labelText: 'Display name', border: OutlineInputBorder())),
            DropdownButtonFormField<AccessRole>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: AccessRole.values.map((item) => DropdownMenuItem(
                value: item, child: Text(item.name))).toList(),
              onChanged: (value) => update(() => role = value ?? role),
            ),
            DropdownButtonFormField<int>(
              initialValue: hours,
              decoration: const InputDecoration(labelText: 'Expires in'),
              items: const [
                DropdownMenuItem(value: 1, child: Text('1 hour')),
                DropdownMenuItem(value: 24, child: Text('24 hours')),
                DropdownMenuItem(value: 168, child: Text('7 days')),
              ],
              onChanged: (value) => update(() => hours = value ?? hours),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Add demo grant')),
          ],
        ),
      ),
    );
    if (create == true && name.text.trim().isNotEmpty) {
      controller.addUser(name.text.trim(), role, hours);
      tell('Demo access grant created. No actual account or invitation sent.');
    }
    name.dispose();
  }

  String formatTime(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Widget activity() => ListView(padding: const EdgeInsets.all(16), children: [
    section('Audit trail', hint: 'In-memory demonstration records. Not tamper-proof or permanent.'),
    const Card(child: ListTile(
      leading: Icon(Icons.cloud_off_outlined, color: Colors.amberAccent),
      title: Text('Production needs server-side immutable audit storage'),
      subtitle: Text('Include user ID, device ID, time, command, denied reason, '
        'actual controller acknowledgement, and final sensor-confirmed result.'),
    )),
    ...controller.events.map((event) {
      final color = switch (event.kind) {
        'success' => Colors.greenAccent,
        'denied' => Colors.redAccent,
        'warning' => Colors.amberAccent,
        _ => Colors.lightBlueAccent,
      };
      return Card(child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(event.kind == 'denied' ? Icons.block : Icons.history,
            color: color)),
        title: Text(event.message, style: const TextStyle(fontSize: 13)),
        subtitle: Text(formatTime(event.timestamp),
          style: const TextStyle(fontSize: 11)),
      ));
    }),
  ]);

  Widget safetySwitch(String title, String subtitle, bool value,
    ValueChanged<bool> onChange, {bool dangerWhenOn = true}) => Card(
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChange,
        secondary: Icon(value == dangerWhenOn
          ? Icons.warning_amber_rounded : Icons.check_circle_outline,
          color: value == dangerWhenOn ? Colors.amberAccent : Colors.greenAccent),
      ),
    );

  Widget safety() => ListView(padding: const EdgeInsets.all(16), children: [
    section('Safeguards test panel', hint: 'Simulated external inputs · not connected to hardware'),
    const Card(child: ListTile(
      leading: Icon(Icons.health_and_safety, color: Colors.amberAccent),
      title: Text('Real safety must live in certified hardware'),
      subtitle: Text('Physical E-stop, monitored photo-eyes / safety edges, manual release, '
        'and motor controller interlocks operate independently of this phone.'),
    )),
    safetySwitch('Controller online', 'Block new motion commands on disconnection.',
      controller.online,
      (v) => controller.updateSafety(isOnline: v), dangerWhenOn: false),
    safetySwitch('Position feedback available',
      'No sensor feedback means UNKNOWN; deny new movement.',
      controller.feedbackAvailable,
      (v) => controller.updateSafety(feedback: v), dangerWhenOn: false),
    safetySwitch('Safety sensors healthy',
      'A fault prevents remote CLOSE commands.',
      controller.safetySensorsHealthy,
      (v) => controller.updateSafety(sensorsHealthy: v), dangerWhenOn: false),
    safetySwitch('Obstruction detected',
      'A detected obstacle prevents simulated CLOSE.',
      controller.obstructionDetected,
      (v) => controller.updateSafety(obstruction: v)),
    safetySwitch('Physical E-stop engaged (simulate)',
      'Only a person at the real gate should reset a physical E-stop.',
      controller.physicalStopEngaged,
      (v) => controller.updateSafety(physicalStop: v)),
    safetySwitch('Manual release engaged (simulate)',
      'Remote commands blocked while manual release is in use.',
      controller.manualReleaseEngaged,
      (v) => controller.updateSafety(manualRelease: v)),
    safetySwitch('Maintenance mode',
      'Prevent commands during inspection or repairs.',
      controller.maintenanceMode,
      (v) => controller.updateSafety(maintenance: v)),
    section('Test access role'),
    Card(child: ListTile(
      leading: const Icon(Icons.badge_outlined),
      title: const Text('Simulate current role'),
      subtitle: const Text('Switching roles always locks the demo app.'),
      trailing: DropdownButton<AccessRole>(
        value: controller.currentRole,
        items: AccessRole.values.map((role) => DropdownMenuItem(
          value: role,
          child: Text(role.name.toUpperCase(), style: const TextStyle(fontSize: 12)),
        )).toList(),
        onChanged: (role) { if (role != null) controller.setRole(role); },
      ),
    )),
    section('Override policy'),
    const Card(child: Padding(padding: EdgeInsets.all(16), child: Text(
      'SAFE: a physical keyed manual-release mechanism, hardware E-stop, '
      'controller-controlled safe reset, and fail-safe loss-of-signal behavior.\n\n'
      'NOT ALLOWED: using the app to bypass safety edges, override obstruction '
      'detection, cancel an E-stop, or force movement during maintenance.\n\n'
      'App REQUEST STOP is a convenience command, never the only emergency stop.',
      style: TextStyle(height: 1.5),
    ))),
  ]);

  @override
  Widget build(BuildContext context) {
    final pages = [home(), more(), userManagement(), activity(), safety()];
    final isNested = tabIndex > 1;
    final titles = {2: 'Authorized users', 3: 'Activity', 4: 'Safety tests'};
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF101B2D),
        leading: isNested
          ? IconButton(
              tooltip: 'Back to More',
              onPressed: () => setState(() => tabIndex = 1),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ) : null,
        title: Row(children: [
          if (!isNested) ...[
            const Icon(Icons.shield_rounded, color: mint, size: 23),
            const SizedBox(width: 8),
          ],
          Text(isNested ? titles[tabIndex]! : 'RollerGuard',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        ]),
        actions: [
          if (controller.appUnlocked)
            IconButton(
              tooltip: 'Lock app',
              onPressed: controller.lock,
              icon: const Icon(Icons.lock_outline_rounded),
            ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: controller.touch,
        child: pages[tabIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex == 0 ? 0 : 1,
        backgroundColor: const Color(0xFF101B2D),
        indicatorColor: const Color(0xFF245E68),
        onDestinationSelected: (index) {
          controller.touch();
          setState(() => tabIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
