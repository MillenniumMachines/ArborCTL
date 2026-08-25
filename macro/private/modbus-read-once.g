; modbus-read-once.g - Single M261.1 read into global.arborRetVal
;
; V"val" creates a new file-scope local. Do not declare var val first
; (already exists). Do not wrap V"val" / var.val in if/while: RRF EndScope
; plus DSF local cleanup throws "unknown variable 'val'" on every tick.
;
; Parameters:
;   S - UART channel (M98 reserves P for filename)
;   A - Modbus address
;   F - Function code
;   R - Register address
;   B - Byte/word count

set global.arborRetVal = null
M261.1 P{param.S} A{param.A} F{param.F} R{param.R} B{param.B} V"val"
set global.arborRetVal = var.val
