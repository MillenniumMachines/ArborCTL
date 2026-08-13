; prepare-plugin-update.g — Pause / resume ArborCTL daemon for plugin ZIP update
;
; USAGE:
;   M98 P"arborctl/prepare-plugin-update.g"       Pause, wait 5s, leave paused
;   M98 P"arborctl/prepare-plugin-update.g" S1    Apply *.install, then resume
;
; Pause before DWC Settings → Plugins install/upgrade so DSF can delete
; numbered metas (M2604.g) that Huanyang polling keeps open.

var arborResume = false
if { exists(param.S) && param.S == 1 }
    set var.arborResume = true

if { var.arborResume }
    if { fileexists("0:/sys/arborctl/apply-sys-gcodes.g") }
        M98 P"arborctl/apply-sys-gcodes.g"
    if { exists(global.arborctlDaemonEnabled) }
        set global.arborctlDaemonEnabled = true
    else
        global arborctlDaemonEnabled = true
    echo { "ArborCtl: daemon resumed (S1)" }
    M99

if { exists(global.arborctlDaemonEnabled) }
    set global.arborctlDaemonEnabled = false
else
    global arborctlDaemonEnabled = false

; Huanyang ticks hold M2604.g for several 250ms delays; wait out one tick.
G4 P5000

echo { "ArborCtl: daemon paused — safe to install/update the plugin ZIP" }
echo { "ArborCtl: after update, reboot or resume this macro with S1" }
