; apply-sys-gcodes.g — Apply pending 0:/sys/*.install numbered metas
;
; Plugin ZIP ships M2600.install / M2601.install / M2604.install / G4.9.install
; so DSF upgrades do not delete live files the daemon may have open.
; Call at boot from arborctl.g, or from prepare-plugin-update.g S1 (paused).

if { fileexists("0:/sys/M2600.install") }
    if { fileexists("0:/sys/M2600.g.old") }
        M472 P{"0:/sys/M2600.g.old"}
    if { fileexists("0:/sys/M2600.g") }
        M471 S{"0:/sys/M2600.g"} T{"0:/sys/M2600.g.old"}
    M471 S{"0:/sys/M2600.install"} T{"0:/sys/M2600.g"}

if { fileexists("0:/sys/M2601.install") }
    if { fileexists("0:/sys/M2601.g.old") }
        M472 P{"0:/sys/M2601.g.old"}
    if { fileexists("0:/sys/M2601.g") }
        M471 S{"0:/sys/M2601.g"} T{"0:/sys/M2601.g.old"}
    M471 S{"0:/sys/M2601.install"} T{"0:/sys/M2601.g"}

if { fileexists("0:/sys/M2604.install") }
    if { fileexists("0:/sys/M2604.g.old") }
        M472 P{"0:/sys/M2604.g.old"}
    if { fileexists("0:/sys/M2604.g") }
        M471 S{"0:/sys/M2604.g"} T{"0:/sys/M2604.g.old"}
    M471 S{"0:/sys/M2604.install"} T{"0:/sys/M2604.g"}

if { fileexists("0:/sys/G4.9.install") }
    if { fileexists("0:/sys/G4.9.g.old") }
        M472 P{"0:/sys/G4.9.g.old"}
    if { fileexists("0:/sys/G4.9.g") }
        M471 S{"0:/sys/G4.9.g"} T{"0:/sys/G4.9.g.old"}
    M471 S{"0:/sys/G4.9.install"} T{"0:/sys/G4.9.g"}
