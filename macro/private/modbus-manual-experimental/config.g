; modbus-manual-experimental/config.g - UART + optional Modbus probe (experimental)
;
; Same parameter contract as other ArborCtl config.g files (B baud, C channel, A address,
; S spindle, W U V F I R motor, T E min/max Hz from wizard).
;
; Requires global.arborModbusManualSpec[S] to be a vector of 11 integers (see doc).

if { !exists(param.A) }
    abort { "ArborCtl: Manual Modbus - No address specified!" }

if { !exists(param.B) }
    abort { "ArborCtl: Manual Modbus - No baud rate specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: Manual Modbus - No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: Manual Modbus - No spindle specified!" }

if { exists(param.U) && exists(param.F) && exists(param.R) }
    M98 P"arborctl/check-motor-nameplate.g" U{param.U} F{param.F} R{param.R}

; Pause daemon polling while config / probe runs.
if { exists(global.arborVFDCommReady) }
    set global.arborVFDCommReady[param.S] = false

M575 P{param.C} B{param.B} S7

if { !exists(global.arborModbusManualSpec) || global.arborModbusManualSpec[param.S] == null }
    echo { "ArborCtl: Manual Modbus (experimental) - arborModbusManualSpec[" ^ param.S ^ "] is not set. Configure register map first." }
    M99

if { #global.arborModbusManualSpec[param.S] != 11 }
    abort { "ArborCtl: Manual Modbus - arborModbusManualSpec[" ^ param.S ^ "] must have exactly 11 integers. See doc/modbus-manual-experimental.md" }

var m = { global.arborModbusManualSpec[param.S] }
var rProbe = { var.m[10] }

if { var.rProbe >= 0 }
    M98 P"arborctl/uart-channel-probe.g" B{param.B} C{param.C} A{param.A} R{var.rProbe} S{param.S} W{250}
    if { global.arborProbeChannel == null || global.arborRetVal == null }
        echo { "ArborCtl: Manual Modbus (experimental) - probe read failed on register " ^ var.rProbe }
        M99
    echo { "ArborCtl: Manual Modbus (experimental) - probe OK on register " ^ var.rProbe ^ " channel P" ^ global.arborProbeChannel }

if { exists(global.arborVFDCommReady) }
    set global.arborVFDCommReady[param.S] = true

echo { "ArborCtl: Manual Modbus (experimental) - configuration complete for spindle " ^ param.S }
