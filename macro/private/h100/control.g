; h100/control.g - H100 VFD implementation (standard Modbus RTU)
; FluidNC register map: FC5 coils for run/stop, FC6 for frequency, FC4 for readback.
;
; M2600 verifies with FC3 — do not use it for FC5 coil writes.

if { !exists(param.A) }
    abort { "ArborCtl: No address specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: No spindle specified!" }

M98 P"arborctl/delay-for-command.g" S250

M98 P"arborctl/h100/settings.g"

; Initialize motor data if needed
if { global.arborState[param.S][0] == null }
    set global.arborState[param.S][0] = { vector(10, null) }

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

; Load motor config + Hz limits once
if { global.arborState[param.S][3] == null }
    var motorCfg = { null }
    var maxHz = { null }
    var minHz = { null }

    if { exists(global.arborMotorSpec) && global.arborMotorSpec[param.S] != null }
        set var.motorCfg = { global.arborMotorSpec[param.S] }

    if { exists(global.arborWizardFreqLimits) && global.arborWizardFreqLimits[param.S] != null }
        set var.maxHz = { global.arborWizardFreqLimits[param.S][1] }
        set var.minHz = { global.arborWizardFreqLimits[param.S][0] }

    ; Prefer VFD F005 / F011 when readable (deci-Hz)
    M2601 E0 P{param.C} A{param.A} F3 R{global.h100MaxFreqAddr} B1
    var rawMax = { global.arborRetVal }
    M2601 E0 P{param.C} A{param.A} F3 R{global.h100MinFreqAddr} B1
    var rawMin = { global.arborRetVal }

    if { var.rawMax != null && #var.rawMax == 1 && var.rawMax[0] > 0 }
        set var.maxHz = { var.rawMax[0] / 10 }
    if { var.rawMin != null && #var.rawMin == 1 }
        set var.minHz = { var.rawMin[0] / 10 }

    if { var.motorCfg == null || var.maxHz == null || var.minHz == null }
        if { exists(global.arborVFDCommReady) }
            set global.arborVFDCommReady[param.S] = false
        echo { "ArborCtl: H100 - Unable to load motor/Hz limits (run VFD config or set wizard values)." }
        M99

    echo { "ArborCtl: H100 Configuration: " }
    echo { "  Power=" ^ var.motorCfg[0] ^ "kW, Poles=" ^ var.motorCfg[1] ^ ", Voltage=" ^ var.motorCfg[2] ^ "V" }
    echo { "  Frequency=" ^ var.motorCfg[3] ^ "Hz, Current=" ^ var.motorCfg[4] ^ "A, Speed=" ^ var.motorCfg[5] ^ "RPM" }
    echo { "  Max Hz=" ^ var.maxHz ^ ", Min Hz=" ^ var.minHz }

    set global.arborState[param.S][0] = { var.motorCfg }
    set global.arborState[param.S][3] = { var.maxHz, var.minHz }

var shouldRun = { (spindles[param.S].state == "forward" || spindles[param.S].state == "reverse") && spindles[param.S].active > 0 }
var wasRunning = { global.arborVFDStatus[param.S] != null ? global.arborVFDStatus[param.S][0] : false }

if { !var.shouldRun && !var.wasRunning }
    M99

; Read output frequency (FC4, 2 input regs). First word = running freq (deci-Hz).
M2601 E0 P{param.C} A{param.A} F4 R{global.h100ReadFreqAddr} B2
var freqWords = { global.arborRetVal }

if { var.freqWords == null || #var.freqWords < 1 }
    echo { "ArborCtl: H100 stopped responding to inputs." }
    if { exists(global.arborVFDCommReady) }
        set global.arborVFDCommReady[param.S] = false
    set global.arborState[param.S][4] = true
    M99

var vfdOutputDeciHz = { var.freqWords[0] }
var vfdSetDeciHz = { #var.freqWords > 1 ? var.freqWords[1] : var.freqWords[0] }
var currentFrequency = { var.vfdOutputDeciHz / 10 }
var vfdRunning = { var.vfdOutputDeciHz > 0 }
var lastDir = { global.arborVFDStatus[param.S][1] }
var vfdForward = { var.vfdRunning && var.lastDir == 1 }
var vfdReverse = { var.vfdRunning && var.lastDir == -1 }

var commandChange = false
var numPoles = { global.arborState[param.S][0][1] }
var maxFreq = { global.arborState[param.S][3][0] }
var minFreq = { global.arborState[param.S][3][1] }

; Stop as early as possible
if { !var.shouldRun && var.vfdRunning }
    M98 P"arborctl/delay-for-command.g"
    M260.1 P{param.C} A{param.A} F5 R{global.h100CoilStop} B{1,}
    M98 P"arborctl/delay-for-command.g"
    M260.1 P{param.C} A{param.A} F6 R{global.h100SetFreqAddr} B{0,}
    set var.commandChange = true
    set var.vfdRunning = false
    set var.lastDir = 0
elif { var.shouldRun }
    ; f = |RPM| * poles / 120 ; store as deci-Hz
    var cmdRpm = { abs(spindles[param.S].active) }
    var targetHz = { min(var.maxFreq, max(var.minFreq, (var.cmdRpm * var.numPoles) / 120)) }
    var newFreq = { ceil(var.targetHz) * 10 }

    if { var.vfdSetDeciHz != var.newFreq }
        echo { "ArborCtl: Setting spindle " ^ param.S ^ " to " ^ var.targetHz ^ " Hz" }
        echo { "ArborCtl: poles=" ^ var.numPoles ^ " cmdRPM=" ^ var.cmdRpm }
        M2600 E0 P{param.C} A{param.A} F6 R{global.h100SetFreqAddr} B{var.newFreq,}
        set var.commandChange = true

    if { spindles[param.S].state == "forward" && (!var.vfdRunning || !var.vfdForward) }
        M98 P"arborctl/delay-for-command.g"
        M260.1 P{param.C} A{param.A} F5 R{global.h100CoilFwd} B{1,}
        set var.commandChange = true
        set var.lastDir = 1
        set var.vfdForward = true
        set var.vfdReverse = false
        set var.vfdRunning = true
    elif { spindles[param.S].state == "reverse" && (!var.vfdRunning || !var.vfdReverse) }
        M98 P"arborctl/delay-for-command.g"
        M260.1 P{param.C} A{param.A} F5 R{global.h100CoilRev} B{1,}
        set var.commandChange = true
        set var.lastDir = -1
        set var.vfdReverse = true
        set var.vfdForward = false
        set var.vfdRunning = true

; RPM = 120 * f / poles
var currentRPM = { var.currentFrequency * 120 / var.numPoles }
var stableHz = { abs(spindles[param.S].active) * var.numPoles / 120 }
var isStable = { var.vfdRunning && abs(var.currentFrequency - var.stableHz) < 1.0 }

set global.arborState[param.S][2] = { global.arborVFDStatus[param.S] != null ? global.arborVFDStatus[param.S][4] : false }
set global.arborState[param.S][1] = { var.commandChange }
set global.arborState[param.S][4] = false

set global.arborVFDStatus[param.S][0] = { var.vfdRunning }
set global.arborVFDStatus[param.S][1] = { var.vfdRunning ? var.lastDir : 0 }
set global.arborVFDStatus[param.S][2] = { var.currentFrequency }
set global.arborVFDStatus[param.S][3] = { var.currentRPM }
set global.arborVFDStatus[param.S][4] = { var.isStable }

; No power register on FluidNC H100 map — leave watts at 0, load at 0
set global.arborVFDPower[param.S][0] = 0
set global.arborVFDPower[param.S][1] = 0
