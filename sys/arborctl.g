; arborctl.g
;
; ArborCTL entrypoint.
;
; This file can be included at the end of RRF's config.g file using
; M98 P"arborctl.g"

; ArborCTL Release version
if { exists(global.arborctlVer) }
    set global.arborctlVer = { "%%ARBORCTL_VERSION%%" }
else
    global arborctlVer = { "%%ARBORCTL_VERSION%%" }

; Load internal / default variables
if { !exists(global.arborctlVarsLoaded) }
    M98 P"arborctl-vars.g"
    global arborctlVarsLoaded=true

if { !exists(global.arborctlLdd) }
    global arborctlLdd=false
else
    set global.arborctlLdd=false

; If user vars file doesn't exist, ask the user to configure via DWC plugin and stop loading
if { !fileexists("0:/sys/arborctl-user-vars.g") }
    echo { "ArborCtl: No user configuration found. Open the ArborCTL DWC plugin to configure your spindle, then reset." }
    M99

; Delete extraneous example uservars
if { fileexists("0:/sys/arborctl-user-vars.g.example") }
    M472 P{"0:/sys/arborctl-user-vars.g.example" }

; Load user vars
M98 P"arborctl-user-vars.g"

; Verify each ArborCtl configured spindle is a valid RRF Spindle
while { iterations < #global.arborVFDConfig }
    if { global.arborVFDConfig[iterations] == null }
        ; Keep comm gate closed for unconfigured spindle slots.
        if { exists(global.arborVFDCommReady) }
            set global.arborVFDCommReady[iterations] = false
        continue

    if { spindles[iterations].state == "unconfigured" }
        abort { "ArborCtl: Spindle " ^ iterations ^ " is configured in ArborCtl but unconfigured in RRF!" }

    ; Re-enable comm gate at startup for configured spindles.
    ; Without this, commReady stays false after reboot.
    if { exists(global.arborVFDCommReady) }
        set global.arborVFDCommReady[iterations] = true

; Allow ArborCtl macros to run.
set global.arborctlLdd = true

echo { "ArborCtl: Loaded " ^ global.arborctlVer }