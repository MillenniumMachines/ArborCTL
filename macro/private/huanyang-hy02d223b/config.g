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

var vfdCommReady = null
var probeValue = null

while { var.vfdCommReady == null }
    ; Read PD005 to confirm the VFD is powered on and responding to the Huanyang protocol.
    M260.4 P{param.C} A{param.A} B{{0x01, 0x03, global.hy02d223bSpecialParams[0][0], 0x00, 0x00}} R6 V"probeValue"
    G4 P{var.waitTime}

    if { var.probeValue != null && #var.probeValue == 6 }
        set var.vfdCommReady = true
    else
        M291 P"Unable to communicate with the Huanyang HY02D223B VFD. Your VFD may need to be configured for RS485 communication.<br/><br/>Would you like guidance on how to configure your VFD?" R"ArborCtl: Huanyang HY02D223B Setup" S4 T0 K{"Yes, guide me", "No, skip and retry"} F0 J2
        if { result == -1 }
            abort { "ArborCtl: Operator aborted configuration wizard!" }

        if { input == 0 }
            M291 P{"These settings need to be configured directly on your VFD's control panel."} R"ArborCtl: Huanyang HY02D223B Setup" S2 T0
            M291 P{"STEP 1: Enter parameter setting mode<br/><br/>Press <b>PRGM</b> until the display shows a <b>PDxxx</b> parameter code."} R"ArborCtl: Huanyang HY02D223B Setup" S2 T0
            M291 P{"STEP 2: Set VFD address<br/><br/>Select parameter <b>PD163</b>, press <b>SET</b>, change the value to <b>" ^ param.A ^ "</b>, then press <b>SET</b> again."} R"ArborCtl: Huanyang HY02D223B Setup" S2 T0
            M291 P{"STEP 3: Set communication baud rate<br/><br/>Select parameter <b>PD164</b>, press <b>SET</b>, change the value to <b>" ^ var.baudRateValue ^ "</b> for <b>" ^ param.B ^ "bps</b>, then press <b>SET</b> again."} R"ArborCtl: Huanyang HY02D223B Setup" S2 T0
            M291 P{"STEP 4: Set communication format<br/><br/>Select parameter <b>PD165</b>, press <b>SET</b>, change the value to <b>3</b> for <b>RTU 8N1</b>, then press <b>SET</b> again."} R"ArborCtl: Huanyang HY02D223B Setup" S2 T0
            M291 P{"STEP 5: Set run command source<br/><br/>Select parameter <b>PD001</b>, press <b>SET</b>, change the value to <b>2</b> so run commands come from the communication port."} R"ArborCtl: Huanyang HY02D223B Setup" S2 T0
            M291 P{"STEP 6: Set frequency source<br/><br/>Select parameter <b>PD002</b>, press <b>SET</b>, change the value to <b>2</b> so operating frequency comes from the communication port."} R"ArborCtl: Huanyang HY02D223B Setup" S2 T0
            M291 P{"STEP 7: Power-cycle the VFD after changing communication settings, then press OK to retry the connection."} R"ArborCtl: Huanyang HY02D223B Setup" S2 T0 J2
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
    var readLen = { var.width == 1 ? 5 : 6 }
    var readValue = null

    echo { "ArborCtl: Huanyang HY02D223B - Writing PD" ^ var.reg ^ " = " ^ var.value }

    ; Function 0x02 writes parameter data. LEN includes the parameter byte plus the value width.
    if { var.width == 1 }
        M260.4 P{param.C} A{param.A} B{{0x02, 0x02, var.reg, var.value}} R4
    elif { var.width == 2 }
        M260.4 P{param.C} A{param.A} B{{0x02, 0x03, var.reg, var.writeHigh, var.writeLow}} R5
    else
        abort { "ArborCtl: Huanyang HY02D223B - Invalid config width for PD" ^ var.reg ^ "!" }
    G4 P{var.waitTime}

    ; Function 0x01 reads parameter data. This follows the same request layout used in the
    ; Huanyang reference code for initialization reads.
    M260.4 P{param.C} A{param.A} B{{0x01, 0x03, var.reg, 0x00, 0x00}} R{var.readLen} V"readValue"
    G4 P{var.waitTime}

    if { var.readValue != null && #var.readValue == var.readLen }
        var decoded = { var.width == 1 ? var.readValue[4] : (var.readValue[4] * 256 + var.readValue[5]) }
        if { var.decoded == var.value }
            set var.allCorrect = true
        else
            echo { "ArborCtl: Huanyang HY02D223B - Verification failed for PD" ^ var.reg ^ ": expected " ^ var.value ^ ", got " ^ var.decoded }
    else
        echo { "ArborCtl: Huanyang HY02D223B - Readback failed for PD" ^ var.reg ^ ": expected " ^ var.value }

    set var.statusVector[var.idx] = { var.allCorrect }
    echo { "ArborCtl: Huanyang HY02D223B - PD" ^ var.reg ^ " result: " ^ (var.allCorrect ? "Success" : "Failed") }
    set var.idx = { var.idx + 1 }

var successCount = 0
var idx = 0
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
    if { exists(global.arborMotorSpec) }
        set global.arborMotorSpec[param.S] = null

if { var.successCount == 0 }
    M291 P{"VFD Configuration <b>failed</b>.<br/>No HY02D223B parameters were set successfully."} R"ArborCtl: Huanyang HY02D223B" S0 T5
elif { var.successCount < #global.hy02d223bConfigParams }
    echo { "ArborCtl: Huanyang HY02D223B - Warning: Some parameters could not be set. Check VFD communication and parameter lock state." }
    M291 P{"VFD Configuration <b>partially successful</b>.<br/>" ^ var.successCount ^ " of " ^ #global.hy02d223bConfigParams ^ " parameters were set successfully."} R"ArborCtl: Huanyang HY02D223B" S0 T5
else
    M291 P{"VFD Configuration <b>successful</b>.<br/>All " ^ var.successCount ^ " parameters were set successfully."} R"ArborCtl: Huanyang HY02D223B" S0 T5
    M291 P"Configuration complete. Power-cycle the VFD before relying on the updated communication settings." R"ArborCtl: Huanyang HY02D223B" S2 T0
