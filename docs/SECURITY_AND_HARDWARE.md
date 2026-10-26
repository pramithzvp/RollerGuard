# RollerGuard — Production safeguards & hardware design (සිංහල / English)

## 1) Risk model: mobile remote control is an actuator

Phone app එකේ OPEN/CLOSE button එක **physical movement** initiate කරන නිසා authentication එකට අමතරව entrapment / crushing risks design කරන්න ඕන. Remote closing is the highest-risk operation: user may not have direct line of sight and children/pets could be under the door. UI confirmation alone is **never sufficient safety protection**.

## 2) Mandatory hardware protections — app එකෙන් bypass කරන්න බැහැ

1. **Certified motor controller with correct safety wiring.** Original roller-door control board's supported low-voltage OPEN/CLOSE/STEP terminals only; a smart dry-contact relay must *not* be connected across motor mains.
2. **Monitored photo-eye / safety beam** and **pressure-sensitive safety edge / force detection** as applicable to site, operator and local standard. The controller—not the phone—must enforce protection, safe stop/reverse and fault behavior.
3. **Accessible physical emergency stop**, where risk assessment calls for it. Phone `REQUEST STOP` over a network is best effort and cannot substitute.
4. **Manual override / key release** operable during power failure, per original manufacturer instructions. Motor must not start while the drive is mechanically released (where supported).
5. **Position feedback:** hardwired open/closed limit switches and/or controller-provided verified travel state. Missing sensor = UNKNOWN, not “closed” or “open”.
6. **Safety fault/interlock input:** emergency stop, obstruction fault, maintenance mode; must directly inhibit dangerous motion at controller level.
7. **Warning lamp / buzzer + pre-movement warning**, where required for unattended/remote operation. Include appropriate signage and access controls.
8. **Power restoration safety:** controller must not automatically reopen/close after a power outage or app reconnection. No queued stale movement commands.

Manufacturer-specific hardware and qualified installers determine the correct layout. Do not retrofit/defeat existing OEM anti-entrapment circuits. A rolling shutter's installation needs assessment on site.

### High-level architecture

```text
[Android/iPhone app]  <-- HTTPS/TLS, short-lived user auth -->  [Secure Access Gateway]
    FaceID unlock  (UX)                                      RBAC / MFA / audit
    OPEN/CLOSE UI                                             authorization
    voice -> confirm                                          expiring invitations
    display telemetry                                         rate limit / anti-replay
                                                                  |
                                                    authenticated LAN-only protocol
                                                                  |
                                                 [Approved Motor Door Controller]
                                                       |              |
                                              [Open/Close sensors]  [Motor]
                                                       |
                    [Safety beam + safety edge + physical E-stop + manual release]
                          HARDWARE LOOP; cannot be bypassed by gateway/app
```

For smaller installations a local gateway/VPN may be used in place of cloud, but the gate controller must still enforce all safety and interlocks. Never port-forward an unprotected relay's HTTP endpoint to the internet. A compatible smart relay may be used *as an input* to a certified door controller, never as a motor-power switch.

## 3) App security features — production implementation requirements

**Authentication**: individual accounts, phishing-resistant MFA for remote operations, device enrollment, secure session refresh, Android Keystore/iOS Keychain, session expiry, Face ID/biometrics to unlock UX, reauthenticate for risky admin actions. Do not rely only on in-app biometrics: the **backend must authenticate every motion request**.

**Access control / authorized users**: Owner/Admin, Operator, Viewer, time-limited Guest. Every request is checked by backend against door ID, user ID, role, grant expiry, revoked state, and access time window. Owner can revoke instantly. Failed invite = deny. No static shared PIN, no hard-coded relay key in mobile app.

**Lock**: remote-control inhibit enforced **in the gateway AND controller** if supported. App "locked" can be session or remote control locked and is NOT the same as a physical mechanical roller-door lock. If a mechanical lock actuator is desired, use an approved controller with interlock/position sensing and electrical/mechanical fail-safe assessment. **Do not engage a mechanical lock while the motor can run.**

**Stop & override**: remote stop = convenience, subject to network failure. Physical E-stop / key manual release work with phone dead, Wi-Fi down or gateway compromised. Operator cannot remotely disable hardware stops, safety edge or beam. Reset emergency stop physically and inspect gate before restart. Maintenance lockout/tagout requires local authorized process.

**Telemetry**: display separate values for *command sent*, *gateway accepted*, *controller acknowledged*, and *position sensor verified*. An HTTP 200 or relay activation is **not** proof of door position. Timestamp telemetry and expire stale status; fail closed and show UNKNOWN on stale/missing feedback.

**Voice**: push-to-talk; not ambient / always listening. Full auth + request confirmation even for voice commands. For remote/offsite CLOSE, consider disabling completely unless the site-specific certified safety system supports unattended remote closing and required warnings.

**Threat mitigation**: HTTPS + certificate validation, no public unauthenticated relay endpoint, device binding if appropriate, one-time command IDs, server-side nonce/replay validation, max command rate, distinct per-user revoke, immutable audit server logs, fail-safe defaults, firmware updates and restricted LAN access. Avoid storing controller credentials in app assets.

**Privacy**: minimize retention of activity logs and speech data; do not store raw audio. Record who operated door and why blocked, with access controls to the audit trail.

## 4) Required command safety contract (example, NOT a ready backend)

Request (authenticated): `POST /v1/doors/{doorId}/commands`

```json
{
  "command": "CLOSE",
  "request_id": "unique-per-attempt-id",
  "client_observed_state_version": 1052,
  "user_confirmed_clear_area": true
}
```

Gateway validation: authenticate user and device -> allow role/grant -> reject disabled remote lock/maintenance -> verify live controller heartbeat + feedback + physical interlocks -> enforce anti-replay/rate limits -> issue command **only** via controller's approved interface -> return request id + `accepted` without claiming door is already closed.

Read telemetry with `GET /v1/doors/{doorId}/status` and signed, sensor-derived: `position`, `feedback_at`, `obstruction`, `sensors_healthy`, `physical_stop`, `manual_release`, `remote_locked`, `connection_status`. If values stale or conflicting: block movement and report UNKNOWN/FAULT.

The app's local `SafetyPolicy` is defense-in-depth for UI. All decisions **must be repeated** by the secure gateway and motor controller. An attacker can patch any app or call the API directly.

## 5) Hard requirements before connecting to user's door

- Controller model and photo of its terminal labels/manual (without credentials)
- Roller-door manufacturer, model, supply voltage and existing radio remote behavior
- Whether it supports independent OPEN/CLOSE/STOP or only STEP/TOGGLE; direction cannot be assumed from a single pulse
- Safety edge/photocell/emergency-stop support and site access risks
- Real open/closed position sensor/feedback interface
- Relay/interface and network setup, allowed remote reachability
- Installation and commissioning by suitable electrician/gate specialist

> Status of this package: **demonstration app + a safety engineering spec**, not a certified or live-connected door security system.
