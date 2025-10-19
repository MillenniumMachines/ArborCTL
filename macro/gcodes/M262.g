var kMaxRetries = 3

M98 P"arborctl/delay-for-command.g"

while {iterations < var.kMaxRetries}
    M260.1 P{param.P} A{param.A} F{param.F} R{param.R} B{param.B}
    M261.1 P{param.P} A{param.A} F3 R{param.R} B{#param.B} V"val"
    
    if { var.val == null || #var.val != #param.B}
        continue
    
    var different = false
    while {iterations < #param.B}
        if {var.val[iterations] != param.B[iterations]}
            set var.different = true
    
    if { !var.different }
        M99
