; huanyang-hy02d223b.g - Huanyang HY02D223B VFD implementation
; This file implements specific commands for the Huanyang HY02D223B VFD
; This VFD is NOT Modbus compatible, so we have to use M260.4 commands
; with the Huanyang VFD protocol to control it

if { !exists(param.A) }
    abort { "ArborCtl: No address specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: No spindle specified!" }

; Motor Poles, Motor Rated Voltage, Motor Rated Frequency, Motor Rated Current, Motor Rotation Speed
var motorConfigAddresses = {0x8F, 0x8D, 0x05, 0x8E, 0x90}

; Gather Motor Configuration from VFD if not already loaded
if { global.arborCtlState[param.S][7] == null }
    var motorConfig = { vector(6, null) }

    ; Read each motor configuration value
    while { iterations < #var.motorConfigAddresses }
        M260.4 P{param.C} A{param.A} B{{0x01, 0x03, var.motorConfigAddresses[iterations], 0x00, 0x00}} R5 V"rawMotorConfig"
        G4 P1

        ; Strip out the value from the raw data
        set var.motorConfig[iterations+1] = { var.rawMotorConfig[3] * 256 + var.rawMotorConfig[4] }

    ; Motor power can not be read from the VFD, so we calculate it
    set var.motorConfig[0] = { var.motorConfig[2] * var.motorConfig[3] }

    set global.arborCtlState[param.S][6] = { vector(6, null) }
    set global.arborCtlState[param.S][7] = { var.motorConfig }

var shouldRun = { (spindles[param.S].state == "forward" || spindles[param.S].state == "reverse") && spindles[param.S].active > 0 }

; Read status bits by writing an empty control status request that does
; not modify the direction configured.
M260.4 P{param.C} A{param.A} B{0x03, (global.arbotCtlState[param.S][6][1] == true ? 0x10: 0x00)} R5 V"spindleState"

; Give VFD time to process
G4 P1

; Read output power
M261.1 P{global.modbusChannel} A{global.modbusAddress} F3 R{var.powerAddr} B1 V"spindlePower"

G4 P1

; Read any error codes
M261.1 P{global.modbusChannel} A{global.modbusAddress} F3 R{var.errorAddr} B2 V"spindleErrors"

; Make sure we have all the data we need
if { var.spindleState == null || var.spindleErrors == null }
    M5
    abort { "ArborCtl: Failed to read spindle state!" }

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
var vfdRunning      = { (var.spindleState[0] - ((var.spindleState[0] / 2) * 2)) == 1 }
var vfdForward      = { ((var.spindleState[0] / 2) * 2) != var.spindleState[0] }
var vfdReverse      = { ((var.spindleState[0] / 4) * 4) != var.spindleState[0] }
var vfdSpeedReached = { (var.spindleState[0] - ((var.spindleState[0] / 8) * 8)) == 1 }
var vfdInputFreq    = { global.spindleState[1] }

if { var.spindlePower == null }
    set var.spindlePower = { var.spindleState[3] * var.spindleState[4] }
else
    set var.spindlePower = { var.spindlePower[0] * 10 }

; Check for invalid spindle state and call emergency stop on the VFD
if { (var.vfdRunning && !var.vfdForward && !var.vfdReverse) || (!var.vfdRunning && (var.vfdForward || var.vfdReverse)) }
    M260.1 P{param.C} A{param.A} F6 R{var.statusAddr} B128
    G4 P1
    echo { "ArborCtl: Invalid spindle state detected - emergency VFD stop issued!" }
    M112

var commandChange = false

; Stop spindle as early as possible if it should not be running
if { !var.shouldRun && var.vfdRunning }
    ; Stop spindle, set frequency to 0
    M260.1 P{param.C} A{param.A} F6 R{var.statusAddr} B0
    G4 P1
    M260.1 P{param.C} A{param.A} F6 R{var.freqAddr} B0
    G4 P1

    set var.commandChange = true

else
    ; Set input frequency if it doesn't match the RRF value
    if { global.spindleState[1] != spindles[param.S].active }
        M260.1 P{param.C} A{param.A} F6 R{var.freqAddr} B{spindles[param.S].active}
        G4 P1
        set var.commandChange = true

    ; Set spindle direction forward if it is not running forward
    if { spindles[0].state == "forward" && !var.vfdForward }
        M260.1 P{param.C} A{param.A} F6 R{var.statusAddr} B2
        set var.commandChange = true

    ; Set spindle direction reverse if it is not running in reverse
    elif { spindles[0].state == "reverse" && !var.vfdReverse }
        M260.1 P{param.C} A{param.A} F6 R{var.statusAddr} B4
        set var.commandChange = true

; Update global state
set global.arborCtlState[param.S][0] = { var.vfdRunning }
set global.arborCtlState[param.S][1] = { var.vfdRunning && var.vfdReverse }

; Update old stable value
set global.arborCtlState[param.S][3] = { global.arborCtlState[param.S][2] }

; Write new stable value
set global.arborCtlState[param.S][2] = { var.vfdRunning && var.vfdSpeedReached }

set global.arborCtlState[param.S][4] = { var.commandChange }

; Set model-specific data
set global.arborCtlState[param.S][6] = { var.spindleState[1], var.spindleState[2], var.spindlePower[3], var.spindlePower[4] }

; Update spindle load
; Spindle load is calculated as the current power divided by the rated power
set global.arborCtlState[param.S][5] = { var.spindlePower / (global.arborCtlState[param.S][7][0] * 1000) }
