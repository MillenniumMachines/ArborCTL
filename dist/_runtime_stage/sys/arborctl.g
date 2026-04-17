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

if { !exists(global.arborctlErr) }
    global arborctlErr=null
else
    set global.arborctlErr=null

; If user vars file doesn't exist, run configuration wizard
if { !fileexists("0:/sys/arborctl-user-vars.g") }
    echo { "No user configuration file found. Running configuration wizard." }
    G8001
    M99

; Delete extraneous example uservars
if { fileexists("0:/sys/arborctl-user-vars.g.example") }
    M472 P{"0:/sys/arborctl-user-vars.g.example" }

; Load user vars
if { fileexists("0:/sys/arborctl-user-vars.g") }
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

    ; Re-enable comms gate at startup for configured spindles.
    ; Without this, commReady stays false after reboot until G8001 is rerun.
    if { exists(global.arborVFDCommReady) }
        set global.arborVFDCommReady[iterations] = true
    if { exists(global.arborVFDCommFaultLatched) }
        set global.arborVFDCommFaultLatched[iterations] = false

; Allow ArborCtl macros to run.
set global.arborctlLdd = true

echo { "ArborCtl: Loaded " ^ global.arborctlVer }