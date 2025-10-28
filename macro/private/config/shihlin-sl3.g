; config/shihlin-sl3.g - Shihlin SL3 VFD configuration
; This file implements specific commands for the Shihlin SL3 VFD
;
; Parameters:
; A - Modbus address
; B - Baud rate
; C - Communication channel (UART port)
; S - Spindle ID to configure
; T - Spindle Minimum Speed (RPM)
; E - Spindle Maximum Speed (RPM)
; W - Motor rated power (kW)
; U - Motor poles (2, 4, 6, 8)
; V - Motor rated voltage (V)
; F - Motor rated frequency (Hz)
; I - Motor rated current (A)
; R - Motor rated rotation speed (RPM)
; D - Reset to factory defaults (1) or not (0)

if { !exists(param.A) }
    abort { "ArborCtl: Shihlin-SL3 - No address specified!" }

if { !exists(param.B) }
    abort { "ArborCtl: Shihlin-SL3 - No baud rate specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: Shihlin-SL3 - No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: Shihlin-SL3 - No spindle specified!" }

if { !exists(param.T) }
    abort { "ArborCtl: Shihlin-SL3 - No spindle minimum frequency specified!" }

if { !exists(param.E) }
    abort { "ArborCtl: Shihlin-SL3 - No spindle maximum frequency specified!" }

if { param.T > param.E }
    abort { "ArborCtl: Shihlin-SL3 - Spindle minimum frequency cannot be greater than maximum frequency!" }

if { param.E > 599.9 }
    abort { "ArborCtl: Shihlin-SL3 - Spindle maximum frequency " ^ param.E ^ " cannot be greater than 599.9Hz - are you sure you set the right number of poles and spindle limits in RRF?" }

if { param.T < 0 || param.E < 0 }
    abort { "ArborCtl: Shihlin-SL3 - Spindle minimum and maximum frequency must be positive!" }

if { !exists(param.W) }
    abort { "ArborCtl: Shihlin-SL3 - No motor rated power specified!" }

if { !exists(param.U) }
    abort { "ArborCtl: Shihlin-SL3 - No motor poles specified!" }

if { !exists(param.V) }
    abort { "ArborCtl: Shihlin-SL3 - No motor rated voltage specified!" }

if { !exists(param.F) }
    abort { "ArborCtl: Shihlin-SL3 - No motor rated frequency specified!" }

if { !exists(param.I) }
    abort { "ArborCtl: Shihlin-SL3 - No motor rated current specified!" }

if { !exists(param.R) }
    abort { "ArborCtl: Shihlin-SL3 - No motor rotation speed specified!" }


; Load the settings file which will define global.sl3ConfigParams
M98 P"arborctl/settings/shihlin-sl3.g" W{param.W} U{param.U} V{param.V} F{param.F} I{param.I} R{param.R} T{param.T} E{param.E}

var waitTime = 250

; Configure UART port with the selected baud rate
M575 P{param.C} B{param.B} S7

var vfdModelDetected = { null }

var reset = { exists(param.D) && param.D == 1 }

