; huanyang-hy02d223b/control.g - Huanyang HY02D223B VFD implementation
; This file implements specific commands for the Huanyang HY02D223B VFD
; This VFD is NOT Modbus compatible, so we have to use custom protocol
; with the Huanyang VFD protocol to control it

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
var REG_RUN_CMD = 0x00          ; PD000: Run command register
var REG_FREQ_SETTING = 0x01     ; PD001: Operating frequency setting
var REG_DIR_SETTING = 0x02      ; PD002: Operating direction setting
var REG_MAIN_VISUAL = 0x03      ; PD003: Main visualization parameter
var REG_AUX_VISUAL = 0x04       ; PD004: Auxiliary visualization parameter
var REG_MAX_FREQ = 0x05         ; PD005: Max operating frequency
var REG_MIN_FREQ = 0x06         ; PD006: Min operating frequency
var REG_MAX_VOLTAGE = 0x08      ; PD008: Max voltage
var REG_MIN_VOLTAGE = 0x09      ; PD009: Min voltage
var REG_LOWER_FREQ_LIMIT = 0x0A ; PD010: Lower frequency limit
var REG_ACCEL_TIME = 0x0E       ; PD014: Acceleration time
var REG_DECEL_TIME = 0x0F       ; PD015: Deceleration time
var REG_FWD_REV_DEADTIME = 0x17 ; PD023: Forward/Reverse switching dead time
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
    ; Query the VFD for motor configuration
    var rawMotorPoles = 0
    var rawMotorVoltage = 0
    var rawMotorCurrent = 0
    var rawMotorSpeed = 0
    var rawMaxFreq = 0
    var rawMinFreq = 0

    ; Read number of motor poles (PD143)
    M260.4 P{param.C} A{param.A} B{{0x01, 0x03, var.REG_MOTOR_POLES, 0x00, 0x01}} R5
    G4 P{var.cmdWait}
    M261.4 V"rawMotorPoles"

    ; Read rated motor voltage (PD141)
    M260.4 P{param.C} A{param.A} B{{0x01, 0x03, var.REG_MOTOR_VOLTAGE, 0x00, 0x01}} R5
    G4 P{var.cmdWait}
    M261.4 V"rawMotorVoltage"

    ; Read rated motor current (PD142)
    M260.4 P{param.C} A{param.A} B{{0x01, 0x03, var.REG_MOTOR_CURRENT, 0x00, 0x01}} R5
    G4 P{var.cmdWait}
    M261.4 V"rawMotorCurrent"

    ; Read rated motor speed (PD144)
    M260.4 P{param.C} A{param.A} B{{0x01, 0x03, var.REG_MOTOR_SPEED, 0x00, 0x01}} R5
    G4 P{var.cmdWait}
    M261.4 V"rawMotorSpeed"

    ; Read max frequency (PD005)
    M260.4 P{param.C} A{param.A} B{{0x01, 0x03, var.REG_MAX_FREQ, 0x00, 0x01}} R5
    G4 P{var.cmdWait}
    M261.4 V"rawMaxFreq"

    ; Read min frequency (PD006)
    M260.4 P{param.C} A{param.A} B{{0x01, 0x03, var.REG_MIN_FREQ, 0x00, 0x01}} R5
    G4 P{var.cmdWait}
    M261.4 V"rawMinFreq"

    ; Check if we received all the necessary data
    if { var.rawMotorPoles == 0 || var.rawMotorVoltage == 0 || var.rawMotorCurrent == 0 ||
         var.rawMotorSpeed == 0 || var.rawMaxFreq == 0 || var.rawMinFreq == 0 }
        echo { "ArborCtl: Failed to read motor configuration from Huanyang VFD!" }
        M99

    ; Parse values from the responses
    var motorPoles = var.rawMotorPoles[3]
    var motorVoltage = var.rawMotorVoltage[3]
    var motorCurrent = { var.rawMotorCurrent[3] * 0.1 }  ; Current is in 0.1A units
    var motorSpeed = var.rawMotorSpeed[3]
    var maxFreq = { var.rawMaxFreq[3] * 0.1 }            ; Frequency is in 0.1Hz units
    var minFreq = { var.rawMinFreq[3] * 0.1 }            ; Frequency is in 0.1Hz units

    ; Calculate rated frequency based on speed and poles
    ; f = (n * p) / 120 where n is speed in RPM and p is number of poles
    var motorFreq = { (var.motorSpeed * var.motorPoles) / 120 }

    ; Calculate rated power (P = √3 × V × I × PF), assuming PF of 0.8
    var powerFactor = 0.8
    var motorPower = { (sqrt(3) * var.motorVoltage * var.motorCurrent * var.powerFactor) / 1000 }  ; in kW

    ; Create a motor configuration vector [power, poles, voltage, frequency, current, speed]
    var motorCfg = { vector(6, 0) }
    set var.motorCfg[0] = var.motorPower  ; Rated power in kW
    set var.motorCfg[1] = var.motorPoles  ; Number of poles
    set var.motorCfg[2] = var.motorVoltage ; Rated voltage
    set var.motorCfg[3] = var.motorFreq   ; Rated frequency
    set var.motorCfg[4] = var.motorCurrent ; Rated current
    set var.motorCfg[5] = var.motorSpeed  ; Rated speed

    ; Create a frequency conversion vector for consistency with Shihlin
    var freqConv = { vector(1, 1.0) }

    ; Store motor config and frequency conversion in arborState[S][0]
    set global.arborState[param.S][0] = { var.motorCfg, var.freqConv }

    ; Store frequency limits
    set global.arborState[param.S][3] = { vector(2, 0) }
    set global.arborState[param.S][3][0] = var.minFreq           ; Min frequency
    set global.arborState[param.S][3][1] = var.maxFreq           ; Max frequency

    echo { "ArborCTL Huanyang HY02D223B Configuration: " }
    echo { "  Power=" ^ var.motorCfg[0] ^ "kW, Poles=" ^ var.motorCfg[1] ^ ", Voltage=" ^ var.motorCfg[2] ^ "V" }
    echo { "  Frequency=" ^ var.motorCfg[3] ^ "Hz, Current=" ^ var.motorCfg[4] ^ "A, Speed=" ^ var.motorCfg[5] ^ "RPM" }
    echo { "  Max Freq=" ^ var.maxFreq ^ "Hz, Min Freq=" ^ var.minFreq ^ "Hz" }

