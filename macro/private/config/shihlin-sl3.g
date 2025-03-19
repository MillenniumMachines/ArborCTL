; config/shihlin-sl3.g - Shihlin SL3 VFD configuration
; This file implements specific commands for the Shihlin SL3 VFD
;
; Parameters:
; A - Modbus address
; C - Communication channel (UART port)
; S - Spindle ID to configure
; W - Motor rated power (kW)
; P - Motor poles (2, 4, 6, 8)
; V - Motor rated voltage (V)
; F - Motor rated frequency (Hz)
; I - Motor rated current (A)
; R - Motor rated rotation speed (RPM)
; D - Reset to factory defaults (1) or not (0)
; T - Restart VFD after configuration (1) or not (0)
; E - Execution mode: 1 for dry run (connection check only)

if { !exists(param.A) }
    abort { "ArborCtl: Shihlin-SL3 - No address specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: Shihlin-SL3 - No channel specified!" }

; In dry run mode, we only need address and channel parameters
var dryRunMode = { exists(param.E) && param.E == 1 }

; Only check for these parameters if not in dry run mode
if { !var.dryRunMode }
    if { !exists(param.S) }
        abort { "ArborCtl: Shihlin-SL3 - No spindle specified!" }

    if { !exists(param.W) }
        abort { "ArborCtl: Shihlin-SL3 - No motor rated power specified!" }

    if { !exists(param.P) }
        abort { "ArborCtl: Shihlin-SL3 - No motor poles specified!" }

    if { !exists(param.V) }
        abort { "ArborCtl: Shihlin-SL3 - No motor rated voltage specified!" }

    if { !exists(param.F) }
        abort { "ArborCtl: Shihlin-SL3 - No motor rated frequency specified!" }

    if { !exists(param.I) }
        abort { "ArborCtl: Shihlin-SL3 - No motor rated current specified!" }

    if { !exists(param.R) }
        abort { "ArborCtl: Shihlin-SL3 - No motor rotation speed specified!" }

var vfdModelAddr   = 0x005A ; P.90/00-00 in parameter mode
var vfdResetAddr   = 0x1105
var vfdResetValue  = 0x55AA
var vfdRebootAddr  = 0x1101
var vfdRebootValue = 0x9696

var waitTime = 100

; Reset VFD to factory defaults if requested (not in dry run mode)
if { !var.dryRunMode && exists(param.D) && param.D == 1 }
    M291 P"Resetting VFD to factory defaults..." R"ArborCtl: Shihlin-SL3" S0 T0
    M260.1 P{param.C} A{param.A} F6 R{var.vfdResetAddr} B{var.vfdResetValue}
    G4 P2000  ; Wait longer for reset to complete
    M291 P"Factory reset command sent. VFD should now be reset to defaults." R"ArborCtl: Shihlin-SL3" S2 T0

; Check that we can talk to the VFD by reading the model number (P.90/00-00)
M261.1 P{param.C} A{param.A} F3 R{var.vfdModelAddr} B1 V"vfdModel"
G4 P{var.waitTime}

; Verify we got a valid response
if { var.vfdModel == null || var.vfdModel[0] == 0 }
    ; If in dry run mode, show configuration guide for Modbus settings
    if { var.dryRunMode }
        M291 P"Unable to communicate with VFD. Your VFD may need to be configured for Modbus communication.<br/><br/>Would you like guidance on how to configure your VFD?" R"ArborCtl: Shihlin-SL3 Setup" S3 T0 K{"Yes, guide me", "No, skip"} F0

        if { input == 0 }
            M291 P"We'll walk you through configuring your VFD for Modbus communication.<br/>These settings need to be configured directly on your VFD's control panel." R"ArborCtl: Shihlin-SL3 Setup" S2 T0

            M291 P"STEP 1: Enter Parameter Group 7 on your VFD.<br/><br/>Press <b>MODE</b> to select parameter mode, use arrows to select group <b>07</b>, then press <b>SET</b>." R"ArborCtl: Shihlin-SL3 Setup" S2 T0

            M291 P"STEP 2: Set Parameter 07-00 (P.33)<br/><br/>Select parameter <b>07-00</b>, press <b>SET</b>, change value to <b>0</b> (Modbus), press <b>SET</b> again to confirm.<br/>This sets the communication protocol to Modbus." R"ArborCtl: Shihlin-SL3 Setup" S2 T0

            M291 P"STEP 3: Set Parameter 07-01 (P.36)<br/><br/>Select parameter <b>07-01</b>, press <b>SET</b>, change value to <b>1</b> (or your desired address), press <b>SET</b>.<br/>This sets the VFD's Modbus address." R"ArborCtl: Shihlin-SL3 Setup" S2 T0

            M291 P"STEP 4: Set Parameter 07-02 (P.32)<br/><br/>Select parameter <b>07-02</b>, press <b>SET</b>, change value to <b>3</b>, press <b>SET</b>.<br/>This sets the baud rate to 38400bps." R"ArborCtl: Shihlin-SL3 Setup" S2 T0

            M291 P"STEP 5: Set Parameter 07-07 (P.154)<br/><br/>Select parameter <b>07-07</b>, press <b>SET</b>, change value to <b>6</b>, press <b>SET</b>.<br/>This sets the Modbus format to RTU 8N1." R"ArborCtl: Shihlin-SL3 Setup" S2 T0

            M291 P"FINAL STEP: Exit parameter mode and power cycle the VFD.<br/><br/>Press <b>MODE</b> repeatedly until you return to the main display.<br/><br/><b>IMPORTANT:</b> You must power off and restart your VFD for these communication settings to take effect!" R"ArborCtl: Shihlin-SL3 Setup" S2 T0

            M291 P"After powering your VFD back on, please run the ArborCtl configuration wizard again to continue setup." R"ArborCtl: Shihlin-SL3 Setup" S2 T0

        M99 ; Exit early, user needs to power cycle the VFD before continuing
    else
        abort { "ArborCtl: Shihlin-SL3 - Cannot communicate with VFD! Check connections and address settings." }

