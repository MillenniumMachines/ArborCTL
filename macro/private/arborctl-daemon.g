; arbor-daemon.g - ArborCtl daemon control file
; This file runs the appropriate VFD control file and handles spindle stability monitoring

while { iterations < limits.spindles }
    if { spindles[iterations].state == "unconfigured" }
        continue

    var spindleModel = { global.arborCtlState[iterations][0] }
    var spindleChannel = { global.arborCtlState[iterations][1] }
    var spindleAddr = { global.arborCtlState[iterations][2] }

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

    var vfdRunning    = { global.arborCtlState[iterations][3] }
    var errorDetected = { global.arborCtlState[iterations][5] }
    var wasStable     = { global.arborCtlState[iterations][7] }
    var isStable      = { global.arborCtlState[iterations][6] }
    var commandChange = { global.arborCtlState[iterations][8] }
    var jobRunning    = { job.file.fileName != null && !(state.status == "resuming" || state.status == "pausing" || state.status == "paused") }

    ; Check for unexpected instability
    if { (var.wasStable && !var.isStable && !var.commandChange) || var.errorDetected }
        ; Unexpected instability detected - pause job
        echo { "ArborCtl: Spindle " ^ iterations ^ " became unstable!" }
        if { var.jobRunning }
            echo { "ArborCtl: Pausing job" }
            M25 ; Pause any running job

    var spindleLoad = { global.arborCtlState[iterations][9] }

    ; If spindle is running and stable, check for load
    ; If load is higher than global.arborCtlMaxLoad, reduce the speed
    ; factor by 5% and update the speed.
    if { var.vfdRunning && var.isStable && var.spindleLoad > global.arborCtlMaxLoad }
            var speedFactor = { move.speedFactor * 0.95 }
            echo { "ArborCtl: Spindle load is " ^ var.spindleLoad ^ "% - reducing speed to " ^ var.speedFactor * 100 ^ "%" }
            M220 S{var.speedFactor}