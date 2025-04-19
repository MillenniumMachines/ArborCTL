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
if { global.arborState[param.S][0] == null }
    ; 0 = Motor Rated Power, 1 = Motor Poles, 2 = Motor Rated Voltage,
    ; 3 = Motor Rated Frequency, 4 = Motor Rated Current, 5 = Motor Rotation Speed
    M261.1 P{param.C} A{param.A} F3 R{var.motorAddr} B6 V"motorCfg"
    G4 P{var.cmdWait}

    ; 0 = Max Frequency, 1 = Min Frequency
    M261.1 P{param.C} A{param.A} F3 R{var.limitsAddr} B2 V"spindleLimits"
    G4 P{var.cmdWait}

    ; 0 = Frequency Conversion Factor
    M261.1 P{param.C} A{param.A} F3 R{var.freqConvAddr} B1 V"freqConv"
    G4 P{var.cmdWait}

    if { var.motorCfg == null || var.spindleLimits == null || var.freqConv == null }
        echo { "Unable to load necessary data from VFD for spindle control!"}
        M99

    set var.motorCfg[0]      = { var.motorCfg[0] * 10 * 0.75 } ; Cos phi = 0.75
    set var.motorCfg[3]      = { var.motorCfg[3] / 100 }
    set var.motorCfg[4]      = { var.motorCfg[4] / 100 }
    set var.motorCfg[5]      = { var.motorCfg[5] * 10 }
    set var.spindleLimits[0] = { ceil(var.spindleLimits[0] / 100) }
    set var.spindleLimits[1] = { floor(var.spindleLimits[1] / 100) }

    ; Handle the case when frequency conversion factor is 0 or null
    if { var.freqConv == null || var.freqConv[0] == 0 }
        echo { "ArborCtl: No frequency conversion factor detected, using default 1:1 mapping" }
        set var.freqConv = { vector(1, 1) }
    else
        set var.freqConv[0] = { var.freqConv[0] / 60 }

    echo { "ArborCTL Shihlin SL3 Configuration: "}
    echo { "  Power=" ^ var.motorCfg[0] ^ "W, Poles=" ^ var.motorCfg[1] ^ ", Voltage=" ^ var.motorCfg[2] ^ "V" }
    echo { "  Frequency=" ^ var.motorCfg[3] ^ "Hz, Current=" ^ var.motorCfg[4] ^ "A, Speed=" ^ var.motorCfg[5] ^ "RPM" }
    echo { "  Max Speed=" ^ var.spindleLimits[0] ^ ", Min Speed=" ^ var.spindleLimits[1] ^ " SpeedFactor=" ^ var.freqConv[0] }

    ; Store VFD-specific configuration in internal state
    set global.arborState[param.S][0] = { var.motorCfg, var.freqConv }
    set global.arborState[param.S][3] = { var.spindleLimits }

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
if { var.spindleState == null }
    M260.1 P{param.C} A{param.A} F6 R{var.statusAddr} B0
    G4 P{var.cmdWait}
    M260.1 P{param.C} A{param.A} F6 R{var.freqAddr} B0
    G4 P{var.cmdWait}
    M5
    abort { "ArborCtl: Failed to read spindle state!" }

; Check if VFD is in emergency stop
if { var.spindleState[0] == 128 }
    echo { "ArborCtl: VFD in emergency stop!" }
    set global.arborState[param.S][4] = true
    M99

; Check for VFD errors
if { var.spindleState[5] > 0 }
    echo { "ArborCtl: VFD Error detected. Code=" ^ var.spindleState[5] }
    set global.arborState[param.S][4] = true
    M99

; Extract status bits from spindleState using modulo and division
; Bit 0: Running (0=stopped, 1=running)
; Bit 1: Forward (1=forward)
; Bit 2: Reverse (1=reverse)
; Bit 3: Speed reached (0=not reached, 1=reached)
var vfdRunning = { mod(var.spindleState[0], 2) == 1 }
var vfdForward = { mod(floor(var.spindleState[0] / 2), 2) == 1 }
var vfdReverse = { mod(floor(var.spindleState[0] / 4), 2) == 1 }
var vfdSpeedReached = { mod(floor(var.spindleState[0] / 8), 2) == 1 }
var vfdInputFreq = { var.spindleState[1] }
var vfdOutputFreq = { var.spindleState[2] }

