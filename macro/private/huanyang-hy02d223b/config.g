; huanyang-hy02d223b/config.g - Huanyang HY02D223B VFD configuration
; This file implements parameter configuration for the Huanyang HY02D223B VFD.
;
; Parameters:
; A - Modbus / RS485 address
; B - Baud rate
; C - Communication channel (UART port)
; S - Spindle ID to configure
; T - Spindle minimum frequency (Hz)
; E - Spindle maximum frequency (Hz)
; W - Motor rated power (kW)
; U - Motor poles (2, 4, 6, 8)
; V - Motor rated voltage (V)
; F - Motor rated frequency (Hz)
; I - Motor rated current (A)
; R - Motor rated rotation speed (RPM)
; D - Reset to factory defaults (1) or not (0) - not currently implemented for HY02D223B

if { !exists(param.A) }
    abort { "ArborCtl: Huanyang HY02D223B - No address specified!" }

if { !exists(param.B) }
    abort { "ArborCtl: Huanyang HY02D223B - No baud rate specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: Huanyang HY02D223B - No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: Huanyang HY02D223B - No spindle specified!" }

if { !exists(param.T) }
    abort { "ArborCtl: Huanyang HY02D223B - No spindle minimum frequency specified!" }

if { !exists(param.E) }
    abort { "ArborCtl: Huanyang HY02D223B - No spindle maximum frequency specified!" }

if { param.T > param.E }
    abort { "ArborCtl: Huanyang HY02D223B - Spindle minimum frequency cannot be greater than maximum frequency!" }

if { param.E > 400 }
    abort { "ArborCtl: Huanyang HY02D223B - Spindle maximum frequency " ^ param.E ^ " cannot be greater than 400Hz." }

if { param.T < 0 || param.E < 0 }
    abort { "ArborCtl: Huanyang HY02D223B - Spindle minimum and maximum frequency must be positive!" }

if { !exists(param.W) }
    abort { "ArborCtl: Huanyang HY02D223B - No motor rated power specified!" }

if { !exists(param.U) }
    abort { "ArborCtl: Huanyang HY02D223B - No motor poles specified!" }

if { !exists(param.V) }
    abort { "ArborCtl: Huanyang HY02D223B - No motor rated voltage specified!" }

if { !exists(param.F) || param.F <= 0 }
    abort { "ArborCtl: Huanyang HY02D223B - No valid motor rated frequency specified!" }

if { !exists(param.I) }
    abort { "ArborCtl: Huanyang HY02D223B - No motor rated current specified!" }

if { !exists(param.R) || param.R <= 0 }
    abort { "ArborCtl: Huanyang HY02D223B - No valid motor rotation speed specified!" }

var baudRateValue = { param.B == 4800 ? 0 : param.B == 9600 ? 1 : param.B == 19200 ? 2 : param.B == 38400 ? 3 : -1 }
if { var.baudRateValue == -1 }
    abort { "ArborCtl: Huanyang HY02D223B - Invalid baud rate specified. Supported baud rates are 4800, 9600, 19200, and 38400." }

if { exists(param.D) && param.D == 1 }
    echo { "ArborCtl: Huanyang HY02D223B - Factory reset over RS485 is not implemented. Continuing without reset." }

; Load the settings file which will define global.hy02d223bConfigParams
M98 P"arborctl/huanyang-hy02d223b/settings.g" A{param.A} B{param.B} W{param.W} U{param.U} V{param.V} F{param.F} I{param.I} R{param.R} T{param.T} E{param.E}

var waitTime = 250

; Configure UART port with the selected baud rate
M575 P{param.C} B{param.B} S7

; Active communication channel for this session. If probing discovers
; that the selected channel is wrong, this is updated automatically.
var commChannel = { param.C }

