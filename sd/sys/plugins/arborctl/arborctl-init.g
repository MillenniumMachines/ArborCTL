; 0:/sys/plugins/arborctl/arborctl-init.g — NeXT data.nxt init hook for ArborCTL
; RepRapFirmware 3.6+ / 3.7+
;
; Thin one-shot: ensure ArborCTL vars are loaded if config.g has not already
; run arborctl.g. Safe to call when arborctl.g already ran (idempotent guards).

if { !exists(global.arborctlVarsLoaded) }
    if { fileexists("0:/sys/arborctl-vars.g") }
        M98 P"arborctl-vars.g"
        global arborctlVarsLoaded = true
    elif { fileexists("0:/sys/arborctl/arborctl-vars.g") }
        ; Some installs keep vars under arborctl/
        M98 P"arborctl/arborctl-vars.g"
        global arborctlVarsLoaded = true

if { !exists(global.arborctlLdd) }
    global arborctlLdd = false

; Prefer full arborctl.g when present and not yet loaded (loads user vars + gates).
if { !global.arborctlLdd && fileexists("0:/sys/arborctl.g") }
    M98 P"arborctl.g"

echo { "ArborCTL: nxt plugin init ready" }
