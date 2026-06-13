; shihlin-sl3/restart.g - Shihlin SL3 VFD implementation
; This file implements a direct restart command for the Shihlin SL3 VFD

if { !exists(param.A) }
    abort { "ArborCtl: No address specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: No spindle specified!" }

var rebootAddr = 0x1101
var rebootValue = 0x9696

; Restart the VFD if in emergency
if { global.arborState[param.S][4] == true }
    M5
    echo { "Restarting spindle with "}
    M2600 E1 P{param.C} A{param.A} F6 R{var.rebootAddr} B{var.rebootValue}
    echo { "ArborCtl:  Restart issued! Params: C" ^ param.C ^ " A" ^ param.A }
