; shihlin-sl3.g - Shihlin SL3 VFD implementation
; This file implements specific commands for the Shihlin SL3 VFD

if { !exists(param.A) }
    abort { "ArborCtl: No address specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: No spindle specified!" }

var cmdWait      = 10
var motorAddr    = 10501
var limitsAddr   = 10100
var freqConvAddr = 10008
var statusAddr   = 4097
var freqAddr     = 4098
var powerAddr    = 4123
var errorAddr    = 4103

; Gather Motor Configuration from VFD if not already loaded
if { global.arborCtlState[param.S][11] == null }
    ; 0 = Motor Rated Power, 1 = Motor Poles, 2 = Motor Rated Voltage,
    ; 3 = Motor Rated Frequency, 4 = Motor Rated Current, 5 = Motor Rotation Speed
    M261.1 P{param.C} A{param.A} F3 R{var.motorAddr} B6 V"motorCfg"

    G4 P{var.cmdWait}

    ; 0 = Max Frequency, 1 = Min Frequency
    M261.1 P{param.C} A{param.A} F3 R{var.limitsAddr} B2 V"spindleLimits"

    G4 P{var.cmdWait}

    ; 0 = Frequency Conversion Factor
    M261.1 P{param.C} A{param.A} F3 R{var.freqConvAddr} B1 V"freqConv"

    set var.motorCfg[0] = { var.motorCfg[0] * 10 }
    set var.motorCfg[3] = { var.motorCfg[3] / 100 }
    set var.motorCfg[4] = { var.motorCfg[4] / 100 }
    set var.motorCfg[5] = { var.motorCfg[5] * 10 }
    set var.spindleLimits[0] = { var.spindleLimits[0] / 100 }
    set var.spindleLimits[1] = { var.spindleLimits[1] / 100 }
    set var.freqConv[0] = { var.freqConv[0] / 60 }

    echo { "Shihlin SL3 Configuration: "}
    echo { "  Power=" ^ var.motorCfg[0] ^ "W, Poles=" ^ var.motorCfg[1] ^ ", Voltage=" ^ var.motorCfg[2] ^ "V" }
    echo { "  Frequency=" ^ var.motorCfg[3] ^ "Hz, Current=" ^ var.motorCfg[4] ^ "A, Speed=" ^ var.motorCfg[5] ^ "RPM" }
    echo { "  Max Speed=" ^ var.spindleLimits[0] ^ ", Min Speed=" ^ var.spindleLimits[1] ^ " Conversion=" ^ var.freqConv[0] }

    set global.arborCtlState[param.S][11] = { var.motorCfg, var.spindleLimits, var.freqConv }

var shouldRun = { (spindles[param.S].state == "forward" || spindles[param.S].state == "reverse") && spindles[param.S].active > 0 }

; Read status bits, frequency, output data
; 0 = Status, 1 = Req Freq, 2 = Output Freq, 3 = Output Current,
; 4 = Output Voltage, 5 = Error 1, 6 = Error 2
M261.1 P{param.C} A{param.A} F3 R{var.statusAddr} B7 V"spindleState"

G4 P{var.cmdWait}

; Read output power
M261.1 P{param.C} A{param.A} F3 R{var.powerAddr} B1 V"spindlePower"

G4 P{var.cmdWait}

; Make sure we have all the data we need.
; If we do not have spindle state or errors, we are in
; an unknown state and should stop the spindle immediately.
if { var.spindleState == null }
    M260.1 P{param.C} A{param.A} F6 R{var.statusAddr} B0
    G4 P{var.cmdWait}
    M260.1 P{param.C} A{param.A} F6 R{var.freqAddr} B0
    G4 P{var.cmdWait}
    M5
    abort { "ArborCtl: Failed to read spindle state!" }

if { var.spindleState[5] > 0 }
    echo { "ArborCtl: VFD Error detected. Code=" ^ var.spindleState[5] }
    M99

; spindleState[0] is a bitmask of the following values:
; b15:during tuning
; b14: during inverter reset
; b13, b12: Reserved
; b11: inverter E0 status
; b10~8: Reserved
; b7:alarm occurred
; b6:frequency detect
; b5:Parameters reset end
; b4: overload
; b3: frequency arrive
; b2: during reverse rotation
; b1: during forward rotation
; b0: running

