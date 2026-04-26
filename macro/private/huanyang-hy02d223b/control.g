; huanyang-hy02d223b/control.g - Huanyang HY02D223B VFD implementation
; This file implements specific commands for the Huanyang HY02D223B VFD
; This VFD is NOT Modbus compatible, so we have to use custom protocol
; with the Huanyang VFD protocol to control it
;
; All Huanyang serial calls go through M2604.g so a timeout does not
; abort the caller macro.

if { !exists(param.A) }
    abort { "ArborCtl: No address specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: No spindle specified!" }

; Initialize motor data if needed
if { global.arborState[param.S][0] == null }
    set global.arborState[param.S][0] = { vector(10, null) }

var cmdWait = 50  ; Wait time between commands

; Parameter codes for Huanyang protocol as constants
var REG_MAX_FREQ = 0x05         ; PD005: Max operating frequency
var REG_MIN_FREQ = 0x0B         ; PD011: Frequency lower limit
var REG_MOTOR_VOLTAGE = 0x8D    ; PD141: Rated motor voltage
var REG_MOTOR_CURRENT = 0x8E    ; PD142: Rated motor current
var REG_MOTOR_POLES = 0x8F      ; PD143: Number of motor poles
var REG_MOTOR_SPEED = 0x90      ; PD144: Rated rotation speed

; Initialize VFD Status objects if not already done
if { global.arborVFDStatus[param.S] == null }
    set global.arborVFDStatus[param.S] = { vector(5, 0) }
    set global.arborVFDStatus[param.S][0] = false
    set global.arborVFDStatus[param.S][1] = 0
    set global.arborVFDStatus[param.S][2] = 0
    set global.arborVFDStatus[param.S][3] = 0
    set global.arborVFDStatus[param.S][4] = true

; Initialize VFD Power objects if not already done
if { global.arborVFDPower[param.S] == null }
    set global.arborVFDPower[param.S] = { vector(2, 0) }
    set global.arborVFDPower[param.S][0] = 0
    set global.arborVFDPower[param.S][1] = 0

