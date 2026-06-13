; shihlin-sl3/estop.g - Shihlin SL3 VFD implementation
; This file implements a direct stop command for the Shihlin SL3 VFD

if { !exists(param.A) }
    abort { "ArborCtl: No address specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: No spindle specified!" }

var statusAddr   = 4097

M5
M2600 E0 P{param.C} A{param.A} F6 R{var.statusAddr} B{0,}
M2600 E0 P{param.C} A{param.A} F6 R{var.freqAddr} B{0,}
echo { "ArborCtl:  Emergency VFD stop issued! Params: C" ^ param.C ^ " A" ^ param.A }
