; control-spindle.g - ArborCtl spindle control file
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

var modelFile = { "arborctl/control/" ^ global.arborModelInternalNames[var.spindleModel] ^ ".g" }

if { global.arborSpindleDriverExists[param.S] == null }
    echo { "ArborCtl: Checking for existence of VFD model file for spindle " ^ param.S }
    set global.arborSpindleDriverExists[param.S] = { fileexists("0:/sys/" ^ var.modelFile ) }

if { ! global.arborSpindleDriverExists[param.S] }
    echo { "ArborCtl: VFD model file '0:/sys/" ^ var.modelFile ^ "' not found for spindle " ^ param.S ^ "!" }
    M99

; Run the appropriate VFD control file for the given spindle
M98 P{var.modelFile} S{param.S} C{var.spindleChannel} A{var.spindleAddr}

; Check for unexpected spindle instability
; This happens when:
; 1. The spindle was stable (from last iteration)
; 2. The spindle is now unstable
; 3. No command change was issued
; 4. There's a job running

var vfdRunning    = { global.arborVFDStatus[param.S] != null ? global.arborVFDStatus[param.S][0] : false }
var errorDetected = { global.arborState[param.S][4] }
var wasStable     = { global.arborState[param.S][2] }
var isStable      = { global.arborVFDStatus[param.S] != null ? global.arborVFDStatus[param.S][4] : false }
var commandChange = { global.arborState[param.S][1] }
var jobRunning    = { job.file.fileName != null && !(state.status == "resuming" || state.status == "pausing" || state.status == "paused") }

; Check for unexpected instability
if { (var.wasStable && !var.isStable && !var.commandChange) || var.errorDetected }
    ; Unexpected instability detected - pause job
    echo { "ArborCtl: Spindle " ^ param.S ^ " became unstable!" }
    echo { "ArborCtl: VFD Running=" ^ var.vfdRunning ^ " WasStable=" ^ var.wasStable ^ " IsStable=" ^ var.isStable ^ " CommandChange=" ^ var.commandChange ^ " ErrorDetected=" ^ var.errorDetected }
    if { var.jobRunning }
        echo { "ArborCtl: Pausing job" }
        M25 ; Pause any running job
    
    M99


; Get spindle load if available
var spindleLoad = { global.arborVFDPower[param.S] != null ? global.arborVFDPower[param.S][1] : 0 }

; If spindle is running and stable, check for load
; If load is higher than global.arborMaxLoad, reduce the speed factor
if { var.vfdRunning && var.isStable && var.spindleLoad > global.arborMaxLoad }
    var speedFactor = { move.speedFactor * 0.95 }
    echo { "ArborCtl: Spindle load is " ^ var.spindleLoad ^ "% - reducing feed to " ^ var.speedFactor * 100 ^ "% to counteract" }
    M220 S{var.speedFactor}
