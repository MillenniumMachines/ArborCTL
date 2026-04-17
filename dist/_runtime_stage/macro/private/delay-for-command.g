; delay-for-command.g - ArborCtl RS485 communication delay
; This file delays for long enough to account for the VFDs maximum RS485 command rate

var cmdWait = { (exists(param.S) && param.S !== null) ? param.S : 10 }

if { !exists(global.arborLast485Send) }
    global arborLast485Send = { 0 }

var earliest485Send = { global.arborLast485Send + var.cmdWait }
var now = { state.upTime * 1000 + state.msUpTime }
var timeToWait = { var.earliest485Send - var.now }

if { var.timeToWait > 0 }
    G4 P{var.timeToWait}

set global.arborLast485Send = { state.upTime * 1000 + state.msUpTime }