while { var.vfdModelDetected == null }
    ; Check if the VFD is powered on and responding
    M261.9 P{param.C} A{param.A} F3 R{global.sl3SpecialParams[0][0]} B1
    var vfdModel = { global.arborRetVal }

    if { var.vfdModel != null && var.vfdModel[0] != 0 }
        set var.vfdModelDetected = { var.vfdModel[0] }
    else
        M291 P"Unable to communicate with VFD. Your VFD may need to be configured for Modbus communication.<br/><br/>Would you like guidance on how to configure your VFD?" R"ArborCtl: Shihlin-SL3 Setup" S4 T0 K{"Yes, guide me", "No, skip and retry"} F0 J2
        if { result == -1 }
            abort { "ArborCtl: Operator aborted configuration wizard!" }

        if { input == 0 }
            M291 P{"These settings need to be configured directly on your VFD's control panel."} R"ArborCtl: Shihlin-SL3 Setup" S2 T0

            M291 P{"STEP 1: Enter Parameter Setting Mode<br/><br/>Press <b>MODE</b> repeatedly to select parameter setting mode.<br/>Screen will either show 00-00 in Group mode or P.000 in Parameter mode."} R"ArborCtl: Shihlin-SL3 Setup" S2 T0

            M291 P{"NOTE: Your VFD is either configured in Group mode (XX-YY), later referred to as <b>GXX-YY</b> or Parameter mode (P.XXX), later as <b>P.XXX</b>."} R"ArborCtl: Shihlin-SL3 Setup" S2 T0

            M291 P{"STEP 2: Set communication protocol<br/><br/>Select parameter <b>G07-00</b> or <b>P.033</b>, press <b>SET</b>, change value to <b>0</b> (Modbus), hold <b>SET</b> again to confirm."} R"ArborCtl: Shihlin-SL3 Setup" S2 T0

            M291 P{"STEP 3: Set VFD address<br/><br/>Select parameter <b>G07-01</b> or <b>P.036</b>, press <b>SET</b>, change value to <b>" ^ param.A ^ "</b>, hold <b>SET</b>."} R"ArborCtl: Shihlin-SL3 Setup" S2 T0

            ; Baud rate needs to be converted to an integer value that can be set via this parameter.
            ; The mapping is as follows:
            ; 4800 -> 0
            ; 9600 -> 1
            ; 19200 -> 2
            ; 38400 -> 3

            var baudRateValue = { param.B == 4800 ? 0 : param.B == 9600 ? 1 : param.B == 19200 ? 2 : param.B == 38400 ? 3 : -1 }
            if { var.baudRateValue == -1 }
                abort { "ArborCtl: Shihlin-SL3 - Invalid baud rate specified!" }

            M291 P{"STEP 4: Set Modbus baudrate to " ^ param.B ^ "bps<br/><br/>Select parameter <b>G07-02</b> or <b>P.032</b>, press <b>SET</b>, change value to <b>" ^ var.baudRateValue ^ "</b>, hold <b>SET</b>."} R"ArborCtl: Shihlin-SL3 Setup" S2 T0

            M291 P{"STEP 5: Set Modbus format to RTU 8N1<br/><br/>Select parameter <b>G07-07</b> or <b>P.154</b>, press <b>SET</b>, change value to <b>6</b>, hold <b>SET</b>."} R"ArborCtl: Shihlin-SL3 Setup" S2 T0

            M291 P{"STEP 6: Restart VFD to apply settings<br/><br/>Select parameter <b>G00-02</b> or <b>P.997</b>, press <b>SET</b>, change value to <b>2 in Group or 1 in Parameter mode</b>, hold <b>SET</b>."} R"ArborCtl: Shihlin-SL3 Setup" S2 T0

            M291 P"Press OK once VFD has restarted to retry the connection." R"ArborCtl: Shihlin-SL3 Setup" S2 T0 J2
            if { result == -1 }
                abort { "ArborCtl: Operator aborted configuration wizard!" }

; Extract the VFD information from the model code
var possibleCapacities = { 0.4, 0.75, 1.5, 2.2 }
var vfdVoltage = { floor(var.vfdModelDetected / 100) }
var vfdCapacity = { var.possibleCapacities[var.vfdModelDetected - (var.vfdVoltage * 100) - 2] }
var defaultVoltage = { var.vfdVoltage == 1 ? 220 : var.vfdVoltage == 2 ? 440 : 0 }

; Display VFD model information
echo { "ArborCtl: Shihlin-SL3 - VFD Model detected: " ^ var.vfdModelDetected }
echo { "ArborCtl: Shihlin-SL3 - VFD Capacity: " ^ var.vfdCapacity ^ "kW, Voltage Class: " ^ (var.vfdVoltage == 1 ? "220V 1PH" : var.vfdVoltage == 2 ? "440V 3PH" : "Unknown") }