; Extract the VFD information from the model code
var vfdCapacity = { floor(var.vfdModel[0] / 100) }
var vfdVoltage = { mod(floor(var.vfdModel[0] / 10), 10) }
var defaultVoltage = { var.vfdVoltage == 2 ? 220 : var.vfdVoltage == 4 ? 440 : 0 }

; Set global test data for the wizard to read
global arborctlTestData = { vector(4, 0) }
set global.arborctlTestData[0] = var.vfdModel[0]  ; Model code
set global.arborctlTestData[1] = var.vfdCapacity  ; Capacity in kW
set global.arborctlTestData[2] = var.vfdVoltage   ; Voltage class (2=220V, 4=440V)
set global.arborctlTestData[3] = var.defaultVoltage ; Default voltage value

; Display VFD model information
echo { "ArborCtl: Shihlin-SL3 - VFD Model detected: " ^ var.vfdModel[0] }
echo { "ArborCtl: Shihlin-SL3 - VFD Capacity: " ^ var.vfdCapacity ^ "kW, Voltage Class: " ^ (var.vfdVoltage == 2 ? "220V" : var.vfdVoltage == 4 ? "440V" : "Unknown") }

; If this is a dry run, exit now that we've verified communication and set test data
if { var.dryRunMode }
    echo { "ArborCtl: Shihlin-SL3 - Dry run complete. VFD communication successful." }
    M99

; Load the settings file which will define global.sl3ConfigParams
M98 P"arborctl/settings/shihlin-sl3.g"

; Initialize status vector for configuration progress
var statusVector = { vector(#global.sl3ConfigParams, 0) }

echo { "ArborCtl: Shihlin-SL3 - Starting VFD configuration process with " ^ #global.sl3ConfigParams ^ " parameter groups" }

; Loop through and write each batch of parameters from the global configuration
while { iterations < #global.sl3ConfigParams }
    var configItem = { global.sl3ConfigParams[iterations] }
    var startAddr = { var.configItem[0] }
    var values = { var.configItem[1] }

    ; Create command string for display
    var cmdString = { "ArborCtl: Shihlin-SL3 - Writing batch " ^ (iterations + 1) ^ " - Address " ^ var.startAddr ^ ": " }

    ; Build value string using iterations in a nested loop
    var valueStr = ""
    while { iterations < #var.values }
        set var.valueStr = { var.valueStr ^ var.values[iterations] ^ (iterations < #var.values - 1 ? ", " : "") }

    set var.cmdString = { var.cmdString ^ var.valueStr }
    echo { var.cmdString }

    ; Write batch of parameters using Modbus command
    M260.1 P{param.C} A{param.A} F16 R{var.startAddr} B{var.values}
    G4 P{var.waitTime}

    ; Verify values were set correctly by reading them back
    var allCorrect = 1

    ; Read back the parameters to verify they were set correctly
    M261.1 P{param.C} A{param.A} F3 R{var.startAddr} B{#var.values} V"readValues"
    G4 P50

    ; Check if all values were set correctly
    if { var.readValues != null && #var.readValues == #var.values }
        while { iterations < #var.values }
            if { var.readValues[iterations] != var.values[iterations] }
                set var.allCorrect = 0
                break
    else
        set var.allCorrect = 0

    ; Store verification result
    set var.statusVector[iterations] = { var.allCorrect }

    echo { "ArborCtl: Shihlin-SL3 - Batch " ^ (iterations + 1) ^ " result: " ^ (var.allCorrect ? "Success" : "Failed") }

; Report configuration results
var successCount = 0
while { iterations < #var.statusVector }
    if { var.statusVector[iterations] == 1 }
        set var.successCount = { var.successCount + 1 }

echo { "ArborCtl: Shihlin-SL3 - Configuration complete. " ^ var.successCount ^ " of " ^ #global.sl3ConfigParams ^ " batches set successfully." }

if { var.successCount < #global.sl3ConfigParams }
    echo { "ArborCtl: Shihlin-SL3 - Warning: Some parameters could not be set. Check VFD communication." }
else
    echo { "ArborCtl: Shihlin-SL3 - VFD successfully configured!" }

; Restart the VFD to apply settings if requested
if { exists(param.T) && param.T == 1 }
    M291 P"Configuration complete. Restarting VFD to apply settings..." R"ArborCtl: Shihlin-SL3" S0 T0
    M260.1 P{param.C} A{param.A} F6 R{var.vfdRebootAddr} B{var.vfdRebootValue}
    G4 P5000  ; Wait for VFD to restart
    M291 P"VFD restart command sent. VFD should now be running with new settings." R"ArborCtl: Shihlin-SL3" S2 T0



