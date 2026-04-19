; modbus-manual-experimental/control.g - User-defined Modbus RTU holding registers (experimental)
;
; Requires global.arborModbusManualSpec[S] (11 ints). See doc/modbus-manual-experimental.md.
; Uses M2600/M2601 wrappers (same Modbus path as Shihlin SL3).

if { !exists(param.A) }
    abort { "ArborCtl: Manual Modbus - No address specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: Manual Modbus - No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: Manual Modbus - No spindle specified!" }

if { !exists(global.arborModbusManualSpec) || global.arborModbusManualSpec[param.S] == null }
    abort { "ArborCtl: Manual Modbus - arborModbusManualSpec[" ^ param.S ^ "] not configured!" }

if { #global.arborModbusManualSpec[param.S] != 11 }
    abort { "ArborCtl: Manual Modbus - spec must have 11 integers (see doc)" }

var m = { global.arborModbusManualSpec[param.S] }
var rWf = { var.m[0] }
var rCmd = { var.m[1] }
var rRf = { var.m[2] }
var vFwd = { var.m[3] }
var vRev = { var.m[4] }
var vStop = { var.m[5] }
var wn = { var.m[6] }
var wd = { var.m[7] }
var rn = { var.m[8] }
var rd = { var.m[9] }

if { var.wd == 0 || var.rd == 0 }
    abort { "ArborCtl: Manual Modbus - scale denominators must be non-zero!" }

; --- Motor / limits from wizard (same pattern as Huanyang fallback) ---
if { global.arborState[param.S][0] == null }
    if { exists(global.arborMotorSpec) && global.arborMotorSpec[param.S] != null && exists(global.arborWizardFreqLimits) && global.arborWizardFreqLimits[param.S] != null }
        var wms = global.arborMotorSpec[param.S]
        var wfl = global.arborWizardFreqLimits[param.S]
        var motorCfg = { vector(6, 0) }
        set var.motorCfg[0] = var.wms[0]
        set var.motorCfg[1] = var.wms[1]
        set var.motorCfg[2] = var.wms[2]
        set var.motorCfg[3] = var.wms[3]
        set var.motorCfg[4] = var.wms[4]
        set var.motorCfg[5] = var.wms[5]
        var freqConv = { vector(1, 1.0) }
        set global.arborState[param.S][0] = { var.motorCfg, var.freqConv, 0 }
        set global.arborState[param.S][3] = { var.wfl[0], var.wfl[1] }
        echo { "ArborCtl: Manual Modbus (experimental) motor data from wizard." }
    else
        abort { "ArborCtl: Manual Modbus - configure motor + Hz limits (G8001 / DWC) first." }

if { global.arborVFDStatus[param.S] == null }
    set global.arborVFDStatus[param.S] = { vector(5, 0) }

if { global.arborVFDPower[param.S] == null }
    set global.arborVFDPower[param.S] = { vector(2, 0) }

var numPoles = { global.arborState[param.S][0][0][1] }
var minHz = { global.arborState[param.S][3][0] }
var maxHz = { global.arborState[param.S][3][1] }

var shouldRun = { (spindles[param.S].state == "forward" || spindles[param.S].state == "reverse") && spindles[param.S].active > 0 }

; Target Hz from RRF spindle RPM
var targetHz = { 0 }
if { var.shouldRun }
    set var.targetHz = { min(var.maxHz, max(var.minHz, (abs(spindles[param.S].current) * var.numPoles) / 120)) }

var rawSet = { 0 }
if { var.shouldRun }
    set var.rawSet = { min(65535, max(0, floor(abs(spindles[param.S].current) * var.wn / var.wd))) }

; --- Read feedback frequency register (optional); else use commanded raw ---
var rawFb = { var.rawSet }
if { var.rRf > 0 }
    M98 P"arborctl/delay-for-command.g"
    M2601 E0 P{param.C} A{param.A} F3 R{var.rRf} B1
    if { global.arborRetVal != null && #global.arborRetVal >= 1 }
        set var.rawFb = { global.arborRetVal[0] }
elif { exists(global.arborModbusManualLastRaw) && global.arborModbusManualLastRaw[param.S] != null }
    set var.rawFb = { global.arborModbusManualLastRaw[param.S] }

var outHz = { var.rawFb * var.rn / var.rd }
var outRpm = { var.outHz * 120 / var.numPoles }

var vfdRunning = { var.outHz > 0.05 }
var dir = { 0 }
if { spindles[param.S].state == "forward" && var.shouldRun }
    set var.dir = { 1 }
elif { spindles[param.S].state == "reverse" && var.shouldRun }
    set var.dir = { -1 }

var freqStable = { abs(var.outHz - var.targetHz) < max(0.25, var.targetHz * 0.05) || !var.shouldRun }

; --- Stop ---
if { !var.shouldRun }
    M98 P"arborctl/delay-for-command.g"
    M2600 E0 P{param.C} A{param.A} F6 R{var.rWf} B{0,}
    M98 P"arborctl/delay-for-command.g"
    M2600 E0 P{param.C} A{param.A} F6 R{var.rCmd} B{var.vStop,}
    set global.arborModbusManualLastRaw[param.S] = { 0 }
    set global.arborState[param.S][1] = { true }
    set global.arborVFDStatus[param.S][0] = { false }
    set global.arborVFDStatus[param.S][1] = { 0 }
    set global.arborVFDStatus[param.S][2] = { 0 }
    set global.arborVFDStatus[param.S][3] = { 0 }
    set global.arborVFDStatus[param.S][4] = { true }
    M99

; --- Run: write frequency then direction command ---
M98 P"arborctl/delay-for-command.g"
M2600 E0 P{param.C} A{param.A} F6 R{var.rWf} B{var.rawSet,}
set global.arborModbusManualLastRaw[param.S] = { var.rawSet }

var cmdVal = { var.vStop }
if { spindles[param.S].state == "forward" }
    set var.cmdVal = { var.vFwd }
elif { spindles[param.S].state == "reverse" }
    set var.cmdVal = { var.vRev }

M98 P"arborctl/delay-for-command.g"
M2600 E0 P{param.C} A{param.A} F6 R{var.rCmd} B{var.cmdVal,}
set global.arborState[param.S][1] = { true }

set global.arborVFDStatus[param.S][0] = { var.vfdRunning }
set global.arborVFDStatus[param.S][1] = { var.dir }
set global.arborVFDStatus[param.S][2] = { var.outHz }
set global.arborVFDStatus[param.S][3] = { var.outRpm }
set global.arborVFDStatus[param.S][4] = { var.freqStable }

set global.arborState[param.S][2] = { global.arborVFDStatus[param.S][4] }
set global.arborVFDPower[param.S][0] = { 0 }
set global.arborVFDPower[param.S][1] = { 0 }
