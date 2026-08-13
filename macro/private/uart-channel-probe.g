; uart-channel-probe.g - M575 + FC3 probe across UART channel candidates
;
; Tries preferred channel C first, then P2, P3, P1 (RRF 3.7 UARTs before USB). On success:
;   - global.arborProbeChannel = working UART device number
;   - global.arborRetVal = FC3 read result (same as M2601)
;   - if S given and arborVFDConfig[S] set, updates [1] and may append user-vars
; On failure: arborProbeChannel = null, arborRetVal = null
;
; Parameters:
;   B - baud
;   C - preferred UART channel
;   A - Modbus slave address
;   R - holding register (decimal) for FC3 read of 1 register
;   S - optional spindle index (persist channel into arborVFDConfig)
;   W - optional inter-try wait ms (default 250)

if { !exists(param.B) }
    abort { "ArborCtl: uart-channel-probe - No baud (B)!" }

if { !exists(param.C) }
    abort { "ArborCtl: uart-channel-probe - No channel (C)!" }

if { !exists(param.A) }
    abort { "ArborCtl: uart-channel-probe - No address (A)!" }

if { !exists(param.R) }
    abort { "ArborCtl: uart-channel-probe - No register (R)!" }

if { !exists(global.arborProbeChannel) }
    global arborProbeChannel = null
else
    set global.arborProbeChannel = null

set global.arborRetVal = null

var waitMs = { exists(param.W) ? param.W : 250 }
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
    M98 P"arborctl/delay-for-command.g" S{var.waitMs}
    M2601 E0 P{var.tryChannel} A{param.A} F3 R{param.R} B1

    if { global.arborRetVal != null }
        set var.probeOk = true
        set var.workChannel = var.tryChannel

    set var.probeIdx = { var.probeIdx + 1 }

if { !var.probeOk }
    set global.arborProbeChannel = null
    set global.arborRetVal = null
    M99

set global.arborProbeChannel = var.workChannel

; Keep arborRetVal from the successful M2601 above.

if { exists(param.S) && exists(global.arborVFDConfig) }
    if { global.arborVFDConfig[param.S] != null }
        set global.arborVFDConfig[param.S][1] = var.workChannel
        if { fileexists("0:/sys/arborctl-user-vars.g") && var.workChannel != param.C }
            echo >>"arborctl-user-vars.g" ""
            echo >>"arborctl-user-vars.g" "; ArborCtl auto-corrected UART channel after FC3 probe"
            var cfgLine = { "set global.arborVFDConfig[" ^ param.S ^ "] = {" }
            set var.cfgLine = { var.cfgLine ^ global.arborVFDConfig[param.S][0] }
            set var.cfgLine = { var.cfgLine ^ ", " ^ var.workChannel ^ ", " ^ param.A }
            set var.cfgLine = { var.cfgLine ^ "} ; Auto-corrected channel" }
            echo >>"arborctl-user-vars.g" { var.cfgLine }
            echo { "ArborCtl: Auto-corrected UART channel to P" ^ var.workChannel }
