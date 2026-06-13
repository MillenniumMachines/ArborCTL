; restart-spindle.g - ArborCtl spindle direct restart file
; This file runs the appropriate VFD control file and handles spindle stability monitoring for one spindle.

if { !exists(param.S) || param.S < 0 || param.S >= limits.spindles | spindles[param.S] == null || spindles[param.S].state == "unconfigured" }
    echo "ArborCtl: No spindle specified."
    M99

if { !exists(global.arborctlLdd) || !global.arborctlLdd || !exists(global.arborVFDConfig) || global.arborVFDConfig == null }
    echo "ArborCtl: Invalid state"
    M99

; Ensure VFD is configured for this spindle
if { global.arborVFDConfig[param.S] == null }
    echo "ArborCtl: No spindle set up."
    M99

var spindleModel   = { global.arborVFDConfig[param.S][0] }
var spindleChannel = { global.arborVFDConfig[param.S][1] }
var spindleAddr    = { global.arborVFDConfig[param.S][2] }

if { var.spindleModel == null || var.spindleChannel == null || var.spindleAddr == null }
    M99

var modelFile = { "arborctl/" ^ global.arborModelInternalNames[var.spindleModel] ^ "/restart.g" }

if { global.arborSpindleDriverExists[param.S] == null }
    echo { "ArborCtl: Checking for existence of VFD model file for spindle " ^ param.S }
    set global.arborSpindleDriverExists[param.S] = { fileexists("0:/sys/" ^ var.modelFile ) }

if { ! global.arborSpindleDriverExists[param.S] }
    echo { "ArborCtl: VFD model file '0:/sys/" ^ var.modelFile ^ "' not found for spindle " ^ param.S ^ "!" }
    M99

; Run the appropriate VFD control file for the given spindle
M98 P{var.modelFile} S{param.S} C{var.spindleChannel} A{var.spindleAddr}
echo { "ArborCtl: Restart command send to spindle" ^ param.S }