; Determine what the spindle should be doing based on RRF's state
var shouldRun = { (spindles[param.S].state == "forward" || spindles[param.S].state == "reverse") && spindles[param.S].active > 0 }

; Read current VFD status
var rawStatus = 0
var rawFreq = 0
var rawCurrent = 0

; Read run status (PD000)
M260.4 P{param.C} A{param.A} B{{0x01, 0x03, var.REG_RUN_CMD, 0x00, 0x01}} R5
G4 P{var.cmdWait}
M261.4 V"rawStatus"

; Read current frequency (PD001)
M260.4 P{param.C} A{param.A} B{{0x01, 0x03, var.REG_FREQ_SETTING, 0x00, 0x01}} R5
G4 P{var.cmdWait}
M261.4 V"rawFreq"

; Read output current (PD003 - Main display parameter set to current)
M260.4 P{param.C} A{param.A} B{{0x01, 0x03, var.REG_MAIN_VISUAL, 0x00, 0x01}} R5
G4 P{var.cmdWait}
M261.4 V"rawCurrent"

; Make sure we have all the data we need
if { var.rawStatus == 0 || var.rawFreq == 0 || var.rawCurrent == 0 }
    echo { "ArborCtl: Failed to read spindle state from Huanyang VFD!" }

    ; Try to stop the spindle if we can't read its state - safety measure
    M260.4 P{param.C} A{param.A} B{{0x01, 0x06, var.REG_RUN_CMD, 0x00, 0x01}} R6
    G4 P{var.cmdWait}
    M5
    M99

; Parse values from the responses
var vfdRunning = { (var.rawStatus[3] & 0x01) == 1 }
var vfdForward = { (var.rawStatus[3] & 0x02) == 0 }  ; Direction bit is 0 for forward
var vfdReverse = { !var.vfdForward && var.vfdRunning }
var currentFreq = { (var.rawFreq[3] * 256 + var.rawFreq[4]) / 100.0 }  ; Convert from 0.01Hz units
var outputCurrent = { var.rawCurrent[3] * 0.1 }  ; Current in 0.1A units

; Check for invalid spindle state
if { (var.vfdRunning && !var.vfdForward && !var.vfdReverse) }
    M260.4 P{param.C} A{param.A} B{{0x01, 0x06, var.REG_RUN_CMD, 0x00, 0x01}} R6
    G4 P{var.cmdWait}
    echo { "ArborCtl: Invalid spindle state detected - emergency VFD stop issued!" }
    M112

var commandChange = false

; Stop spindle as early as possible if it should not be running
if { !var.shouldRun && var.vfdRunning }
    echo { "ArborCtl: Stopping spindle " ^ param.S }
    ; Stop spindle
    M260.4 P{param.C} A{param.A} B{{0x01, 0x06, var.REG_RUN_CMD, 0x00, 0x01}} R6
    G4 P{var.cmdWait}

    ; Set frequency to 0
    M260.4 P{param.C} A{param.A} B{{0x01, 0x06, var.REG_FREQ_SETTING, 0x00, 0x00}} R6
    G4 P{var.cmdWait}

    set var.commandChange = true
