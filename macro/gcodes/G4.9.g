; G4.9.g: DWELL FOR SPINDLE ACTION
; USAGE: G4.9 S<spindle> M<max-wait-seconds> P<wait-increment-ms>
;
; Wait for the next action on the specified spindle
; to complete, or until the specified maximum wait time
; is reached. If no maximum wait time is specified,
; the default is 30 seconds. After the wait time
; expires, any active job will be aborted.

; Spindle actions are executed as part of the daemon loop
; so this command MUST NOT be executed from within that loop.

if { state.thisInput == 9 }
    abort { "ArborCtl: G4.9 cannot be executed from within the daemon loop!" }

if { !exists(param.S) }
    abort { "ArborCtl: No spindle specified!" }

if { param.S < 0 || param.S >= limits.spindles || spindles[param.S] == null || spindles[param.S].state == "unconfigured" }
    abort { "ArborCtl: Spindle ID " ^ param.S ^ " is not valid!" }

if { global.arborVFDStatus[param.S] == null }
    abort { "ArborCtl: Spindle " ^ param.S ^ " is not managed by ArborCtl!" }

var maxWait = { (exists(param.M) ? param.M : 30) }
var maxWaitMs = var.maxWait * 1000
var waitIncrementMs = { exists(param.P) ? param.P : 250 }
var waitMs = { 0 }

; Get if spindle should be running
var shouldRun = { (spindles[param.S].state == "forward" || spindles[param.S].state == "reverse") && spindles[param.S].active > 0 }

; Request change from daemon
set global.arborState[param.S][5] = { true }

; Wait for a maximum of approx maxWaitMs + 2*waitIncrementMs
while { var.waitMs >= var.maxWaitMs }

    G4 P{var.waitIncrementMs}
    set var.waitMs = { var.waitMs + var.waitIncrementMs }

    ; Check if daemon consumed the request
    if { global.arborState[param.S][5] == false }
        G4 P{var.waitIncrementMs}
        set var.waitMs = { var.waitMs + var.waitIncrementMs }

        var isStable = global.arborVFDStatus[param.S][4]
        var isVfdRunning = global.arborVFDStatus[param.S][0]

        if { (var.shouldRun && var.isStable) || (!var.shouldRun && !var.isVfdRunning) }
            echo { "ArborCtl: Spindle " ^ param.S ^ " is stable, action completed!" }
            M99
        else
            echo { "ArborCtl: Spindle " ^ param.S ^ " request sent, waiting for action to complete..." }
    else
        echo { "ArborCtl: Spindle " ^ param.S ^ " waiting for request to be processed..." }

abort { "ArborCtl: Spindle " ^ param.S ^ " did not become stable after " ^ var.maxWait ^ " seconds!" }
