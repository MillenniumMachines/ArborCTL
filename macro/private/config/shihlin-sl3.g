; config/shihlin-sl3.g - Shihlin SL3 VFD configuration
; This file implements specific commands for the Shihlin SL3 VFD

if { !exists(param.A) }
    abort { "ArborCtl: Shihlin-SL3 - No address specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: Shihlin-SL3 - No channel specified!" }

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

var vfdModelAddr = 0x005A ; P.90/00-00 in parameter mode
var waitTime = 100

; Check that we can talk to the VFD by reading the model number (P.90/00-00)
M261.1 P{param.C} A{param.A} F3 R{var.vfdModelAddr} B1 V"vfdModel"
G4 P{var.waitTime}

; Verify we got a valid response
if { var.vfdModel == null || var.vfdModel[0] == 0 }
    abort { "ArborCtl: Shihlin-SL3 - Cannot communicate with VFD! Check connections and address settings." }

; Extract the VFD information from the model code
var vfdCapacity = { floor(var.vfdModel[0] / 100) }
var vfdVoltage = { mod(floor(var.vfdModel[0] / 10), 10) }

; Display VFD model information
echo { "ArborCtl: Shihlin-SL3 - VFD Model detected: " ^ var.vfdModel[0] }
echo { "ArborCtl: Shihlin-SL3 - VFD Capacity: " ^ var.vfdCapacity ^ "kW, Voltage Class: " ^ (var.vfdVoltage == 2 ? "220V" : var.vfdVoltage == 4 ? "440V" : "Unknown") }

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



