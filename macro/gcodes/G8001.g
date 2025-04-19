; G8001.g: ARBORCTL CONFIGURATION WIZARD
;
; This command walks the user through configuring ArborCtl.
; It is triggered automatically when ArborCtl is first loaded, if the
; arborctl-user-vars.g file does not exist. It can also be run manually but
; please note, it will overwrite your existing arborctl-user-vars.g file.

; Make sure this file is not executed by the secondary motion system
if { !inputs[state.thisInput].active }
    M99

var wizUVF = "arborctl-user-vars.g"

; Reset options
var wizReset = false

; Configuration options
var wizChan = null
var wizType = null
var wizAddr = null
var wizSpdlID = null
var wizMotorW = null ; W
var wizMotorU = null ; P
var wizMotorV = null ; V
var wizMotorF = null ; F
var wizMotorI = null ; I
var wizMotorR = null ; R
var wizBaud = null   ; Baud rate for UART

M291 P{"Welcome to ArborCtl! This wizard will walk you through VFD configuration.<br/>You can run this wizard again using <b>G8001</b> or clicking the <b>Run ArborCtl Configuration Wizard</b> macro."} R"ArborCtl: Configuration Wizard" S3 T0 J2
if { result == -1 }
    abort { "ArborCtl: Operator aborted configuration wizard!" }

; Check if ArborCtl is already configured
if { exists(global.arborctlLdd) && global.arborctlLdd }
    M291 P{"ArborCtl is already configured. Click <b>Continue</b> to re-configure and change settings, or <b>Reset</b> to reset all settings and start again."} R"ArborCtl: Configuration Wizard" S4 T0 K{"Continue","Reset"} J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
elif { exists(global.arborctlErr) && global.arborctlErr != null }
    M291 P{"ArborCtl could not be loaded due to a startup error.<br/>Click <b>Update</b> to configure any missing settings or <b>Reset</b> to reset all settings and start again."} R"ArborCtl: Configuration Wizard" S4 T0 K{"Update","Reset"}

; Reset if requested
set var.wizReset = { (input == 1) }

; Get communication channel
if { var.wizChan == null || var.wizReset }
    M291 P{"Which UART channel is your VFD connected to?"} R"ArborCtl: Configuration Wizard" S4 T0 K{"AUX 0 (First port)", "AUX 1 (Second port)", "AUX 2 (Third port)"} F0 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizChan = { input+1 }

; Get VFD type
if { var.wizType == null || var.wizReset }
    M291 P{"What type of VFD do you have?"} R"ArborCtl: Configuration Wizard" S4 T0 K{global.arborAvailableModels} F0 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizType = { global.arborAvailableModels[input] }

; Get VFD address
if { var.wizAddr == null || var.wizReset }
    M291 P{"What is the Modbus address of your VFD?<br/><br/>This is typically 1, but can be changed in your VFD settings."} R"ArborCtl: Configuration Wizard" S5 T0 L1 H247 F1 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizAddr = { input }

; Get spindle ID
; Look up configured spindles. If only one spindle is configured, use that one.
; If multiple spindles are configured, ask the user to select one.
if { var.wizSpdlID == null || var.wizReset }
    while { iterations < limits.spindles }

        if { spindles[iterations] != null && spindles[iterations].state != "unconfigured" }
            M291 P{"<b>Spindle " ^ iterations ^ "</b> is configured.<br/><br/>Do you want to assign this spindle to the VFD?"} R"ArborCtl: Configuration Wizard" S4 T0 K{"Yes", "No"} F0 J2
            if { result == -1 }
                abort { "ArborCtl: Operator aborted configuration wizard!" }
            if { input == 0 }
                set var.wizSpdlID = { iterations }
                break

    if { var.wizSpdlID == null }
        abort { "ArborCtl: No spindle selected! You must bind a configured RRF spindle to this VFD." }



; Get motor parameters first so we can pass them to the VFD configuration file
if { var.wizMotorW == null || var.wizReset }
    M291 P{"What is the rated power of your motor?<br/><br/>Enter the value in kW."} R"ArborCtl: Configuration Wizard" S6 T0 L0 H100 F1.5 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizMotorW = { input }

