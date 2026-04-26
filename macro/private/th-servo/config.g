; th-servo/config.g - UART + Modbus probe (preliminary TH Servo)
;
; Same parameter contract as other ArborCtl config.g (B baud, C channel, A address,
; S spindle, W U V F I R motor, T E min/max Hz from wizard). Hz fields are unused
; for RPM-native servo control but are kept for G8001 / DWC compatibility.

if { !exists(param.A) }
    abort { "ArborCtl: TH Servo - No address specified!" }

if { !exists(param.B) }
    abort { "ArborCtl: TH Servo - No baud rate specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: TH Servo - No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: TH Servo - No spindle specified!" }

M575 P{param.C} B{param.B} S7

; Probe motor speed register (4096 / 0x1000) — same read as control.g
M98 P"arborctl/delay-for-command.g"
M2601 E0 P{param.C} A{param.A} F3 R{4096} B1
if { global.arborRetVal == null }
    echo { "ArborCtl: TH Servo (preliminary) - probe read failed on register 4096" }
    if { exists(global.arborVFDCommReady) }
        set global.arborVFDCommReady[param.S] = false
    M99

echo { "ArborCtl: TH Servo (preliminary) - probe OK on register 4096" }

if { exists(global.arborVFDCommReady) }
    set global.arborVFDCommReady[param.S] = true

echo { "ArborCtl: TH Servo (preliminary) - configuration complete for spindle " ^ param.S }