; Always gather Motor Configuration from VFD if not already loaded
if { global.arborState[param.S][3] == null }
    ; Prefer wizard-saved motor + Hz limits when PD reads (0x01) are not
    ; supported by the VFD (common on clones that still answer 0x04 status).
    if { exists(global.arborMotorSpec) && global.arborMotorSpec[param.S] != null && exists(global.arborWizardFreqLimits) && global.arborWizardFreqLimits[param.S] != null }
        var wizMs = global.arborMotorSpec[param.S]
        var wizFl = global.arborWizardFreqLimits[param.S]
        var motorCfg = { vector(6, 0) }
        set var.motorCfg[0] = var.wizMs[0]
        set var.motorCfg[1] = var.wizMs[1]
        set var.motorCfg[2] = var.wizMs[2]
        set var.motorCfg[3] = var.wizMs[3]
        set var.motorCfg[4] = var.wizMs[4]
        set var.motorCfg[5] = var.wizMs[5]
        var freqConv = { vector(1, 1.0) }
        set global.arborState[param.S][0] = { var.motorCfg, var.freqConv, 0 }
        set global.arborState[param.S][3] = { var.wizFl[0], var.wizFl[1] }
        echo { "ArborCtl: Huanyang motor data from wizard (PD reads skipped)." }
        echo { "  Min Hz=" ^ var.wizFl[0] ^ " Max Hz=" ^ var.wizFl[1] }
    else
    ; Read number of motor poles (PD143)
    M2604 P{param.C} A{param.A} B{{0x01, 0x02, var.REG_MOTOR_POLES, 0x00, 0x00}} R5
    G4 P{var.cmdWait}
    var rawMotorPoles = { global.arborRetVal }

    ; Read rated motor voltage (PD141)
    M2604 P{param.C} A{param.A} B{{0x01, 0x03, var.REG_MOTOR_VOLTAGE, 0x00, 0x00}} R6
    G4 P{var.cmdWait}
    var rawMotorVoltage = { global.arborRetVal }

    ; Read rated motor current (PD142)
    M2604 P{param.C} A{param.A} B{{0x01, 0x03, var.REG_MOTOR_CURRENT, 0x00, 0x00}} R6
    G4 P{var.cmdWait}
    var rawMotorCurrent = { global.arborRetVal }

    ; Read rated motor speed (PD144)
    M2604 P{param.C} A{param.A} B{{0x01, 0x03, var.REG_MOTOR_SPEED, 0x00, 0x00}} R6
    G4 P{var.cmdWait}
    var rawMotorSpeed = { global.arborRetVal }

    ; Read max frequency (PD005)
    M2604 P{param.C} A{param.A} B{{0x01, 0x03, var.REG_MAX_FREQ, 0x00, 0x00}} R6
    G4 P{var.cmdWait}
    var rawMaxFreq = { global.arborRetVal }

    ; Read lower frequency limit (PD011)
    M2604 P{param.C} A{param.A} B{{0x01, 0x03, var.REG_MIN_FREQ, 0x00, 0x00}} R6
    G4 P{var.cmdWait}
    var rawMinFreq = { global.arborRetVal }

    ; Check if we received all the necessary data
    if { var.rawMotorPoles == null || var.rawMotorVoltage == null || var.rawMotorCurrent == null || var.rawMotorSpeed == null || var.rawMaxFreq == null || var.rawMinFreq == null }
        if { exists(global.arborVFDCommReady) }
            set global.arborVFDCommReady[param.S] = false
        echo { "ArborCtl: Huanyang comm fault on spindle " ^ param.S ^ ". Re-run config to clear." }
        M99

    ; Parse values from the responses
    var motorPoles = var.rawMotorPoles[4]
    var motorVoltage = { var.rawMotorVoltage[4] * 256 + var.rawMotorVoltage[5] }
    var motorCurrent = { (var.rawMotorCurrent[4] * 256 + var.rawMotorCurrent[5]) / 10.0 }
    var motorSpeed = { var.rawMotorSpeed[4] * 256 + var.rawMotorSpeed[5] }
    var maxFreq = { (var.rawMaxFreq[4] * 256 + var.rawMaxFreq[5]) / 100.0 }
    var minFreq = { (var.rawMinFreq[4] * 256 + var.rawMinFreq[5]) / 100.0 }

    ; Calculate rated frequency based on speed and poles
    var motorFreq = { (var.motorSpeed * var.motorPoles) / 120 }

    ; Calculate rated power (P = sqrt(3) x V x I x PF), assuming PF of 0.8
    var powerFactor = 0.8
    var motorPower = { (sqrt(3) * var.motorVoltage * var.motorCurrent * var.powerFactor) / 1000 }

    ; Create a motor configuration vector [power, poles, voltage, frequency, current, speed]
    var motorCfg = { vector(6, 0) }
    set var.motorCfg[0] = var.motorPower
    set var.motorCfg[1] = var.motorPoles
    set var.motorCfg[2] = var.motorVoltage
    set var.motorCfg[3] = var.motorFreq
    set var.motorCfg[4] = var.motorCurrent
    set var.motorCfg[5] = var.motorSpeed

    ; Frequency conversion vector for consistency with Shihlin
    var freqConv = { vector(1, 1.0) }

    ; Store motor config, frequency conversion, and last commanded direction
    set global.arborState[param.S][0] = { var.motorCfg, var.freqConv, 0 }

    ; Store frequency limits
    set global.arborState[param.S][3] = { vector(2, 0) }
    set global.arborState[param.S][3][0] = var.minFreq
    set global.arborState[param.S][3][1] = var.maxFreq

    echo { "ArborCTL Huanyang HY02D223B Configuration: " }
    echo { "  Power=" ^ var.motorCfg[0] ^ "kW, Poles=" ^ var.motorCfg[1] ^ ", Voltage=" ^ var.motorCfg[2] ^ "V" }
    echo { "  Frequency=" ^ var.motorCfg[3] ^ "Hz, Current=" ^ var.motorCfg[4] ^ "A, Speed=" ^ var.motorCfg[5] ^ "RPM" }
    echo { "  Max Freq=" ^ var.maxFreq ^ "Hz, Min Freq=" ^ var.minFreq ^ "Hz" }

