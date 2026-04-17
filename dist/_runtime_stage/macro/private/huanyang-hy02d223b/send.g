; huanyang-hy02d223b/send.g - Resilient M260.4 wrapper for Huanyang protocol
;
; Because the Huanyang HY02D223B uses a non-standard serial protocol (not
; Modbus), we use M260.4 instead of M261.1.  When the VFD does not respond,
; M260.4 throws a hard error that aborts the calling macro.  By isolating
; the call inside this sub-macro (invoked via M98), the error only aborts
; *this* file and the caller can check global.arborRetVal afterwards.
;
; Parameters (note: P is consumed by M98, so the UART channel uses C)
;   C - UART channel
;   A - VFD address
;   B - Byte array to send
;   R - Expected response length (omit or 0 for fire-and-forget writes)

M98 P"arborctl/delay-for-command.g"

set global.arborRetVal = null

if { exists(param.R) && param.R > 0 }
    M260.4 P{param.C} A{param.A} B{param.B} R{param.R} V"resp"
    if { exists(var.resp) && var.resp != null }
        set global.arborRetVal = var.resp
else
    M260.4 P{param.C} A{param.A} B{param.B}
