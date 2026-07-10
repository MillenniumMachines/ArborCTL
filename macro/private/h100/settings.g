; h100/settings.g - H100 VFD Modbus register map (FluidNC-compatible)
; Standard Modbus RTU — not Huanyang custom protocol.
;
; Coils (FC5): forward 0x0049, reverse 0x004A, stop 0x004B
; Holding (FC6): set frequency 0x0201 (deci-Hz = Hz * 10)
; Input (FC4): output frequency 0x0000 (2 regs, deci-Hz)
; Holding (FC3): F005 max 0x0005, F011 min 0x000B (deci-Hz)

if { !exists(global.h100CoilFwd) }
    global h100CoilFwd = 0x0049
    global h100CoilRev = 0x004A
    global h100CoilStop = 0x004B
    global h100SetFreqAddr = 0x0201
    global h100ReadFreqAddr = 0x0000
    global h100MaxFreqAddr = 0x0005
    global h100MinFreqAddr = 0x000B
