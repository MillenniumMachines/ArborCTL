; h100/control.g - H100 VFD implementation (standard Modbus RTU)
; FluidNC register map: FC5 coils for run/stop, FC6 for frequency, FC4 for readback.
; FC4 at 0x0000 also carries current/voltage/power (V1.8 input-register table).
;
; M2600 verifies with FC3 — do not use for FC5 coils or H100 FC6 set-Hz (0x0201).

if { !exists(param.A) }
    abort { "ArborCtl: No address specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: No spindle specified!" }

M98 P"arborctl/delay-for-command.g" S250

M98 P"arborctl/h100/settings.g"

; FluidNC H100 map as literals (not OM globals). See settings.g comments.
; Coils 0x0049/4A/4B = 73/74/75; set Hz 0x0201=513; FC4 0x0000; F005=5; F011=11.

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
    M2601 E0 P{param.C} A{param.A} F3 R5 B1
    var rawMax = { global.arborRetVal }
    M2601 E0 P{param.C} A{param.A} F3 R11 B1
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

; FC4 monitor at 0x0000. FluidNC uses B2 (Hz + set Hz). Wider counts often
; fail on clones and spam empty "Error: M261.1:" (RRF logs every failed read).
; Default/latch B2; load uses supplemental F4 R2 B4 below when needed.
var fc4Try = { global.h100Fc4Count[param.S] }
M2601 E0 P{param.C} A{param.A} F4 R0 B{var.fc4Try}
var freqWords = { global.arborRetVal }
if { (var.freqWords == null || #var.freqWords < 1) && var.fc4Try != 2 }
    set global.h100Fc4Count[param.S] = 2
    M2601 E0 P{param.C} A{param.A} F4 R0 B2
    set var.freqWords = { global.arborRetVal }

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
    M260.1 P{param.C} A{param.A} F5 R75 B{1,}
    M98 P"arborctl/delay-for-command.g"
    M260.1 P{param.C} A{param.A} F6 R513 B{0,}
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
        ; FC6 only — M2600 FC3 verify of 0x0201 fails on H100 (write-focused reg).
        M260.1 P{param.C} A{param.A} F6 R513 B{var.newFreq,}
        set var.commandChange = true

    if { spindles[param.S].state == "forward" && (!var.vfdRunning || !var.vfdForward) }
        M98 P"arborctl/delay-for-command.g"
        M260.1 P{param.C} A{param.A} F5 R73 B{1,}
        set var.commandChange = true
        set var.lastDir = 1
        set var.vfdForward = true
        set var.vfdReverse = false
        set var.vfdRunning = true
    elif { spindles[param.S].state == "reverse" && (!var.vfdRunning || !var.vfdReverse) }
        M98 P"arborctl/delay-for-command.g"
        M260.1 P{param.C} A{param.A} F5 R74 B{1,}
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
; 000A current fault (word 10) — pause-on-error like Shihlin/Yalang
if { #var.freqWords >= 11 && var.freqWords[10] > 0 }
    set global.arborState[param.S][4] = true

set global.arborVFDStatus[param.S][0] = { var.vfdRunning }
set global.arborVFDStatus[param.S][1] = { var.vfdRunning ? var.lastDir : 0 }
set global.arborVFDStatus[param.S][2] = { var.currentFrequency }
set global.arborVFDStatus[param.S][3] = { var.currentRPM }
set global.arborVFDStatus[param.S][4] = { var.isStable }

; Load from FC4 current (0.1 A) / AC V (0.1 V); native 000C power if plausible.
; Two-word FC4 (FluidNC) needs supplemental F4 R2 B4 for current when running.
var loadWords = { null }
var haveLoadData = { #var.freqWords >= 3 }
if { !var.haveLoadData && var.vfdRunning && #var.freqWords == 2 }
    M2601 E0 P{param.C} A{param.A} F4 R2 B4
    set var.loadWords = { global.arborRetVal }
    if { var.loadWords != null && #var.loadWords >= 1 }
        set var.haveLoadData = { true }
set global.arborVFDPower[param.S][0] = 0
set global.arborVFDPower[param.S][1] = 0
if { var.vfdRunning && var.haveLoadData }
    var outputCurrent = { 0 }
    if { #var.freqWords >= 3 }
        set var.outputCurrent = { var.freqWords[2] / 10 }
    elif { var.loadWords != null && #var.loadWords >= 1 }
        set var.outputCurrent = { var.loadWords[0] / 10 }
    var acVoltage = { global.arborState[param.S][0][2] }
    if { #var.freqWords >= 6 && var.freqWords[5] > 0 }
        set var.acVoltage = { var.freqWords[5] / 10 }
    elif { var.loadWords != null && #var.loadWords >= 4 && var.loadWords[3] > 0 }
        set var.acVoltage = { var.loadWords[3] / 10 }
    var ratedW = { global.arborState[param.S][0][0] * 1000 }
    var ratedA = { global.arborState[param.S][0][4] }
    var pwrWatts = { sqrt(3) * var.acVoltage * var.outputCurrent * 0.8 }
    if { #var.freqWords >= 13 && var.freqWords[12] > 0 && var.pwrWatts > 0 }
        var nPwr = { var.freqWords[12] * 100 }
        if { var.nPwr > var.ratedW * 2 }
            set var.nPwr = { var.freqWords[12] }
        var nLo = { var.pwrWatts * 0.25 }
        var nHi = { var.ratedW * 2 }
        var nativeOk = { var.nPwr >= var.nLo && var.nPwr <= var.nHi }
        if { var.nativeOk }
            set var.pwrWatts = { var.nPwr }
    if { var.pwrWatts > 0 }
        set global.arborVFDPower[param.S][0] = { var.pwrWatts }
    if { var.pwrWatts > 0 && var.ratedW > 0 }
        var loadPct = { min((var.pwrWatts / var.ratedW) * 100, 100) }
        set global.arborVFDPower[param.S][1] = { var.loadPct }
    elif { var.pwrWatts <= 0 && var.outputCurrent > 0 && var.ratedA > 0 }
        var loadPctI = { min((var.outputCurrent / var.ratedA) * 100, 100) }
        set global.arborVFDPower[param.S][1] = { var.loadPctI }
