; M261.9.g - M261 with retry logic implementation
; This file implements a retry wrapper for M261.1 RS485 communication commands
; It attempts communication up to 3 times before giving up

M98 P"arborctl/delay-for-command.g"

if { !exists(global.arborRetVal) }
    global arborRetVal = { null }

while {iterations < global.arborMaxRetries}
    M261.1 P{param.P} A{param.A} F{param.F} R{param.R} B{param.B} V"val"
    if { var.val != null }
        set global.arborRetVal = { var.val }
        M99