; Determine what the spindle should be doing based on RRF's state
var shouldRun = { (spindles[param.S].state == "forward" || spindles[param.S].state == "reverse") && spindles[param.S].active > 0 }

; Read current VFD status via send.g

; Read set frequency
M2604 P{param.C} A{param.A} B{{0x04, 0x03, 0x00, 0x00, 0x00}} R5
G4 P{var.cmdWait}
var rawSetFreq = { global.arborRetVal }

; Read output frequency
M2604 P{param.C} A{param.A} B{{0x04, 0x03, 0x01, 0x00, 0x00}} R5
G4 P{var.cmdWait}
var rawOutFreq = { global.arborRetVal }

; Read output current
M2604 P{param.C} A{param.A} B{{0x04, 0x03, 0x02, 0x00, 0x00}} R5
G4 P{var.cmdWait}
var rawCurrent = { global.arborRetVal }

; Make sure we have all the data we need
if { var.rawSetFreq == null || var.rawOutFreq == null || var.rawCurrent == null }
    if { exists(global.arborVFDCommReady) }
        set global.arborVFDCommReady[param.S] = false
    echo { "ArborCtl: Huanyang comm fault on spindle " ^ param.S ^ ". Re-run config to clear." }
    M5
    M99

; Parse values from the responses
var setFreq = { (var.rawSetFreq[3] * 256 + var.rawSetFreq[4]) / 100.0 }
var currentFreq = { (var.rawOutFreq[3] * 256 + var.rawOutFreq[4]) / 100.0 }
var outputCurrent = { (var.rawCurrent[3] * 256 + var.rawCurrent[4]) / 10.0 }
var vfdRunning = { var.currentFreq > 0.1 || var.setFreq > 0.1 }
if { global.arborState[param.S][0][2] == null }
    set global.arborState[param.S][0] = { global.arborState[param.S][0][0], global.arborState[param.S][0][1], 0 }
var trackedDirection = { global.arborState[param.S][0][2] }
if { !var.vfdRunning }
    set var.trackedDirection = { 0 }
var vfdForward = { var.vfdRunning && var.trackedDirection > 0 }
var vfdReverse = { var.vfdRunning && var.trackedDirection < 0 }
var reportedDirection = { var.vfdRunning ? var.trackedDirection : 0 }
var numPoles = { global.arborState[param.S][0][0][1] }
var newFreq = { 0 }

var commandChange = { false }

; Stop spindle as early as possible if it should not be running
if { !var.shouldRun && var.vfdRunning }
    echo { "ArborCtl: Stopping spindle " ^ param.S }
    ; Set frequency to 0
    M2604 P{param.C} A{param.A} B{{0x05, 0x02, 0x00, 0x00}} R4
    G4 P{var.cmdWait}

    ; Stop spindle
    M2604 P{param.C} A{param.A} B{{0x03, 0x01, 0x08}} R3
    G4 P{var.cmdWait}

    set var.reportedDirection = { 0 }
    set var.commandChange = { true }