; Extract status bits from spindleState
var vfdRunning      = { mod(var.spindleState[0], 2) > 0 }
var vfdForward      = { mod(floor(var.spindleState[0] / 2), 2) > 0 }
var vfdReverse      = { mod(floor(var.spindleState[0] / 4), 2) > 0 }
var vfdSpeedReached = { mod(floor(var.spindleState[0] / 8), 2) > 0 }
var vfdInputFreq    = { var.spindleState[1] }

; echo { "ArborCtl: Spindle " ^ param.S ^ " running=" ^ var.vfdRunning ^ ", forward=" ^ var.vfdForward ^ ", reverse=" ^ var.vfdReverse ^ ", speedReached=" ^ var.vfdSpeedReached ^ ", inputFreq=" ^ var.vfdInputFreq }
if { var.spindlePower == null }
    set var.spindlePower = { var.spindleState[3] * var.spindleState[4] }
else
    set var.spindlePower = { var.spindlePower[0] * 10 }

; Check for invalid spindle state and call emergency stop on the VFD
if { (var.vfdRunning && !var.vfdForward && !var.vfdReverse) || (!var.vfdRunning && (var.vfdForward || var.vfdReverse)) }
    M260.1 P{param.C} A{param.A} F6 R{var.statusAddr} B128
    G4 P{var.cmdWait}
    echo { "ArborCtl: Invalid spindle state detected - emergency VFD stop issued!" }
    M112

var commandChange = false

; Stop spindle as early as possible if it should not be running
if { !var.shouldRun && var.vfdRunning }
    echo { "ArborCtl: Stopping spindle " ^ param.S }
    ; Stop spindle, set frequency to 0
    M260.1 P{param.C} A{param.A} F6 R{var.statusAddr} B0
    G4 P{var.cmdWait}
    M260.1 P{param.C} A{param.A} F6 R{var.freqAddr} B0
    G4 P{var.cmdWait}

    set var.commandChange = true

else
    ; Calculate the frequency to set based on the rpm requested,
    ; the max and min frequencies, the number of poles
    ; and the conversion factor.
    var numPoles   = { global.arborCtlState[param.S][11][0][1] }
    var convFactor = { global.arborCtlState[param.S][11][2][0] }
    var maxFreq    = { global.arborCtlState[param.S][11][1][0] }
    var minFreq    = { global.arborCtlState[param.S][11][1][1] }

    ; RPM = 120 x f / poles.
    ; f = RPM x poles / 120
    ; Adjust for the conversion factor and divide by
    ; 60 to normalise to Hz.

    ; Clamp the frequency to the limits
    var newFreq = { min(var.maxFreq,max(var.minFreq,(spindles[param.S].active * var.numPoles) / 120)) }

    ; Adjust for the conversion factor
    set var.newFreq = { ceil(var.newFreq * var.convFactor) }

    ; Set input frequency if it doesn't match the RRF value
    if { var.vfdInputFreq != var.newFreq }
        echo { "ArborCtl: Setting spindle " ^ param.S ^ " frequency to " ^ var.newFreq }
        M260.1 P{param.C} A{param.A} F6 R{var.freqAddr} B{var.newFreq}
        G4 P{var.cmdWait}
        set var.commandChange = true

    ; Set spindle direction forward if it is not running forward
    if { spindles[0].state == "forward" && !var.vfdForward }
        echo { "ArborCtl: Setting spindle " ^ param.S ^ " direction to forward" }
        M260.1 P{param.C} A{param.A} F6 R{var.statusAddr} B2
        set var.commandChange = true

    ; Set spindle direction reverse if it is not running in reverse
    elif { spindles[0].state == "reverse" && !var.vfdReverse }
        echo { "ArborCtl: Setting spindle " ^ param.S ^ " direction to reverse" }
        M260.1 P{param.C} A{param.A} F6 R{var.statusAddr} B4
        set var.commandChange = true

; Update global state
set global.arborCtlState[param.S][3] = { var.vfdRunning }
set global.arborCtlState[param.S][4] = { var.vfdRunning && var.vfdReverse }

; Update old stable value
set global.arborCtlState[param.S][7] = { global.arborCtlState[param.S][5] }

; Write new stable value
set global.arborCtlState[param.S][6] = { var.vfdRunning && var.vfdSpeedReached }

set global.arborCtlState[param.S][8] = { var.commandChange }

; Set model-specific data
set global.arborCtlState[param.S][10] = { var.spindleState, var.spindlePower }

; Update spindle load
; Spindle load is calculated as the current power divided by the rated power
set global.arborCtlState[param.S][9] = { var.spindlePower / global.arborCtlState[param.S][11][0][0] }
