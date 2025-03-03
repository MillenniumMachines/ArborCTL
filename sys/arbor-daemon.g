; arbor-daemon.g - ArborCtl daemon control file
; This file runs the appropriate VFD control file and handles spindle stability monitoring

; Check for VFD model
if { !exists(global.arborCtlModel) || global.arborCtlModel == null }
    abort { "ArborCtl: No VFD model specified!" }

var modelFile = {"control/" ^ global.arborCtlModel ^ ".g" }

if { !fileexists("0:/sys/arborctl/" ^ var.modelFile) }
    abort { "ArborCtl: VFD model file not found!" }

; Run the appropriate VFD control file
M98 P{var.modelFile}

; Check for unexpected spindle instability
; This happens when:
; 1. The spindle was stable (from last iteration)
; 2. The spindle is now unstable
; 3. No command change was issued
; 4. There's a job running

var vfdRunning    = { global.arborCtlState[param.S][0] }
var wasStable     = { global.arborCtlState[param.S][3] }
var isStable      = { global.arborCtlState[param.S][2] }
var commandChange = { global.arborCtlState[param.S][4] }
var freqVariance  = { abs(global.arborCtlState[param.S][5] - global.arborCtlState[param.S][6]) }
var jobRunning    = { job.file.fileName != null && !(state.status == "resuming" || state.status == "pausing" || state.status == "paused") }

; Check for unexpected instability
if { var.wasStable && !var.isStable && !var.commandChange && var.jobRunning }
    ; Unexpected instability detected - pause job
    echo { "ArborCtl: Spindle became unstable - job paused for safety!" }
    M25 ; Pause any running job

var spindleLoad = { global.arborCtlState[param.S][5] }

; If spindle is running and stable, check for load
if { var.vfdRunning && var.isStable && var.spindleLoad > global.arborCtlMaxLoad }
        var speedFactor = { move.speedFactor * 0.95 }
        echo { "ArborCtl: Spindle load is " ^ var.spindleLoad ^ "% - reducing speed to " ^ var.speedFactor * 100 ^ "%" }
        M220 S{var.speedFactor}