; modbus-fc3-probe.g - M575 + one Modbus RTU function 03 (read holding registers)
;
; Use from DWC "Test Modbus" for drives that probe with M2601 FC3 in config.g.
; Tries preferred channel C, then P2, P3, P1 (uart-channel-probe.g).
; Parameters: B baud, C UART channel, A slave address, R holding register address (decimal).

if { !exists(param.B) }
    abort { "ArborCtl: modbus-fc3-probe - No baud (B)!" }

if { !exists(param.C) }
    abort { "ArborCtl: modbus-fc3-probe - No channel (C)!" }

if { !exists(param.A) }
    abort { "ArborCtl: modbus-fc3-probe - No address (A)!" }

if { !exists(param.R) }
    abort { "ArborCtl: modbus-fc3-probe - No register (R)!" }

M98 P"arborctl/uart-channel-probe.g" B{param.B} C{param.C} A{param.A} R{param.R}

if { global.arborProbeChannel == null || global.arborRetVal == null }
    echo { "ArborCtl: FC3 probe FAILED — reg " ^ param.R ^ " (check baud, address, AUX port, termination)." }
    M99

echo { "ArborCtl: FC3 probe OK — channel P" ^ global.arborProbeChannel ^ " reg " ^ param.R ^ " value " ^ global.arborRetVal }
