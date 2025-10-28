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

; Immediately run the spindle control algorithm to make sure that we're actually spinning up the spindle
M98 P"arborctl/control-spindle.g" S{param.S}

var maxWait = { (exists(param.M) ? param.M : 30) }
var maxWaitMs = var.maxWait * 1000
var waitIncrementMs = { exists(param.P) ? param.P : 250 }
var startTime = state.upTime * 1000 + state.msUpTime
var endTime = var.startTime + var.maxWaitMs

var spindleStatus = { global.arborVFDStatus[param.S] }

if { global.arborVFDStatus[param.S] == null }
    abort { "ArborCtl: Spindle " ^ param.S ^ " is not managed by ArborCtl!" }

; When a spindle action occurs, the spindle state 'stable'
; flag is set to false as the action starts, and transitions
; back to true when the action completes.
; To wait for the spindle action to complete, we need to wait
; for a full transition from true to false and back to true.

var desiredState = { false }

; Wait for a maximum of maxWaitMs
while { var.endTime > state.upTime * 1000 + state.msUpTime }

    ; Check if spindle state is in desired state
    var wasStable = { global.arborState[param.S][2] }
    var isStable = { global.arborVFDStatus[param.S][4] }

    if { !var.desiredState && !var.isStable }
        set var.desiredState = { true }
        echo { "ArborCtl: Spindle " ^ param.S ^ " is unstable, waiting for action to complete..." }

    ; Spindle state has transitioned to desired state
    if { var.isStable == var.desiredState && var.wasStable != var.desiredState }
        ; If spindle is in desired state and state is true,
        ; the action is complete and we can exit the loop
        if { var.desiredState == true }
            echo { "ArborCtl: Spindle " ^ param.S ^ " is stable, action completed!" }
            M99

        ; Otherwise, the spindle became unstable
        else
            set var.desiredState = { true }
            echo { "ArborCtl: Spindle " ^ param.S ^ " has become unstable, waiting for action to complete..." }

    G4 P{var.waitIncrementMs}

abort { "ArborCtl: Spindle " ^ param.S ^ " did not become stable after " ^ var.maxWait ^ " seconds!" }
