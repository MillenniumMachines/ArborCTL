; yalang-yl620a.g - Yalang YL620-A VFD implementation
; This file implements specific commands for the Yalang YL620-A VFD

if { !exists(param.A) }
    abort { "ArborCtl: No address specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: No spindle specified!" }

var motorLimitsAddr = 0x0c00
var maximumFrequencyAddr = 0x0005
var minimumFrequencyAddr = 0x0009
var setCommandAddr = 0x2000
var setFrequencyAddr = 0x2001
var stateBytesAddr = 0x2008

if {!exists(global.vfdAtSpeedCount)}
    global vfdAtSpeedCount = 0

; Gather Motor Configuration from VFD if not already loaded
if { global.arborState[param.S][0] == null }
    ; 0 = Motor Rated Current, 1 = Motor Rated Voltage, 2 = Motor Poles
    M261.9 P{param.C} A{param.A} F3 R{var.motorLimitsAddr} B3
    var motorCfg = { global.arborRetVal }

    ; 0 = Max Frequency, 1 = Min Frequency
    M261.9 P{param.C} A{param.A} F3 R{var.maximumFrequencyAddr} B1
    var maxFrequency = { global.arborRetVal }
    M261.9 P{param.C} A{param.A} F3 R{var.minimumFrequencyAddr} B1
    var minFrequency = { global.arborRetVal }

    if { var.maxFrequency == null || var.minFrequency == null}
        echo { "Unable to load necessary data from VFD for spindle control!"}
        M99

    var spindleLimits = { var.maxFrequency[0], var.minFrequency[0] }

    if { var.motorCfg == null || var.spindleLimits == null }
        echo { "Unable to load necessary data from VFD for spindle control!"}
        M99

    set var.motorCfg[0]      = { var.motorCfg[0] / 10 }
    set var.spindleLimits[0] = { ceil(var.spindleLimits[0] / 10) }
    set var.spindleLimits[1] = { floor(var.spindleLimits[1] / 10) }

    ; Handle the case when frequency conversion factor is 0 or null

    echo { "ArborCTL Yalang YL620-A Configuration: "}
    echo { "  Current=" ^ var.motorCfg[0] ^ "A, Voltage=" ^ var.motorCfg[1] ^ "V, Poles=" ^ var.motorCfg[2] }
    echo { "  Max Speed=" ^ var.spindleLimits[0] ^ ", Min Speed=" ^ var.spindleLimits[1] }

    ; Store VFD-specific configuration in internal state
    set global.arborState[param.S][0] = { var.motorCfg }
    set global.arborState[param.S][3] = { var.spindleLimits }

var shouldRun = { (spindles[param.S].state == "forward" || spindles[param.S].state == "reverse") && spindles[param.S].active > 0 }

; 0 = Error
; 1 = Inverter State
; 2 = Target Frequency
; 3 = Current Frequency
; 4 = Current Current
; 5 = Current Voltage
; 6 = Bus Voltage
; 7 = Number of fields in Multi Rate
; 8 = Acceleration/Deceleration Flags
M261.9 P{param.C} A{param.A} F3 R{var.stateBytesAddr} B9
var stateBytes = { global.arborRetVal }

if { var.stateBytes == null }
    echo { "ArborCtl: VFD stopped responding to inputs."}
    set global.arborState[param.S][4] = true
    M99

var error = var.stateBytes[0]

if { var.error == null }
    echo { "ArborCtl: VFD in error state."}
    set global.arborState[param.S][4] = true
    M99

var spindlePower = { var.stateBytes[4] * var.stateBytes[5] }

