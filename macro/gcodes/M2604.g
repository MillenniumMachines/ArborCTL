; M2604.g - Resilient M260.4 wrapper for Huanyang (non-standard) serial protocol
;
; When the VFD does not respond, M260.4 throws a hard error that aborts any
; calling macro.  Because this file lives in sys/ as a gcode macro, the error
; terminates only this gcode invocation, and the caller can inspect
; global.arborRetVal (null on failure) without crashing.
;
; V"resp" creates a new file-scope local. Do not declare var resp first
; (already exists). Do not wrap V"resp" / var.resp in if/while: RRF EndScope
; plus DSF local cleanup throws "unknown variable 'resp'" on every tick.
;
; Parameters:
;   P - UART channel
;   A - VFD address
;   B - Byte array to send
;   R - Expected response length (omit or 0 for fire-and-forget writes)

M98 P"arborctl/delay-for-command.g"

set global.arborRetVal = null

if { !exists(param.R) || param.R <= 0 }
    M260.4 P{param.P} A{param.A} B{param.B}
    M99

M260.4 P{param.P} A{param.A} B{param.B} R{param.R} V"resp"
set global.arborRetVal = var.resp
