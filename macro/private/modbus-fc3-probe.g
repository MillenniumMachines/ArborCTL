; modbus-fc3-probe.g - M575 + one Modbus RTU function 03 (read holding registers)
;
; Use from DWC "Test Modbus" for drives that probe with M2601 FC3 in config.g.
; Parameters: B baud, C UART channel, A slave address, R holding register address (decimal).

if { !exists(param.B) }
    abort { "ArborCtl: modbus-fc3-probe - No baud (B)!" }

if { !exists(param.C) }
    abort { "ArborCtl: modbus-fc3-probe - No channel (C)!" }

if { !exists(param.A) }
    abort { "ArborCtl: modbus-fc3-probe - No address (A)!" }

if { !exists(param.R) }
    abort { "ArborCtl: modbus-fc3-probe - No register (R)!" }

M575 P{param.C} B{param.B} S7

M98 P"arborctl/delay-for-command.g"

M2601 E0 P{param.C} A{param.A} F3 R{param.R} B1

if { global.arborRetVal == null }
    echo { "ArborCtl: FC3 probe FAILED — reg " ^ param.R ^ " (check baud, address, AUX port, termination)." }
    M99

echo { "ArborCtl: FC3 probe OK — reg " ^ param.R ^ " value " ^ global.arborRetVal }
