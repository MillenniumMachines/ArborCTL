; G4.9.g: DWELL FOR SPINDLE ACTION (ArborCTL spindle-delay wait)
; USAGE: G4.9 S<spindle> M<max-wait-seconds> P<wait-increment-ms>
;
; Wait until arborVFDStatus[S][4] (stable) is true, or until max wait.
; This is the VFD ramp / settle wait — not NeXT M3.9 / M5.9 timed dwells.
; Default M: from arborWizardRamp (accel/decel) when set, else 30s.
; After timeout the active job is aborted.

; Spindle actions are executed as part of the daemon loop
; so this command MUST NOT be executed from within that loop.

if { state.thisInput == 9 }
    abort { "ArborCtl: G4.9 cannot be executed from within the daemon loop!" }

if { !exists(param.S) }
    abort { "ArborCtl: No spindle specified!" }

if { param.S < 0 || param.S >= limits.spindles || spindles[param.S] == null || spindles[param.S].state == "unconfigured" }
    abort { "ArborCtl: Spindle ID " ^ param.S ^ " is not valid!" }

; Run control once so setpoint / start commands are issued before we wait
M98 P"arborctl/control-spindle.g" S{param.S}

if { global.arborVFDStatus[param.S] == null }
    abort { "ArborCtl: Spindle " ^ param.S ^ " is not managed by ArborCtl!" }

; Default max wait: wizard ramp + margin, else 30s. Explicit M always wins.
var maxWait = 30
if { exists(param.M) }
    set var.maxWait = { param.M }
elif { exists(global.arborWizardRamp) && global.arborWizardRamp[param.S] != null }
    var rampA = { global.arborWizardRamp[param.S][0] }
    var rampD = { global.arborWizardRamp[param.S][1] }
    var rampSec = { var.rampA }
    if { var.rampD > var.rampSec }
        set var.rampSec = { var.rampD }
    set var.maxWait = { ceil(var.rampSec * 1.25) + 2 }
    if { var.maxWait < 5 }
        set var.maxWait = 5

var maxWaitMs = { var.maxWait * 1000 }
var waitIncrementMs = { exists(param.P) ? param.P : 250 }
var startTime = { state.upTime * 1000 + state.msUpTime }
var endTime = { var.startTime + var.maxWaitMs }

; Already stable and no command change this tick — nothing to wait for
var cmdChange = { global.arborState[param.S][1] }
var isStable = { global.arborVFDStatus[param.S][4] }
if { var.isStable && !var.cmdChange }
    echo { "ArborCtl: Spindle " ^ param.S ^ " already stable" }
    M99

echo { "ArborCtl: Spindle " ^ param.S ^ " waiting for stable (max " ^ var.maxWait ^ "s)" }

while { var.endTime > state.upTime * 1000 + state.msUpTime }
    set var.isStable = { global.arborVFDStatus[param.S][4] }
    if { var.isStable }
        echo { "ArborCtl: Spindle " ^ param.S ^ " is stable, action completed!" }
        M99
    G4 P{var.waitIncrementMs}

abort { "ArborCtl: Spindle " ^ param.S ^ " did not become stable after " ^ var.maxWait ^ " seconds!" }
