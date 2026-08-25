; h100/settings.g - H100 VFD Modbus register map (FluidNC-compatible)
; Standard Modbus RTU — not Huanyang custom protocol.
;
; Coils (FC5): forward 0x0049, reverse 0x004A, stop 0x004B
; Holding (FC6): set frequency 0x0201 (deci-Hz = Hz * 10)
; Input (FC4): 0x0000 count 13 — Hz, set Hz, current, speed, DC, AC, …, power
; Holding (FC3): F005 max 0x0005, F011 min 0x000B (deci-Hz)
;
; Register literals live in control.g / config.g (OM ~8KB — not globals).
; Only h100Fc4Count stays global: FC4 word count (FluidNC default 2).

if { !exists(global.h100Fc4Count) }
    global h100Fc4Count = { vector(limits.spindles, 2) }
