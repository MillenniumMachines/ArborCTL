; M2601.g - M261 with retry logic implementation
; This file implements a retry wrapper for M261.1 RS485 communication commands
; It attempts communication up to 3 times before giving up
M98 P"arborctl/delay-for-command.g"

set global.arborRetVal = { null }

while {iterations < global.arborMaxRetries}

    M261.1 P{param.P} A{param.A} F{param.F} R{param.R} B{param.B} V"val"
    if { var.val != null }
        set global.arborRetVal = { var.val }
        M99

if { !exists(param.E) || param.E == 1 }
    echo { "M2601: Read from addr " ^ param.A ^ " reg " ^ param.R ^ " failed after " ^ global.arborMaxRetries ^ " attempts." }