; Initialize status vector for configuration progress
var statusVector = { vector(#global.sl3ConfigParams, 0) }

echo { "ArborCtl: Shihlin-SL3 - Starting VFD configuration process with " ^ #global.sl3ConfigParams ^ " parameter groups" }

; Loop through and write each batch of parameters from the global configuration
while { iterations < #global.sl3ConfigParams }
    var configItem = { global.sl3ConfigParams[iterations] }
    var startAddr = { var.configItem[0] }
    var values = { var.configItem[1] }

    ; Create display string for logging
    var displayStr = { "ArborCtl: Shihlin-SL3 - Writing batch " ^ (iterations + 1) ^ " - Address " ^ var.startAddr ^ ": " }

    ; Build value string for display purposes only
    var valueStr = ""
    while { iterations < #var.values }
        set var.valueStr = { var.valueStr ^ var.values[iterations] ^ (iterations < #var.values - 1 ? ", " : "") }

    set var.displayStr = { var.displayStr ^ var.valueStr }
    echo { var.displayStr }

    ; Write batch of parameters using Modbus command - pass values vector directly to B parameter
    while { iterations < #var.values }
        echo { "ArborCtl: Shihlin-SL3 - Writing parameter " ^ (iterations + 1) ^ ": " ^ var.values[iterations] }
        M260.9 P{param.C} A{param.A} F6 R{var.startAddr + iterations} B{var.values[iterations]}
        G4 P{var.waitTime}

    ; Verify values were set correctly by reading them back
    var allCorrect = true

    ; Read back the parameters to verify they were set correctly
    ; We must read these one-by-one as reading multiple bytes seems to return
    ; incorrect values for certain registers.
    while { iterations < #var.values }
        M261.9 P{param.C} A{param.A} F3 R{var.startAddr + iterations} B1
        var readValue = { global.arborRetVal }
        G4 P{var.waitTime}
        if { var.readValue == null || #var.readValue != 1 }
            echo { "ArborCtl: Shihlin-SL3 - Readback failed for parameter " ^ (iterations + 1) ^ ": expected " ^ var.values[iterations] }
            set var.allCorrect = false
            break

        if { var.readValue[0] != var.values[iterations] }
            echo { "ArborCtl: Shihlin-SL3 - Verification failed for parameter " ^ (iterations + 1) ^ ": expected " ^ var.values[iterations] ^ ", got " ^ var.readValue }
            set var.allCorrect = false
            break

    ; Store verification result
    set var.statusVector[iterations] = { var.allCorrect }

    echo { "ArborCtl: Shihlin-SL3 - Batch " ^ (iterations + 1) ^ " result: " ^ (var.allCorrect ? "Success" : "Failed") }

; Report configuration results
var successCount = 0
while { iterations < #var.statusVector }
    if { var.statusVector[iterations] == true }
        set var.successCount = { var.successCount + 1 }

if { var.successCount == 0}
    M291 P{"VFD Configuration <b>failed</b>.<br/>No config batches were set successfully."} R"ArborCtl: Shihlin-SL3" S0 T5
if { var.successCount < #global.sl3ConfigParams }
    echo { "ArborCtl: Shihlin-SL3 - Warning: Some parameters could not be set. Check VFD communication." }
else
    M291 P{"VFD Configuration <b>successful</b>.<br/>" ^ var.successCount ^ " of " ^ #global.sl3ConfigParams ^ " config batches set successfully."} R"ArborCtl: Shihlin-SL3" S0 T5

    ; Restart the VFD to apply settings if requested
    M291 P"Configuration complete. Restarting VFD to apply settings..." R"ArborCtl: Shihlin-SL3" S0 T5
    M260.9 P{param.C} A{param.A} F6 R{global.sl3SpecialParams[2][0]} B{global.sl3SpecialParams[2][1]}