; Calculate power consumption
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
    ; Stop spindle - Command 0 = Stop
    M260.1 P{param.C} A{param.A} F6 R{var.statusAddr} B0
    G4 P{var.cmdWait}
    ; Set frequency to 0
    M260.1 P{param.C} A{param.A} F6 R{var.freqAddr} B0
    G4 P{var.cmdWait}

    set var.commandChange = true
elif { var.shouldRun }
    ; Calculate the frequency to set based on the rpm requested,
    ; the max and min frequencies, the number of poles
    ; and the conversion factor.
    ; The conversion factor is the RPM that the spindle runs at with a 60Hz input.
    var numPoles   = { global.arborState[param.S][0][0][1] }
    var convFactor = { global.arborState[param.S][0][1][0] }
    var maxFreq    = { global.arborState[param.S][3][0] }
    var minFreq    = { global.arborState[param.S][3][1] }

    ; If the VFD conversion factor is set to 60, then we can simply give the VFD
    ; the spindle RPM and it will calculate the frequency for us.
    ; If we do this calculation ourselves, there is a possibility of slight
    ; inaccuracy as we need to send round integers to the VFD.
    var newFreq = { abs(spindles[param.S].current) }

    if { var.convFactor != 60 }
        ; RPM = 120 x f / poles.
        ; f = RPM x poles / 120
        ; Adjust for the conversion factor and divide by
        ; 60 to normalise to Hz.

        ; Account for new convFactor
        ; Clamp the frequency to the limits and ensure we get a valid result
        ; We have to split this into multiple variables to avoid stack overflow
        var freqT = { abs(spindles[param.S].current) * var.numPoles) / 120 }
        var freqL = { min(var.maxFreq, max(var.minFreq, var.freqT)) }
        set var.newFreq = { ceil(var.freqL * var.convFactor) }

    ; Set input frequency if it doesn't match the RRF value
    if { var.vfdInputFreq != var.newFreq }
        M260.1 P{param.C} A{param.A} F6 R{var.freqAddr} B{var.newFreq}
        G4 P{var.cmdWait}
        set var.commandChange = true

    ; Set spindle direction forward if needed
    if { spindles[param.S].state == "forward" && (!var.vfdRunning || !var.vfdForward) }
        M260.1 P{param.C} A{param.A} F6 R{var.statusAddr} B2
        G4 P{var.cmdWait}
        set var.commandChange = true

    ; Set spindle direction reverse if needed
    elif { spindles[param.S].state == "reverse" && (!var.vfdRunning || !var.vfdReverse) }
        M260.1 P{param.C} A{param.A} F6 R{var.statusAddr} B4
        G4 P{var.cmdWait}
        set var.commandChange = true

; Calculate current RPM from output frequency
var currentFrequency = { var.vfdOutputFreq * 0.01 } ; Convert to Hz
var currentRPM       = { var.currentFrequency * 60 / (global.arborState[param.S][0][0][1] / 2) }
var isStable         = { var.vfdRunning && var.vfdSpeedReached }

; Save previous stability flag for stability change detection
set global.arborState[param.S][2] = { global.arborVFDStatus[param.S] != null ? global.arborVFDStatus[param.S][4] : false }

; Update internal state
set global.arborState[param.S][1] = { var.commandChange }
set global.arborState[param.S][4] = { var.spindleState[5] > 0 }

; Update public status variables
; Set or initialize VFD status array
if { global.arborVFDStatus[param.S] == null }
    set global.arborVFDStatus[param.S] = { vector(5, 0) }

set global.arborVFDStatus[param.S][0] = { var.vfdRunning }
set global.arborVFDStatus[param.S][1] = { var.vfdRunning ? (var.vfdReverse ? -1 : 1) : 0 }
set global.arborVFDStatus[param.S][2] = { var.currentFrequency }
set global.arborVFDStatus[param.S][3] = { var.currentRPM }
set global.arborVFDStatus[param.S][4] = { var.isStable }

; Set or initialize VFD power array
if { global.arborVFDPower[param.S] == null }
    set global.arborVFDPower[param.S] = { vector(2, 0) }

set global.arborVFDPower[param.S][0] = { var.spindlePower }

; Calculate and update load percentage if motor power is known
if { global.arborMotorSpec[param.S] != null }
    var loadPercent = { var.spindlePower / (global.arborState[param.S][0][0][0] * 1000) * 100 }
    set global.arborVFDPower[param.S][1] = { var.loadPercent }
