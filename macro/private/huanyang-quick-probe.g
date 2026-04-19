; huanyang-quick-probe.g - Same first-step probe as huanyang-hy02d223b/config.g (M2604 raw frame)
;
; Huanyang does not use a simple FC3 read for initial probe; this matches config.g.
; Parameters: B baud, C UART channel, A slave address.

if { !exists(param.B) }
    abort { "ArborCtl: huanyang-quick-probe - No baud (B)!" }

if { !exists(param.C) }
    abort { "ArborCtl: huanyang-quick-probe - No channel (C)!" }

if { !exists(param.A) }
    abort { "ArborCtl: huanyang-quick-probe - No address (A)!" }

M575 P{param.C} B{param.B} S7

M98 P"arborctl/delay-for-command.g"

set global.arborRetVal = { null }

; Function 0x04 read — same as arborctl/huanyang-hy02d223b/config.g probe
M2604 P{param.C} A{param.A} B{{0x04, 0x03, 0x00, 0x00, 0x00}} R5

G4 P250

if { global.arborRetVal != null && #global.arborRetVal == 5 }
    echo { "ArborCtl: Huanyang probe OK (5-byte response)." }
    M99

echo { "ArborCtl: Huanyang probe FAILED (check baud, address, AUX port, wiring)." }
