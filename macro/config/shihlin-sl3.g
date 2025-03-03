; config/shihlin-sl3.g - Shihlin SL3 VFD configuration
; This file implements specific commands for the Shihlin SL3 VFD

if { !exists(param.A) }
    abort { "ArborCtl: Shihlin-SL3 - No address specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: Shihlin-SL3 - No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: Shihlin-SL3 - No spindle specified!" }

if { !exists(param.W) }
    abort { "ArborCtl: Shihlin-SL3 - No motor rated power specified!" }

if { !exists(param.P) }
    abort { "ArborCtl: Shihlin-SL3 - No motor poles specified!" }

if { !exists(param.V) }
    abort { "ArborCtl: Shihlin-SL3 - No motor rated voltage specified!" }

if { !exists(param.F) }
    abort { "ArborCtl: Shihlin-SL3 - No motor rated frequency specified!" }

if { !exists(param.I) }
    abort { "ArborCtl: Shihlin-SL3 - No motor rated current specified!" }

if { !exists(param.R) }
    abort { "ArborCtl: Shihlin-SL3 - No motor rotation speed specified!" }

; Check that we can talk to the VFD by reading the model number
M261.1 P{param.C} A{param.A} F3 R2710 B1 V"vfdModel"


; Command: Read spindle status
if { param.Q == 0 }
    ; Read status bits, frequency, output data
    ; 0 = Status, 1 = Req Freq, 2 = Output Freq, 3 = Output Current, 4 = Output Voltage
    M261.1 P{param.C} A{param.A} F3 R4097 B5 V"spindleState"

    ; Give VFD time to process
    G4 P1

    ; Read output power
    M261.1 P{global.modbusChannel} A{global.modbusAddress} F3 R4123 B1 V"spindlePower"

    G4 P1

    ; Read any error codes
    M261.1 P{global.modbusChannel} A{global.modbusAddress} F3 R4103 B2 V"spindleErrors"

    var vfdForward = { ((var.spindleState[0] / 2) * 2) != var.spindleState[0] }
    var vfdReverse = { ((var.spindleState[0] / 4) * 4) != var.spindleState[0] }

    var spindleRunning = { var.vfdForward || var.vfdReverse }
    var spindleFrequency = { var.spindleState[2] }
    set global.arborCtlState[param.S] = { global.spindleState[0], global.spindleState[1], global.spindleState[2], global.spindlePower[0], global.spindleErrors[0] }

; Command: Process current state and update if needed
elif { param.A == "processState" }
    var shouldRun = param.B

    ; Extract status bits from spindleState
    if { global.spindleState == null }
        M99

    ; Extract current state to variables
    var vfdForward = { mod(floor(global.spindleState[0]/pow(2,1)),2) == 1 }
    var vfdReverse = { mod(floor(global.spindleState[0]/pow(2,2)),2) == 1 }
    var vfdRunning = { var.vfdForward || var.vfdReverse }
    var vfdInputFreq = { global.spindleState[1] }

    ; Stop spindle if it should not be running
    if { !var.shouldRun && var.vfdRunning }
        ; Stop spindle, set frequency to 0
        M260.1 P{global.modbusChannel} A{global.modbusAddress} F6 R4097 B0
        G4 P1
        M260.1 P{global.modbusChannel} A{global.modbusAddress} F6 R4098 B0
        M99

    ; Update frequency if it doesn't match
    if { var.vfdInputFreq != spindles[0].active }
        M260.1 P{global.modbusChannel} A{global.modbusAddress} F6 R4098 B{spindles[0].active}
        G4 P1

    ; Update direction if needed
    if { spindles[0].state == "forward" && !var.vfdForward }
        M260.1 P{global.modbusChannel} A{global.modbusAddress} F6 R4097 B2

    elif { spindles[0].state == "reverse" && !var.vfdReverse }
        M260.1 P{global.modbusChannel} A{global.modbusAddress} F6 R4097 B4

; Command: Set spindle frequency
elif { param.A == "setFrequency" && exists(param.F) }
    M260.1 P{global.modbusChannel} A{global.modbusAddress} F6 R4098 B{param.F}

; Command: Start spindle in forward direction
elif { param.A == "forward" }
    M260.1 P{global.modbusChannel} A{global.modbusAddress} F6 R4097 B2

; Command: Start spindle in reverse direction
elif { param.A == "reverse" }
    M260.1 P{global.modbusChannel} A{global.modbusAddress} F6 R4097 B4

; Command: Stop spindle
elif { param.A == "stop" }
    M260.1 P{global.modbusChannel} A{global.modbusAddress} F6 R4097 B0
    G4 P1
    M260.1 P{global.modbusChannel} A{global.modbusAddress} F6 R4098 B0