elif { var.shouldRun }
    ; Calculate the frequency to set based on the rpm requested
    var maxFreq = { global.arborState[param.S][3][1] }
    var minFreq = { global.arborState[param.S][3][0] }

    ; f = RPM x poles / 120
    set var.newFreq = { min(var.maxFreq, max(var.minFreq, (spindles[param.S].active * var.numPoles) / 120)) }

    ; Huanyang protocol expects frequency in 0.01Hz units
    var scaledFreq = { floor(var.newFreq * 100) }
    var freqHigh = { floor(var.scaledFreq / 256) }
    var freqLow = { var.scaledFreq - (var.freqHigh * 256) }

    ; Check if current frequency doesn't match the requested one
    var currentScaledFreq = { floor(var.setFreq * 100) }

    if { var.currentScaledFreq != var.scaledFreq }
        echo { "ArborCtl: Setting spindle " ^ param.S ^ " frequency to " ^ var.newFreq ^ " Hz" }
        M2604 P{param.C} A{param.A} B{{0x05, 0x02, var.freqHigh, var.freqLow}} R4
        G4 P{var.cmdWait}
        set var.commandChange = { true }

    ; After restart, direction is unknown - stop before reissuing
    if { var.vfdRunning && var.trackedDirection == 0 }
        echo { "ArborCtl: Spindle " ^ param.S ^ " direction is unknown - stopping before restart" }
        M2604 P{param.C} A{param.A} B{{0x05, 0x02, 0x00, 0x00}} R4
        G4 P{var.cmdWait}
        M2604 P{param.C} A{param.A} B{{0x03, 0x01, 0x08}} R3
        G4 P{var.cmdWait}
        set var.reportedDirection = { 0 }
        set var.commandChange = { true }

    ; Start spindle in the requested direction if needed
    elif { spindles[param.S].state == "forward" }
        if { !var.vfdRunning || !var.vfdForward }
            echo { "ArborCtl: Starting spindle " ^ param.S ^ " in forward direction" }
            M2604 P{param.C} A{param.A} B{{0x03, 0x01, 0x01}} R3
            G4 P{var.cmdWait}
            set var.reportedDirection = { 1 }
            set var.commandChange = { true }

    elif { spindles[param.S].state == "reverse" }
        if { !var.vfdRunning || !var.vfdReverse }
            echo { "ArborCtl: Starting spindle " ^ param.S ^ " in reverse direction" }
            M2604 P{param.C} A{param.A} B{{0x03, 0x01, 0x11}} R3
            G4 P{var.cmdWait}
            set var.reportedDirection = { -1 }
            set var.commandChange = { true }

; Calculate current RPM from output frequency
var currentRPM = { var.currentFreq * 60 * 2 / var.numPoles }

; Check if frequency is stable (within 5% of target)
var targetFreq = { var.shouldRun ? var.newFreq : 0 }
var freqDiff = { abs(var.currentFreq - var.targetFreq) }
var freqStable = { var.freqDiff < (var.targetFreq * 0.05) || var.freqDiff < 0.5 }

; Save previous stability flag for stability change detection
set global.arborState[param.S][2] = { global.arborVFDStatus[param.S] != null ? global.arborVFDStatus[param.S][4] : false }

; Update internal state
set global.arborState[param.S][1] = { var.commandChange }
set global.arborState[param.S][0][2] = { var.reportedDirection }

; Update public status variables
set global.arborVFDStatus[param.S][0] = { var.vfdRunning }
set global.arborVFDStatus[param.S][1] = { var.vfdRunning ? var.reportedDirection : 0 }
set global.arborVFDStatus[param.S][2] = { var.currentFreq }
set global.arborVFDStatus[param.S][3] = { var.currentRPM }
set global.arborVFDStatus[param.S][4] = { var.freqStable }

; Calculate and update power information
if { global.arborState[param.S][0] != null }
    var powerFactor = { 0.8 }
    var ratedVoltage = { global.arborState[param.S][0][0][2] }
    var outputPower = { sqrt(3) * var.ratedVoltage * var.outputCurrent * var.powerFactor }

    var ratedPower = { global.arborState[param.S][0][0][0] * 1000 }
    var loadPercentage = { min((var.outputPower / var.ratedPower) * 100, 100) }

    set global.arborVFDPower[param.S][0] = { var.outputPower }
    set global.arborVFDPower[param.S][1] = { var.loadPercentage }
