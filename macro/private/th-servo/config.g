; th-servo/config.g - UART + Modbus probe (preliminary TH Servo)
;
; Same parameter contract as other ArborCtl config.g (B baud, C channel, A address,
; S spindle, W U V F I R motor, T E min/max Hz from DWC). Hz fields are unused
; for RPM-native servo control but are kept for cross-driver parameter parity.

if { !exists(param.A) }
    abort { "ArborCtl: TH Servo - No address specified!" }

if { !exists(param.B) }
    abort { "ArborCtl: TH Servo - No baud rate specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: TH Servo - No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: TH Servo - No spindle specified!" }

if { exists(param.U) && exists(param.F) && exists(param.R) }
    M98 P"arborctl/check-motor-nameplate.g" U{param.U} F{param.F} R{param.R}

; Pause daemon polling while config / probe runs.
if { exists(global.arborVFDCommReady) }
    set global.arborVFDCommReady[param.S] = false

; Probe motor speed register (4096 / 0x1000) — channel fallback C,2,3,1
M98 P"arborctl/uart-channel-probe.g" B{param.B} C{param.C} A{param.A} R{4096} S{param.S} W{250}
if { global.arborProbeChannel == null || global.arborRetVal == null }
    echo { "ArborCtl: TH Servo (preliminary) - probe read failed on register 4096" }
    M99

echo { "ArborCtl: TH Servo (preliminary) - probe OK on register 4096 channel P" ^ global.arborProbeChannel }

if { exists(global.arborVFDCommReady) }
    set global.arborVFDCommReady[param.S] = true

echo { "ArborCtl: TH Servo (preliminary) - configuration complete for spindle " ^ param.S }
