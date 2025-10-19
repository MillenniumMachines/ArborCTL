var kMaxRetries = 3

M98 P"arborctl/delay-for-command.g"

if {!exists(global.returnVal)}
    global returnVal = null

while {iterations < var.kMaxRetries}
    M261.1 P{param.P} A{param.A} F{param.F} R{param.R} B{param.B} V"val"
    if { var.val != null }
        set global.returnVal = {var.val}
        M99
