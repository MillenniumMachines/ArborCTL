; config/yalang-yl620-a.g - Yalang YL620-A VFD configuration
; This file implements specific commands for the Yalang YL620-A VFD
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
    abort { "ArborCtl: Yalang YL620-A - No address specified!" }

if { !exists(param.B) }
    abort { "ArborCtl: Yalang YL620-A - No baud rate specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: Yalang YL620-A - No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: Yalang YL620-A - No spindle specified!" }

if { !exists(param.T) }
    abort { "ArborCtl: Yalang YL620-A - No spindle minimum frequency specified!" }

if { !exists(param.E) }
    abort { "ArborCtl: Yalang YL620-A - No spindle maximum frequency specified!" }

if { param.T > param.E }
    abort { "ArborCtl: Yalang YL620-A - Spindle minimum frequency cannot be greater than maximum frequency!" }

if { param.E > 599.9 }
    abort { "ArborCtl: Yalang YL620-A - Spindle maximum frequency " ^ param.E ^ " cannot be greater than 599.9Hz - are you sure you set the right number of poles and spindle limits in RRF?" }

if { param.T < 0 || param.E < 0 }
    abort { "ArborCtl: Yalang YL620-A - Spindle minimum and maximum frequency must be positive!" }

if { !exists(param.W) }
    abort { "ArborCtl: Yalang YL620-A - No motor rated power specified!" }

if { !exists(param.U) }
    abort { "ArborCtl: Yalang YL620-A - No motor poles specified!" }

if { !exists(param.V) }
    abort { "ArborCtl: Yalang YL620-A - No motor rated voltage specified!" }

if { !exists(param.F) }
    abort { "ArborCtl: Yalang YL620-A - No motor rated frequency specified!" }

if { !exists(param.I) }
    abort { "ArborCtl: Yalang YL620-A - No motor rated current specified!" }

if { !exists(param.R) }
    abort { "ArborCtl: Yalang YL620-A - No motor rotation speed specified!" }


; Load the settings file which will define global.yl620aConfigParams
M98 P"arborctl/settings/yalang-yl620a.g" W{param.W} U{param.U} V{param.V} F{param.F} I{param.I} R{param.R} T{param.T} E{param.E}

var waitTime = 250

; Configure serial port with the selected baud rate
M575 P{param.C} B{param.B} S7

var vfdModelDetected = { null }

var reset = { exists(param.D) && param.D == 1 }

while { var.vfdModelDetected == null }
    ; Check if the VFD is powered on and responding
    M2601 E0 P{param.C} A{param.A} F3 R{global.yl620aSpecialParams[0][0]} B1
    var vfdModel = { global.arborRetVal }

    if { var.vfdModel != null && var.vfdModel[0] != 0 }
        set var.vfdModelDetected = { var.vfdModel[0] }
    else
        M291 P"Unable to communicate with VFD. Your VFD may need to be configured for Modbus communication.<br/><br/>Would you like guidance on how to configure your VFD?" R"ArborCtl: Yalang YL620-A Setup" S4 T0 K{"Yes, guide me", "No, skip and retry"} F0 J2
        if { result == -1 }
            abort { "ArborCtl: Operator aborted configuration wizard!" }

        if { input == 0 }
            M291 P{"These settings need to be configured directly on your VFD's control panel."} R"ArborCtl: Yalang YL620-A Setup" S2 T0

            M291 P{"STEP 1: Enter Parameter Setting Mode<br/><br/>Press <b>PRGM</b> to select parameter setting mode.<br/>Screen will show P 00 00 with last 00 flashing."} R"ArborCtl: Yalang YL620-A Setup" S2 T0

            M291 P{"STEP 2: Set communication protocol<br/><br/>Select parameter <b>P 00 01</b> by pushing the up arrow, press <b>SET</b>, change value to <b>3</b> (RS485 + Modbus), press <b>SET</b> again to confirm."} R"ArborCtl: Yalang YL620-A Setup" S2 T0

            var msg = "STEP 3: Set VFD address<br/><br/>Select parameter <b>P 03 01</b> using <b>DISP >></b> to select the first pair of digits, and the arrow keys to change the value. press <b>SET</b>, change value to <b>" ^ param.A ^ "</b>, press <b>SET</b>."
            M291 P{var.msg} R"ArborCtl: Yalang YL620-A Setup" S2 T0

            ; Baud rate needs to be converted to an integer value that can be set via this parameter.
            ; The mapping is as follows:
            ; 1200 -> 0
            ; 2400 -> 1
            ; 4800 -> 2
            ; 9600 -> 3
            ; 19200 -> 4
            ; 38400 -> 5

            var baudRateValue = { param.B == 1200 ? 0 : param.B == 2400 ? 1 : param.B == 4800 ? 2 : param.B == 9600 ? 3 : param.B == 19200 ? 4 : param.B == 38400 ? 5 : -1 }
            if { var.baudRateValue == -1 }
                abort { "ArborCtl: Yalang YL620-A - Invalid baud rate specified.  The Yalang YL620-A supports the following baud rates:<br>1200; 2400; 4800; 9600; 19200; 38400" }

            M291 P{"STEP 4: Set Modbus baudrate to " ^ param.B ^ "bps<br/><br/>Select parameter <b>P 03 00</b>, press <b>SET</b>, change value to <b>" ^ var.baudRateValue ^ "</b>, press <b>SET</b>."} R"ArborCtl: Yalang YL620-A Setup" S2 T0

            M291 P{"STEP 5: Set Modbus format to RTU 8N1<br/><br/>Select parameter <b>P 03 02</b>, press <b>SET</b>, change value to <b>2</b>, press <b>SET</b>."} R"ArborCtl: Yalang YL620-A Setup" S2 T0

            M291 P{"STEP 8: Restart VFD to apply settings by turning it off, waiting for all lights to go out, and turning it back on again."} R"ArborCtl: Yalang YL620-A Setup" S2 T0

            M291 P"Press OK once VFD has restarted to retry the connection." R"ArborCtl: Yalang YL620-A Setup" S2 T0 J2
            if { result == -1 }
                abort { "ArborCtl: Operator aborted configuration wizard!" }

