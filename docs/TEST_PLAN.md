# Safety acceptance checklist

## Flutter demo test procedures

1. Launch -> `remoteControlLocked=true`, `appUnlocked=false`; OPEN/CLOSE rejected.
2. Unlock via demo button or device auth -> remote lock still ON; commands rejected.
3. Owner disables remote lock -> OPEN accepted when feedback present, online and safe.
4. While opening, send repeated OPEN/CLOSE -> denied. Use REQUEST STOP -> demo stops.
5. If stopped at intermediate position -> subsequent movement blocked until a verified state is obtained.
6. Change role to Viewer -> app auto-locks; after unlock, OPEN/CLOSE denied.
7. Simulate safety sensor unhealthy -> CLOSE denied.
8. Simulate obstruction detected -> CLOSE denied; if closing, simulated movement halts.
9. Simulate physical stop, manual release or maintenance -> motion denied.
10. Disable feedback -> UNKNOWN displayed, all new movement rejected.
11. Simulate offline -> STOP request reports failure; prompt use physical emergency stop.
12. Try CLOSE -> requires explicit checkbox confirmation; cancel sends no request.
13. Use in-app voice "close door" -> same confirmation and policy apply.
14. Add temporary grant, revoke -> screen labels revoked (demo only).
15. App backgrounding -> session locks; 60s inactivity -> locks.
16. Inspect Activity tab -> accepted/denied requests logged in memory.

## Real hardware commissioning (NOT carried out by this package)

Qualified installer must verify the site risk assessment and manufacturer's requirements, including photo-eye, pressure edge, motor force settings, safe reverse, STOP, power failure recovery, manual override, alarm indicators, physical access restriction, tamper resistance, telemetry correctness, remote access latency/offline behavior, individual user revocation and gateway ACL. Test with physical protected fixtures and manufacturer-specific methods. Never perform dangerous obstruction tests with people or animals.

Pass criteria for the future production version: **no single smartphone app failure, network loss, forged API request or gateway software bug can bypass controller safety interlocks.**