; Check for VFD errors
if { var.stateBytes[0] != 0 }
    echo { "ArborCtl: VFD Error detected. Code=" ^ var.stateBytes[0] }
    while {var.stateBytes[0] > 0 }
        var bitPresent = { mod(var.stateBytes[0], 2) == 1 }
        if { var.bitPresent }
            if {iterations == 0}
                echo { "ArborCtl: Too Low Voltage - Supply voltage has dropped too low."}
            elif {iterations == 1}
                echo { "ArborCtl: Too High Voltage - Supply voltage has risen too high."}
            elif {iterations == 2}
                echo { "ArborCtl: Overcurrent - When motor was running, current levels rose too high."}
            elif {iterations == 3}
                echo { "ArborCtl: External PWM Error - An error in the CPU's PWM circuitry has occurred."}
            elif {iterations == 4}
                echo { "ArborCtl: Short Circuit Alarm - A short circuit has occurred."}
            elif {iterations == 5}
                echo { "ArborCtl: External Fault - An external fault has been indicated to the VFD."}
            elif {iterations == 6}
                echo { "ArborCtl: Internal Data Storage Error - An error has occurred in the VFD's internal data storage."}
            elif {iterations == 7}
                echo { "ArborCtl: Overheating - The VFD is overheating."}
            elif {iterations == 8}
                echo { "ArborCtl: Temperature Detection Error - The VFD encountered errors while trying to ascertain its temperature."}
            elif {iterations == 10}
                echo { "ArborCtl: Powering Down - The VFD is in power down mode."}
            elif {iterations == 11}
                echo { "ArborCtl: RS485 Communication Interrupted - RS485 communication was interrupted for too long."}
            elif {iterations == 12}
                echo { "ArborCtl: Parametric Error."}
            elif {iterations == 15}
                echo { "ArborCtl: Motor Overheating - The motor is overheating."}
            else
                echo { "ArborCtl: Unknown Error."}
        set var.stateBytes[0] = { floor(var.stateBytes[0] / 2) }
    set global.arborState[param.S][4] = true
    M99

; Extract status bits from stateBytes using modulo and division
;
var vfdRunning = { var.stateBytes[1] != 0 }
var vfdForward = { mod(floor(var.stateBytes[1] / 2), 2) == 1 }
var vfdReverse = { mod(floor(var.stateBytes[1] / 4), 2) == 1 }
var vfdSpeedReached = { var.stateBytes[8] == 0 }
var vfdInputFreq = { var.stateBytes[2] }
var vfdOutputFreq = { var.stateBytes[3] }

; Calculate power consumption
set var.spindlePower = { var.stateBytes[3] * var.stateBytes[4] }

; Check for invalid spindle state and call emergency stop on the VFD
if { (var.vfdRunning && !var.vfdForward && !var.vfdReverse) || (!var.vfdRunning && (var.vfdForward || var.vfdReverse)) }
    M260.9 P{param.C} A{param.A} F6 R{var.stateBytesAddr} B{10,}
    echo { "ArborCtl: Invalid spindle state detected - emergency VFD stop issued!" }
    M112

var commandChange = false

; Stop spindle as early as possible if it should not be running
if { !var.shouldRun && var.vfdRunning }
    ; Stop spindle - Command 0 = Stop
    M260.9 P{param.C} A{param.A} F6 R{var.setCommandAddr} B{0x0001,}
    ; Set frequency to 0
    M260.9 P{param.C} A{param.A} F6 R{var.setFrequencyAddr} B{0x0000,}

    set var.commandChange = true
elif { var.shouldRun }
    ; Calculate the frequency to set based on the rpm requested,
    ; the max and min frequencies, and the number of poles.
    var numPoles   = { global.arborState[param.S][0][2] }
    var maxFreq    = { global.arborState[param.S][3][0] }
    var minFreq    = { global.arborState[param.S][3][1] }

    ; RPM = 120 x f / poles.
    ; f = RPM x poles / 120
    var newFreq = { ceil(min(var.maxFreq, max(var.minFreq, (abs(spindles[param.S].current) * var.numPoles) / 120))) * 10 }

    ; Set input frequency if it doesn't match the RRF value
    if { var.vfdInputFreq != var.newFreq }
        M260.9 P{param.C} A{param.A} F6 R{var.setFrequencyAddr} B{var.newFreq,}
        set var.commandChange = true

    ; Set spindle direction forward if needed
    if { spindles[param.S].state == "forward" && (!var.vfdRunning || !var.vfdForward) }
        M260.9 P{param.C} A{param.A} F6 R{var.setCommandAddr} B{0x0012,}
        set var.commandChange = true

    ; Set spindle direction reverse if needed
    elif { spindles[param.S].state == "reverse" && (!var.vfdRunning || !var.vfdReverse) }
        M260.9 P{param.C} A{param.A} F6 R{var.setCommandAddr} B{0x0022,}
        set var.commandChange = true

; Calculate current RPM from output frequency
var currentFrequency = { var.vfdOutputFreq * 0.1 } ; Convert to Hz
var currentRPM       = { var.currentFrequency * 60 / (global.arborState[param.S][0][2] / 2) }
var isStable         = { var.vfdRunning && var.vfdSpeedReached }

; Save previous stability flag for stability change detection
set global.arborState[param.S][2] = { global.arborVFDStatus[param.S] != null ? global.arborVFDStatus[param.S][4] : false }

; Update internal state
set global.arborState[param.S][1] = { var.commandChange }
set global.arborState[param.S][4] = { var.stateBytes[0] > 0 }

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