; Probe the VFD using M2604 (system gcode wrapper around M260.4 that
; isolates communication errors so they don't abort this macro)
var vfdCommReady = null

while { var.vfdCommReady == null }
    ; Try selected channel first, then fallback channels. This avoids
    ; lockout if the selected AUX port index doesn't match the board mapping.
    var channelCandidates = { vector(3, 0) }
    set var.channelCandidates[0] = var.commChannel
    set var.channelCandidates[1] = 1
    set var.channelCandidates[2] = 2

    var probeSuccess = false
    var probeIdx = 0
    while { var.probeIdx < #var.channelCandidates && !var.probeSuccess }
        var tryChannel = { var.channelCandidates[var.probeIdx] }
        if { var.probeIdx > 0 && var.tryChannel == var.commChannel }
            set var.probeIdx = { var.probeIdx + 1 }
            continue

        M575 P{var.tryChannel} B{param.B} S7
        ; Huanyang function 0x04 = read control/status (set frequency register).
        ; Some VFDs respond here while function 0x01 (PD parameter read) does not
        ; during initial probe — same frame as runtime polling in control.g.
        M2604 P{var.tryChannel} A{param.A} B{{0x04, 0x03, 0x00, 0x00, 0x00}} R5
        G4 P{var.waitTime}

        if { global.arborRetVal != null && #global.arborRetVal == 5 }
            set var.probeSuccess = true
            set var.commChannel = var.tryChannel

        set var.probeIdx = { var.probeIdx + 1 }

    if { var.probeSuccess }
        set var.vfdCommReady = true
        ; Mark this spindle as communication-ready so the daemon can call control.g
        if { exists(global.arborVFDCommReady) }
            set global.arborVFDCommReady[param.S] = true
        if { exists(global.arborVFDConfig) && global.arborVFDConfig[param.S] != null }
            ; Persist detected channel in-memory for this session.
            set global.arborVFDConfig[param.S][1] = var.commChannel
            ; Persist to user vars so next reboot uses the corrected channel.
            if { fileexists("0:/sys/arborctl-user-vars.g") && var.commChannel != param.C }
                echo >>"arborctl-user-vars.g" ""
                echo >>"arborctl-user-vars.g" "; ArborCtl auto-corrected UART channel after successful Huanyang probe"
                echo >>"arborctl-user-vars.g" {"set global.arborVFDConfig[" ^ param.S ^ "] = {" ^ global.arborVFDConfig[param.S][0] ^ ", " ^ var.commChannel ^ ", " ^ param.A ^ "} ; Auto-corrected channel"}
                echo { "ArborCtl: Huanyang HY02D223B - Auto-corrected UART channel to P" ^ var.commChannel }
    else
        var hyTitle = "ArborCtl: Huanyang HY02D223B Setup"
        var promptNoComms = "Unable to communicate with the Huanyang HY02D223B VFD. Check RS485 wiring, address <b>" ^ param.A ^ "</b>, and baud <b>" ^ param.B ^ "</b>.<br/><br/>On the VFD panel set RS485: typically <b>PD163</b> address, <b>PD164</b> baud, <b>PD165</b>=3 (RTU 8N1), <b>PD001</b>=2, <b>PD002</b>=2. Full notes: <b>doc/hy02d223b-protocol-notes.md</b> in the ArborCTL repo.<br/><br/>Power-cycle the VFD, then press OK to retry probing."
        M291 P{var.promptNoComms} R{var.hyTitle} S3 T0 J2
        if { result == -1 }
            abort { "ArborCtl: Operator aborted configuration wizard!" }

echo { "ArborCtl: Huanyang HY02D223B - Communication established" }
echo { "ArborCtl: Huanyang HY02D223B - Starting VFD configuration process with " ^ #global.hy02d223bConfigParams ^ " parameters" }

var statusVector = { vector(#global.hy02d223bConfigParams, false) }
var idx = 0
while { var.idx < #global.hy02d223bConfigParams }
    var configItem = { global.hy02d223bConfigParams[var.idx] }
    var reg = { var.configItem[0] }
    var width = { var.configItem[1] }
    var value = { var.configItem[2] }
    var allCorrect = false
    var writeHigh = { floor(var.value / 256) }
    var writeLow = { var.value - (var.writeHigh * 256) }

    echo { "ArborCtl: Huanyang HY02D223B - Writing PD" ^ var.reg ^ " = " ^ var.value }

    ; Write parameter via M2604
    if { var.width == 1 }
        M2604 P{var.commChannel} A{param.A} B{{0x02, 0x02, var.reg, var.value}} R4
    elif { var.width == 2 }
        M2604 P{var.commChannel} A{param.A} B{{0x02, 0x03, var.reg, var.writeHigh, var.writeLow}} R5
    else
        abort { "ArborCtl: Huanyang HY02D223B - Invalid config width for PD" ^ var.reg ^ "!" }
    G4 P{var.waitTime}

    ; Many Huanyang clones respond to function 0x04 (status) but not to
    ; function 0x01 (PD read).  Treat write-ack as success from M2604 (any
    ; non-empty response; width 1 -> R4, width 2 -> R5).
    if { global.arborRetVal != null && #global.arborRetVal >= 4 }
        set var.allCorrect = true
    else
        echo { "ArborCtl: Huanyang HY02D223B - Write failed for PD" ^ var.reg }

    set var.statusVector[var.idx] = { var.allCorrect }
    echo { "ArborCtl: Huanyang HY02D223B - PD" ^ var.reg ^ " result: " ^ (var.allCorrect ? "Success" : "Failed") }
    set var.idx = { var.idx + 1 }

var successCount = 0
set var.idx = 0
while { var.idx < #var.statusVector }
    if { var.statusVector[var.idx] }
        set var.successCount = { var.successCount + 1 }
    set var.idx = { var.idx + 1 }

if { var.successCount > 0 }
    set global.arborState[param.S][0] = null
    set global.arborState[param.S][3] = null
    set global.arborState[param.S][1] = false
    set global.arborState[param.S][2] = false
    set global.arborState[param.S][4] = false
    set global.arborVFDStatus[param.S] = null
    set global.arborVFDPower[param.S] = null
    ; Do not clear global.arborMotorSpec — wizard data is needed so control.g
    ; can skip PD reads (0x01) on clones that do not support them.

if { var.successCount == 0 }
    var failMsg = "VFD Configuration <b>failed</b>.<br/>No HY02D223B parameters were set successfully."
    M291 P{var.failMsg} R"ArborCtl: Huanyang HY02D223B" S0 T5
elif { var.successCount < #global.hy02d223bConfigParams }
    echo { "ArborCtl: Huanyang HY02D223B - Warning: Some parameters could not be set." }
    var partialMsg = { "VFD Configuration <b>partially successful</b>.<br/>" ^ var.successCount ^ " of " ^ #global.hy02d223bConfigParams ^ " set." }
    M291 P{var.partialMsg} R"ArborCtl: Huanyang HY02D223B" S0 T5
else
    var okMsg = { "VFD Configuration <b>successful</b>.<br/>All " ^ var.successCount ^ " parameters were set." }
    M291 P{var.okMsg} R"ArborCtl: Huanyang HY02D223B" S0 T5
    M291 P"Configuration complete. Power-cycle the VFD before relying on updated settings." R"ArborCtl: Huanyang HY02D223B" S2 T0
