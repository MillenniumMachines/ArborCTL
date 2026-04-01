; th-servo/control.g - TH Servo Modbus Implementation
; This file implements specific commands for a TH Servo used as a spindle over RS485 Modbus RTU.

if { !exists(param.A) }
    abort { "ArborCtl: No address specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: No spindle specified!" }

var shouldRun = { (spindles[param.S].state == "forward" || spindles[param.S].state == "reverse") && spindles[param.S].active > 0 }
var wasRunning = { global.arborVFDStatus[param.S] != null ? global.arborVFDStatus[param.S][0] : false }

if { !var.shouldRun && !var.wasRunning }
    ; Spindle should not be running and wasn't running last iteration - skip rest of control
    M99

; Initialize or load internal state
if { global.arborState[param.S][0] == null }
    ; User specified default config for TH Servo: 750W (0.75kW), 220V, 3000 RPM Max
    var motorCfg = { vector(6, 0) }
    set var.motorCfg[0] = 0.75  ; Power in kW
    set var.motorCfg[1] = 8     ; Poles (Placeholder, ignored for speed calculation since servo natively accepts RPM)
    set var.motorCfg[2] = 220   ; Voltage V
    set var.motorCfg[3] = 50    ; Frequency Hz (Placeholder)
    set var.motorCfg[4] = 3.0   ; Current A
    set var.motorCfg[5] = 3000  ; RPM Rated

    ; Speed limits (Min 0, Max 3000 default)
    var spindleLimits = { vector(2, 0) }
    set var.spindleLimits[0] = 3000
    set var.spindleLimits[1] = 0

    ; Frequency Conv (1:1 mapping because servo handles RPM directly)
    var freqConv = { vector(1, 1) }

    set global.arborState[param.S][0] = { var.motorCfg, var.freqConv }
    set global.arborState[param.S][3] = { var.spindleLimits }

    ; Attempt to clear any pending alarms on startup
    ; Write 0x1010 (4112) to 0x1004 (4100)
    M2600 E0 P{param.C} A{param.A} F6 R{4100} B{4112,}
    G4 P{50} ; Allow the drive time to process the alarm clear

; ---------------------------------------------------------------------
; Read Status Registers
; ---------------------------------------------------------------------
; 1. Motor Speed r/min (4096 / 0x1000)
M2601 E0 P{param.C} A{param.A} F3 R{4096} B1
var motorSpeed = { global.arborRetVal }

; 2. Inst Current 0.1A (4107 / 0x100B)
M2601 E0 P{param.C} A{param.A} F3 R{4107} B1
var instCurrentInfo = { global.arborRetVal }
var instCurrent = { var.instCurrentInfo != null ? (var.instCurrentInfo[0] * 0.1) : 0 }

; 3. Speed Command r/min (4110 / 0x100E)
M2601 E0 P{param.C} A{param.A} F3 R{4110} B1
var speedCommandInfo = { global.arborRetVal }
var currentSpeedCommand = { var.speedCommandInfo != null ? var.speedCommandInfo[0] : 0 }

; 4. Average Load Rate % (4120 / 0x1018)
M2601 E0 P{param.C} A{param.A} F3 R{4120} B1
var loadRateInfo = { global.arborRetVal }
var loadRate = { var.loadRateInfo != null ? var.loadRateInfo[0] : 0 }

; 5. Alarm Code (4122 / 0x101A)
M2601 E0 P{param.C} A{param.A} F3 R{4122} B1
var alarmCode = { global.arborRetVal }

; Validate read
if { var.motorSpeed == null || var.alarmCode == null }
    ; Emergency Stop if we lose communication while running
    if { var.wasRunning }
        M2600 E0 P{param.C} A{param.A} F6 R{4112} B{0,} ; Write 0 to 0x1010
    abort { "ArborCtl: Failed to read status from TH Servo!" }

; Parse Alarms
var hasAlarm = { var.alarmCode[0] > 0 }
if { var.hasAlarm }
    echo { "ArborCtl: TH Servo Alarm Code: " ^ var.alarmCode[0] }
    set global.arborState[param.S][4] = true
    if { var.wasRunning }
        M2600 E0 P{param.C} A{param.A} F6 R{4112} B{0,} ; Stop
    M99
else
    set global.arborState[param.S][4] = false

; Calculate Stability (Within 5% of target RPM, or just < 50 RPM absolute diff)
var diff = { abs(var.motorSpeed[0] - var.currentSpeedCommand) }
var isStable = { var.wasRunning && (var.diff < max(50, var.currentSpeedCommand * 0.05)) }

; ---------------------------------------------------------------------
; Action & Motion Control
; ---------------------------------------------------------------------
if { !var.shouldRun && var.wasRunning }
    echo { "ArborCtl: Stopping spindle " ^ param.S }
    M2600 E0 P{param.C} A{param.A} F6 R{4112} B{0,} ; Jog Exit / Disable (Write 0x0000 to 0x1010)
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

    ; Write Speed to P-076 (address 76) if needed
    if { var.currentSpeedCommand != var.targetRPM }
        M2600 E0 P{param.C} A{param.A} F6 R{76} B{var.targetRPM,}
        set global.arborState[param.S][1] = { true }

    ; Write Modbus Forward/Reverse Jog Control Word
    if { !var.wasRunning || var.dirChanged }
        var modeWord = 0
        if { spindles[param.S].state == "forward" }
            set var.modeWord = 8738 ; 0x2222 Jog Forward
        elif { spindles[param.S].state == "reverse" }
            set var.modeWord = 4369 ; 0x1111 Jog Reverse

        M2600 E0 P{param.C} A{param.A} F6 R{4112} B{var.modeWord,}
        set global.arborState[param.S][1] = { true }

; ---------------------------------------------------------------------
; Update Public Status Variables
; ---------------------------------------------------------------------
; Save previous stability flag for stability change detection
set global.arborState[param.S][2] = { global.arborVFDStatus[param.S] != null ? global.arborVFDStatus[param.S][4] : false }

; Set or initialize VFD status array
if { global.arborVFDStatus[param.S] == null }
    set global.arborVFDStatus[param.S] = { vector(5, 0) }

set global.arborVFDStatus[param.S][0] = { var.shouldRun }
set global.arborVFDStatus[param.S][1] = { var.shouldRun ? (spindles[param.S].state == "reverse" ? -1 : 1) : 0 }
set global.arborVFDStatus[param.S][2] = { var.motorSpeed[0] } ; Usually Hz, but for servo RPM is suitable
set global.arborVFDStatus[param.S][3] = { var.motorSpeed[0] }
set global.arborVFDStatus[param.S][4] = { var.isStable }

; Set or initialize VFD power array
if { global.arborVFDPower[param.S] == null }
    set global.arborVFDPower[param.S] = { vector(2, 0) }

; Power in watts approximation (V * I)
var curVoltage = 220 ; Approximate
var pwrWatts = { var.curVoltage * var.instCurrent * 1.732 * 0.8 } ; sqrt(3) & Power factor approx
set global.arborVFDPower[param.S][0] = { var.pwrWatts }
set global.arborVFDPower[param.S][1] = { var.loadRate }
