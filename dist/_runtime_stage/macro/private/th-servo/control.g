; th-servo/control.g - TH Servo Modbus (preliminary; see PR #17)
; RS485 Modbus RTU — merged from jayem1427/feature/th-servo-support.

if { !exists(param.A) }
    abort { "ArborCtl: TH Servo - No address specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: TH Servo - No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: TH Servo - No spindle specified!" }

var shouldRun = { (spindles[param.S].state == "forward" || spindles[param.S].state == "reverse") && spindles[param.S].active > 0 }
var wasRunning = { global.arborVFDStatus[param.S] != null ? global.arborVFDStatus[param.S][0] : false }

if { !var.shouldRun && !var.wasRunning }
    ; Spindle should not be running and wasn't running last iteration - skip rest of control
    M99

; Initialize or load internal state
if { global.arborState[param.S][0] == null }
    if { exists(global.arborMotorSpec) && global.arborMotorSpec[param.S] != null }
        var wms = global.arborMotorSpec[param.S]
        var motorCfg = { vector(6, 0) }
        set var.motorCfg[0] = var.wms[0]
        set var.motorCfg[1] = var.wms[1]
        set var.motorCfg[2] = var.wms[2]
        set var.motorCfg[3] = var.wms[3]
        set var.motorCfg[4] = var.wms[4]
        set var.motorCfg[5] = var.wms[5]
        var smax = { spindles[param.S].max != null ? spindles[param.S].max : var.wms[5] }
        var smin = { spindles[param.S].min != null ? spindles[param.S].min : 0 }
        var spindleLimits = { vector(2, 0) }
        set var.spindleLimits[0] = { min(var.wms[5], var.smax) }
        set var.spindleLimits[1] = { var.smin }
        var freqConv = { vector(1, 1.0) }
        set global.arborState[param.S][0] = { var.motorCfg, var.freqConv }
        set global.arborState[param.S][3] = { var.spindleLimits }
        echo { "ArborCtl: TH Servo (preliminary) motor data from wizard." }
    else
        ; Default: 750W, 220V, 3000 RPM rated (matches upstream PR #17)
        var motorCfg = { vector(6, 0) }
        set var.motorCfg[0] = 0.75
        set var.motorCfg[1] = 8
        set var.motorCfg[2] = 220
        set var.motorCfg[3] = 50
        set var.motorCfg[4] = 3.0
        set var.motorCfg[5] = 3000
        var spindleLimits = { vector(2, 0) }
        set var.spindleLimits[0] = 3000
        set var.spindleLimits[1] = 0
        var freqConv = { vector(1, 1) }
        set global.arborState[param.S][0] = { var.motorCfg, var.freqConv }
        set global.arborState[param.S][3] = { var.spindleLimits }

    ; Clear pending alarms: write 4112 to register 4100 (per PR #17)
    M98 P"arborctl/delay-for-command.g"
    M2600 E0 P{param.C} A{param.A} F6 R{4100} B{4112,}
    G4 P{50}

; ---------------------------------------------------------------------
; Read status registers
; ---------------------------------------------------------------------
M98 P"arborctl/delay-for-command.g"
M2601 E0 P{param.C} A{param.A} F3 R{4096} B1
var motorSpeed = { global.arborRetVal }

M98 P"arborctl/delay-for-command.g"
M2601 E0 P{param.C} A{param.A} F3 R{4107} B1
var instCurrentInfo = { global.arborRetVal }
var instCurrent = { var.instCurrentInfo != null ? (var.instCurrentInfo[0] * 0.1) : 0 }

M98 P"arborctl/delay-for-command.g"
M2601 E0 P{param.C} A{param.A} F3 R{4110} B1
var speedCommandInfo = { global.arborRetVal }
var currentSpeedCommand = { var.speedCommandInfo != null ? var.speedCommandInfo[0] : 0 }

M98 P"arborctl/delay-for-command.g"
M2601 E0 P{param.C} A{param.A} F3 R{4120} B1
var loadRateInfo = { global.arborRetVal }
var loadRate = { var.loadRateInfo != null ? var.loadRateInfo[0] : 0 }

M98 P"arborctl/delay-for-command.g"
M2601 E0 P{param.C} A{param.A} F3 R{4122} B1
var alarmCode = { global.arborRetVal }

if { var.motorSpeed == null || var.alarmCode == null }
    if { var.wasRunning }
        M98 P"arborctl/delay-for-command.g"
        M2600 E0 P{param.C} A{param.A} F6 R{4112} B{0,}
        abort { "ArborCtl: Failed to read status from TH Servo!" }

var hasAlarm = { var.alarmCode[0] > 0 }
if { var.hasAlarm }
    echo { "ArborCtl: TH Servo Alarm Code: " ^ var.alarmCode[0] }
    set global.arborState[param.S][4] = true
    if { var.wasRunning }
        M98 P"arborctl/delay-for-command.g"
        M2600 E0 P{param.C} A{param.A} F6 R{4112} B{0,}
    M99
else
    set global.arborState[param.S][4] = false

var diff = { abs(var.motorSpeed[0] - var.currentSpeedCommand) }
var isStable = { var.wasRunning && (var.diff < max(50, var.currentSpeedCommand * 0.05)) }

; ---------------------------------------------------------------------
; Action & motion
; ---------------------------------------------------------------------
if { !var.shouldRun && var.wasRunning }
    echo { "ArborCtl: Stopping spindle " ^ param.S }
    M98 P"arborctl/delay-for-command.g"
    M2600 E0 P{param.C} A{param.A} F6 R{4112} B{0,}
    set global.arborState[param.S][1] = { true }

elif { var.shouldRun }
    var maxRPM = { global.arborState[param.S][3][0] }
    var minRPM = { global.arborState[param.S][3][1] }
    var targetRPM = { floor(min(var.maxRPM, max(var.minRPM, abs(spindles[param.S].current)))) }

    var dirChanged = false
    if { var.wasRunning }
        var wasForward = { global.arborVFDStatus[param.S][1] == 1 }
        var wasReverse = { global.arborVFDStatus[param.S][1] == -1 }
        if { (spindles[param.S].state == "forward" && !var.wasForward) || (spindles[param.S].state == "reverse" && !var.wasReverse) }
            set var.dirChanged = true

    if { var.currentSpeedCommand != var.targetRPM }
        M98 P"arborctl/delay-for-command.g"
        M2600 E0 P{param.C} A{param.A} F6 R{76} B{var.targetRPM,}
        set global.arborState[param.S][1] = { true }

    if { !var.wasRunning || var.dirChanged }
        var modeWord = 0
        if { spindles[param.S].state == "forward" }
            set var.modeWord = 8738
        elif { spindles[param.S].state == "reverse" }
            set var.modeWord = 4369

        M98 P"arborctl/delay-for-command.g"
        M2600 E0 P{param.C} A{param.A} F6 R{4112} B{var.modeWord,}
        set global.arborState[param.S][1] = { true }

; ---------------------------------------------------------------------
; Object model
; ---------------------------------------------------------------------
set global.arborState[param.S][2] = { global.arborVFDStatus[param.S] != null ? global.arborVFDStatus[param.S][4] : false }

if { global.arborVFDStatus[param.S] == null }
    set global.arborVFDStatus[param.S] = { vector(5, 0) }

set global.arborVFDStatus[param.S][0] = { var.shouldRun }
set global.arborVFDStatus[param.S][1] = { var.shouldRun ? (spindles[param.S].state == "reverse" ? -1 : 1) : 0 }
set global.arborVFDStatus[param.S][2] = { var.motorSpeed[0] }
set global.arborVFDStatus[param.S][3] = { var.motorSpeed[0] }
set global.arborVFDStatus[param.S][4] = { var.isStable }

if { global.arborVFDPower[param.S] == null }
    set global.arborVFDPower[param.S] = { vector(2, 0) }

var curVoltage = 220
var pwrWatts = { var.curVoltage * var.instCurrent * 1.732 * 0.8 }
set global.arborVFDPower[param.S][0] = { var.pwrWatts }
set global.arborVFDPower[param.S][1] = { var.loadRate }
