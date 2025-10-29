; M2600.g - Reliable VFD write with verification
; This macro sends data to the VFD and verifies it was written correctly by reading it back
; Retries up to 3 times until the written data matches the intended data

M98 P"arborctl/delay-for-command.g"

while { iterations < global.arborMaxRetries }
    M260.1 P{param.P} A{param.A} F{param.F} R{param.R} B{param.B}
    M261.1 P{param.P} A{param.A} F3 R{param.R} B{#param.B} V"val"

    if { !exists(var.val) || var.val == null || #var.val != #param.B}
        continue

    var different = { false }
    while { iterations < #param.B }
        if { var.val[iterations] != param.B[iterations] }
            set var.different = { true }
            break

    if { !var.different }
        M99

if { !exists(param.E) || param.E == 1 }
    echo { "M2600: Write to addr " ^ param.A ^ " reg " ^ param.R ^ " failed after " ^ global.arborMaxRetries ^ " attempts." }