else
    ; Calculate the frequency to set based on the rpm requested
    var numPoles = global.arborState[param.S][0][0][1]  ; Get motor poles from stored config
    var maxFreq = global.arborState[param.S][3][1]
    var minFreq = global.arborState[param.S][3][0]

    ; RPM = 120 x f / poles
    ; f = RPM x poles / 120
    var newFreq = { min(var.maxFreq, max(var.minFreq, (spindles[param.S].active * var.numPoles) / 120)) }

    ; Huanyang protocol expects frequency in 0.01Hz units
    var scaledFreq = { floor(var.newFreq * 100) }
    var freqHigh = { floor(var.scaledFreq / 256) }
    var freqLow = { var.scaledFreq % 256 }

    ; Check if current frequency doesn't match the requested one
    var currentScaledFreq = { floor(var.currentFreq * 100) }

    if { var.currentScaledFreq != var.scaledFreq }
        echo { "ArborCtl: Setting spindle " ^ param.S ^ " frequency to " ^ var.newFreq ^ " Hz" }
        M260.4 P{param.C} A{param.A} B{{0x01, 0x06, var.REG_FREQ_SETTING, var.freqHigh, var.freqLow}} R6
        G4 P{var.cmdWait}
        set var.commandChange = true

    ; Set spindle direction and start running if needed
    if { spindles[param.S].state == "forward" }
        ; First check if we need to change direction
        if { !var.vfdForward }
            echo { "ArborCtl: Setting spindle " ^ param.S ^ " direction to forward" }
            M260.4 P{param.C} A{param.A} B{{0x01, 0x06, var.REG_DIR_SETTING, 0x00, 0x00}} R6
            G4 P{var.cmdWait}
            set var.commandChange = true

        ; Then check if we need to start the spindle
        if { !var.vfdRunning }
            echo { "ArborCtl: Starting spindle " ^ param.S ^ " in forward direction" }
            M260.4 P{param.C} A{param.A} B{{0x01, 0x06, var.REG_RUN_CMD, 0x00, 0x02}} R6
            G4 P{var.cmdWait}
            set var.commandChange = true

    elif { spindles[param.S].state == "reverse" }
        ; First check if we need to change direction
        if { var.vfdForward || !var.vfdRunning }
            echo { "ArborCtl: Setting spindle " ^ param.S ^ " direction to reverse" }
            M260.4 P{param.C} A{param.A} B{{0x01, 0x06, var.REG_DIR_SETTING, 0x00, 0x01}} R6
            G4 P{var.cmdWait}
            set var.commandChange = true

        ; Then check if we need to start the spindle
        if { !var.vfdRunning }
            echo { "ArborCtl: Starting spindle " ^ param.S ^ " in reverse direction" }
            M260.4 P{param.C} A{param.A} B{{0x01, 0x06, var.REG_RUN_CMD, 0x00, 0x02}} R6
            G4 P{var.cmdWait}
            set var.commandChange = true

; Calculate current RPM from output frequency
var currentRPM = { var.currentFreq * 60 * 2 / var.numPoles }

; Check if frequency is stable (within 5% of target)
var targetFreq = { var.shouldRun ? var.newFreq : 0 }
var freqDiff = { abs(var.currentFreq - var.targetFreq) }
var freqStable = { var.freqDiff < (var.targetFreq * 0.05) || var.freqDiff < 0.5 }

; Save previous stability flag for stability change detection
set global.arborState[param.S][2] = { global.arborVFDStatus[param.S] != null ? global.arborVFDStatus[param.S][4] : false }

; Update internal state
set global.arborState[param.S][1] = var.commandChange

; Update public status variables
set global.arborVFDStatus[param.S][0] = var.vfdRunning
set global.arborVFDStatus[param.S][1] = { var.vfdRunning ? (var.vfdReverse ? -1 : 1) : 0 }
set global.arborVFDStatus[param.S][2] = var.currentFreq
set global.arborVFDStatus[param.S][3] = var.currentRPM
set global.arborVFDStatus[param.S][4] = var.freqStable

; Calculate and update power information
if { global.arborState[param.S][0] != null }
    ; Calculate power in watts (P = √3 × V × I × PF)
    var powerFactor = 0.8  ; Assumed power factor
    var ratedVoltage = global.arborState[param.S][0][0][2]  ; Get voltage from stored config
    var outputPower = { sqrt(3) * var.ratedVoltage * var.outputCurrent * var.powerFactor }

    ; Calculate load percentage
    var ratedPower = { global.arborState[param.S][0][0][0] * 1000 }  ; Convert kW to W
    var loadPercentage = { min((var.outputPower / var.ratedPower) * 100, 100) }

    ; Update power information
    set global.arborVFDPower[param.S][0] = var.outputPower
    set global.arborVFDPower[param.S][1] = var.loadPercentage
