; arbor-daemon.g - ArborCtl daemon control file
; This file runs the appropriate VFD control file and handles spindle stability monitoring

while { iterations < limits.spindles }
    if { spindles[iterations].state == "unconfigured" }
        continue

    ; Ensure VFD is configured for this spindle
    if { global.arborVFDConfig[iterations] == null }
        continue

    var spindleModel   = { global.arborVFDConfig[iterations][0] }
    var spindleChannel = { global.arborVFDConfig[iterations][1] }
    var spindleAddr    = { global.arborVFDConfig[iterations][2] }

    if { var.spindleModel == null || var.spindleChannel == null || var.spindleAddr == null }
        continue

    var modelFile = { "arborctl/control/" ^ var.spindleModel ^ ".g" }

    if { !fileexists("0:/sys/" ^ var.modelFile ) }
        echo { "ArborCtl: VFD model file not found for spindle " ^ iterations ^ "!" }
        continue

    ; Run the appropriate VFD control file for the given spindle
    M98 P{var.modelFile} S{iterations} C{var.spindleChannel} A{var.spindleAddr}

    ; Check for unexpected spindle instability
    ; This happens when:
    ; 1. The spindle was stable (from last iteration)
    ; 2. The spindle is now unstable
    ; 3. No command change was issued
    ; 4. There's a job running

    var vfdRunning    = { global.arborVFDStatus[iterations] != null ? global.arborVFDStatus[iterations][0] : false }
    var errorDetected = { global.arborState[iterations][4] }
    var wasStable     = { global.arborState[iterations][2] }
    var isStable      = { global.arborVFDStatus[iterations] != null ? global.arborVFDStatus[iterations][4] : false }
    var commandChange = { global.arborState[iterations][1] }
    var jobRunning    = { job.file.fileName != null && !(state.status == "resuming" || state.status == "pausing" || state.status == "paused") }

    ; Check for unexpected instability
    if { (var.wasStable && !var.isStable && !var.commandChange) || var.errorDetected }
        ; Unexpected instability detected - pause job
        echo { "ArborCtl: Spindle " ^ iterations ^ " became unstable!" }
        if { var.jobRunning }
            echo { "ArborCtl: Pausing job" }
            M25 ; Pause any running job

    ; Get spindle load if available
    var spindleLoad = { global.arborVFDPower[iterations] != null ? global.arborVFDPower[iterations][1] : 0 }

    ; If spindle is running and stable, check for load
    ; If load is higher than global.arborMaxLoad, reduce the speed factor
    if { var.vfdRunning && var.isStable && var.spindleLoad > global.arborMaxLoad }
        var speedFactor = { move.speedFactor * 0.95 }
        echo { "ArborCtl: Spindle load is " ^ var.spindleLoad ^ "% - reducing feed to " ^ var.speedFactor * 100 ^ "% to counteract" }
        M220 S{var.speedFactor}