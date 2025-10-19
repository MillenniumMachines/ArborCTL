; delay-for-command.g - ArborCtl RS485 communication delay
; This file delays for long enough to account for the VFDs maximum RS485 command rate

var kDefaultCmdWait = 10

var cmdWait = { var.kDefaultCmdWait }

if {exists(param.S)}
    set var.cmdWait = { param.S }

if {!exists(global.lastRS485Send)}
    global lastRS485Send = 0

var rs485EarliestSendTime = { global.lastRS485Send + var.cmdWait }
var now = { state.upTime * 1000 + state.msUpTime }
var timeToWait = { var.rs485EarliestSendTime - var.now }

if { var.timeToWait > 0 }
    G4 P{var.timeToWait}

set global.lastRS485Send = state.upTime * 1000 + state.msUpTime
