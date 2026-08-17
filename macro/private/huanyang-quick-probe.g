; huanyang-quick-probe.g - Same probe as huanyang-hy02d223b/config.g (M2604 raw frame)
;
; Tries preferred channel C, then P2, P3, P1. Huanyang does not use FC3 for initial probe.
; Parameters: B baud, C UART channel, A slave address.

if { !exists(param.B) }
    abort { "ArborCtl: huanyang-quick-probe - No baud (B)!" }

if { !exists(param.C) }
    abort { "ArborCtl: huanyang-quick-probe - No channel (C)!" }

if { !exists(param.A) }
    abort { "ArborCtl: huanyang-quick-probe - No address (A)!" }

if { !exists(global.arborProbeChannel) }
    global arborProbeChannel = null
else
    set global.arborProbeChannel = null

set global.arborRetVal = null

var prefChannel = { param.C }
var probeOk = false
var workChannel = { param.C }

var channelCandidates = { vector(4, 0) }
set var.channelCandidates[0] = var.prefChannel
set var.channelCandidates[1] = 2
set var.channelCandidates[2] = 3
set var.channelCandidates[3] = 1

var probeIdx = 0
while { var.probeIdx < #var.channelCandidates && !var.probeOk }
    var tryChannel = { var.channelCandidates[var.probeIdx] }
    if { var.probeIdx > 0 && var.tryChannel == var.prefChannel }
        set var.probeIdx = { var.probeIdx + 1 }
        continue

    M575 P{var.tryChannel} B{param.B} S7
    M98 P"arborctl/delay-for-command.g" S250
    set global.arborRetVal = { null }
    M2604 P{var.tryChannel} A{param.A} B{{0x04, 0x03, 0x00, 0x00, 0x00}} R5
    G4 P250

    if { global.arborRetVal != null && #global.arborRetVal == 5 }
        set var.probeOk = true
        set var.workChannel = var.tryChannel

    set var.probeIdx = { var.probeIdx + 1 }

if { !var.probeOk }
    set global.arborProbeChannel = null
    echo { "ArborCtl: Huanyang probe FAILED (check baud, address, AUX port, wiring)." }
    M99

set global.arborProbeChannel = var.workChannel
echo { "ArborCtl: Huanyang probe OK (5-byte response) on channel P" ^ var.workChannel }