if { var.wizMotorU == null || var.wizReset }
    M291 P{"How many poles does your motor have?<br/><br/>Most induction motors have either 2 or 4 poles."} R"ArborCtl: Configuration Wizard" S4 T0 K{"2", "4"} F0 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizMotorU = { (input+1)*2 }

; Get Spindle Min/Max RPM and convert to max / min frequency based on pole count
var wizSpdlT = { (spindles[var.wizSpdlID].min / 120) * var.wizMotorU }
var wizSpdlE = { (spindles[var.wizSpdlID].max / 120) * var.wizMotorU }

if { var.wizMotorV == null || var.wizReset }
    M291 P{"What is the rated voltage of your motor?<br/><br/>Enter the value in volts."} R"ArborCtl: Configuration Wizard" S6 T0 L0 H1000 F220 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizMotorV = { input }

if { var.wizMotorF == null || var.wizReset }
    M291 P{"What is the rated frequency of your motor?<br/><br/>Enter the value in Hz."} R"ArborCtl: Configuration Wizard" S6 T0 L0 H800 F400 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizMotorF = { input }

if { var.wizMotorI == null || var.wizReset }
    M291 P{"What is the rated current of your motor?<br/><br/>Enter the value in amperes."} R"ArborCtl: Configuration Wizard" S6 T0 L0 H100 F10 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizMotorI = { input }

if { var.wizMotorR == null || var.wizReset }
    ; Calculate default RPM based on frequency and poles
    var defaultRPM = { ceil((var.wizMotorF * 60 * 2) / var.wizMotorU) }
    M291 P{"What is the rated rotation speed of your motor?<br/><br/>Enter the value in RPM."} R"ArborCtl: Configuration Wizard" S5 T0 L0 H24000 F{var.defaultRPM} J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizMotorR = { input }

; Get baud rate for the UART port
if { var.wizBaud == null || var.wizReset }
    var baudRateStrings = {"4800", "9600", "19200", "38400", "57600"}
    var baudRates       = {4800, 9600, 19200, 38400, 57600}
    M291 P{"Select the baud rate for your VFD communication:<br/><br/>Most VFDs work well with 38400 or 19200."} R"ArborCtl: Configuration Wizard" S4 K{var.baudRateStrings} F3 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizBaud = { var.baudRates[input] }

; Ask user if they want to configure VFD now
M291 P{"Do you want to configure your VFD and motor settings now?<br/><br/>The VFD must be correctly connected and powered on."} R"ArborCtl: Configuration Wizard" S4 T0 K{"Yes", "No"} F0 J2
if { result == -1 }
    abort { "ArborCtl: Operator aborted configuration wizard!" }

if { input == 0 }
    var cfgFile = { "arborctl/config/" ^ var.wizType ^ ".g" }
    ; Configure the VFD - the VFD-specific file will handle both manual configuration guidance and automated settings
    M98 P{var.cfgFile} B{var.wizBaud} C{var.wizChan} A{var.wizAddr} S{var.wizSpdlID} W{var.wizMotorW} U{var.wizMotorU} V{var.wizMotorV} F{var.wizMotorF} I{var.wizMotorI} R{var.wizMotorR} T{var.wizSpdlT} E{var.wizSpdlE}
    ; Add other VFD types here in the future

; Create the actual user variables file
echo >{var.wizUVF}  "; ArborCtl User Variables"
echo >>{var.wizUVF} ";"
echo >>{var.wizUVF} "; This file is automatically generated by the ArborCtl configuration wizard."
echo >>{var.wizUVF} "; You can edit this file manually at your own risk."
echo >>{var.wizUVF} ""

; Write the user-friendly configuration
echo >>{var.wizUVF} "; ArborCtl Configuration"
echo >>{var.wizUVF} "; UART Configuration"
echo >>{var.wizUVF} {"M575 P" ^ var.wizChan ^ " B" ^ var.wizBaud ^ " S7 ; Configure UART for Modbus RTU"}
echo >>{var.wizUVF} ""

; VFD Configuration
echo >>{var.wizUVF} "; VFD Configuration"
echo >>{var.wizUVF} {"set global.arborVFDConfig[" ^ var.wizSpdlID ^ "] = {""" ^ var.wizType ^ """, " ^ var.wizChan ^ ", " ^ var.wizAddr ^ "} ; VFD configuration"}
echo >>{var.wizUVF} ""

M999