; Display VFD model information
echo { "ArborCtl: Yalang YL620-A - VFD Model detected: " ^ var.vfdModelDetected }

; Initialize status vector for configuration progress
var statusVector = { vector(#global.yl620aConfigParams, 0) }

echo { "ArborCtl: Yalang YL620-A - Starting VFD configuration process with " ^ #global.yl620aConfigParams ^ " parameter groups" }

; Loop through and write each batch of parameters from the global configuration
while { iterations < #global.yl620aConfigParams }
    var configItem = { global.yl620aConfigParams[iterations] }
    var startAddr = { var.configItem[0] }
    var values = { var.configItem[1] }

    ; Create display string for logging
    var displayStr = { "ArborCtl: Yalang YL620-A - Writing batch " ^ (iterations + 1) ^ " - Address " ^ var.startAddr ^ ": " }

    ; Build value string for display purposes only
    var valueStr = ""
    echo { "B: " ^ var.values }
    while { iterations < #var.values }
        set var.valueStr = { var.valueStr ^ var.values[iterations] ^ (iterations < #var.values - 1 ? ", " : "") }

    set var.displayStr = { var.displayStr ^ var.valueStr }
    echo { "C: " ^ var.displayStr }

    ; Write batch of parameters using Modbus command - pass values vector directly to B parameter
    while { iterations < #var.values }
        echo { "ArborCtl: Yalang YL620-A - Writing parameter " ^ (iterations + 1) ^ ": " ^ var.values[iterations] }
        M2600 E0 P{param.C} A{param.A} F6 R{var.startAddr + iterations} B{var.values[iterations]}

    ; Verify values were set correctly by reading them back
    var allCorrect = true

    ; Read back the parameters to verify they were set correctly
    ; We must read these one-by-one as reading multiple bytes seems to return
    ; incorrect values for certain registers.
    while { iterations < #var.values }
        M2601 E0 P{param.C} A{param.A} F3 R{var.startAddr + iterations} B1
        var readValue = { global.arborRetVal }
        if { var.readValue == null || #var.readValue != 1 }
            echo { "ArborCtl: Yalang YL620-A - Readback failed for parameter " ^ (iterations + 1) ^ ": expected " ^ var.values[iterations] }
            set var.allCorrect = false
            break

        if { var.readValue[0] != var.values[iterations] }
            echo { "ArborCtl: Yalang YL620-A - Verification failed for parameter " ^ (iterations + 1) ^ ": expected " ^ var.values[iterations] ^ ", got " ^ var.readValue }
            set var.allCorrect = false
            break

    ; Store verification result
    set var.statusVector[iterations] = { var.allCorrect }

    echo { "ArborCtl: Yalang YL620-A - Batch " ^ (iterations + 1) ^ " result: " ^ (var.allCorrect ? "Success" : "Failed") }

; Report configuration results
var successCount = 0
while { iterations < #var.statusVector }
    if { var.statusVector[iterations] == true }
        set var.successCount = { var.successCount + 1 }

if { var.successCount == 0}
    M291 P{"VFD Configuration <b>failed</b>.<br/>No config batches were set successfully."} R"ArborCtl: Yalang YL620-A" S0 T5
if { var.successCount < #global.yl620aConfigParams }
    echo { "ArborCtl: Yalang YL620-A - Warning: Some parameters could not be set. Check VFD communication." }
else
    M291 P{"VFD Configuration <b>successful</b>.<br/>" ^ var.successCount ^ " of " ^ #global.yl620aConfigParams ^ " config batches set successfully."} R"ArborCtl: Yalang YL620-A" S0 T5

    ; Restart the VFD to apply settings if requested
    if { global.yl620aSpecialParams[2][0] != null && global.yl620aSpecialParams[2][1] != null }
        M291 P"Configuration complete. Restarting VFD to apply settings..." R"ArborCtl: Yalang YL620-A" S0 T5
        M2600 E0 P{param.C} A{param.A} F6 R{global.yl620aSpecialParams[2][0]} B{global.yl620aSpecialParams[2][1]}
    else
        M291 P"Configuration complete.  Restart your VFD to apply settings.  Press okay once complete" R"ArborCtl: Yalang YL620-A" S2 T0
