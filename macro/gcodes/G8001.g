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
var wizChannel = null
var wizVFDType = null
var wizVFDAddress = null
var wizSpindleID = null
var wizMotorPower = null     ; W
var wizMotorPoles = null     ; P
var wizMotorVoltage = null   ; V
var wizMotorFrequency = null ; F
var wizMotorCurrent = null   ; I
var wizMotorRotationSpeed = null  ; R
var wizBaudRate = null            ; Baud rate for UART

M291 P"Welcome to ArborCtl! This wizard will walk you through VFD configuration.<br/>You can run this wizard again using <b>G8001</b> or clicking the <b>""Run ArborCtl Configuration Wizard""</b> macro." R"ArborCtl: Configuration Wizard" S3 T0 J2
if { result == -1 }
    abort { "ArborCtl: Operator aborted configuration wizard!" }

; Check if ArborCtl is already configured
if { exists(global.arborctlLdd) && global.arborctlLdd }
    M291 P"ArborCtl is already configured. Click <b>Continue</b> to re-configure and change settings, or <b>Reset</b> to reset all settings and start again." R"ArborCtl: Configuration Wizard" S4 T0 K{"Continue","Reset"} J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
elif { exists(global.arborctlErr) && global.arborctlErr != null }
    M291 P"ArborCtl could not be loaded due to a startup error.<br/>Click <b>Update</b> to configure any missing settings or <b>Reset</b> to reset all settings and start again." R"ArborCtl: Configuration Wizard" S4 T0 K{"Update","Reset"}

; Reset if requested
set var.wizReset = { (input == 1) }

; Get communication channel
if { var.wizChannel == null || var.wizReset }
    M291 P"Which UART channel is your VFD connected to?<br/>This is specified when you configured your UART port with M575." R"ArborCtl: Configuration Wizard" S4 T0 K{"AUX 0 (First port)", "AUX 1 (Second port)", "AUX 2 (Third port)"} F0 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizChannel = { input+1 }

; Get VFD type
if { var.wizVFDType == null || var.wizReset }
    M291 P"What type of VFD do you have?" R"ArborCtl: Configuration Wizard" S4 T0 K{global.arborAvailableModels} F0 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizVFDType = { global.arborAvailableModels[input] }

; Get VFD address
if { var.wizVFDAddress == null || var.wizReset }
    M291 P"What is the Modbus address of your VFD?<br/><br/>This is typically 1, but can be changed in your VFD settings." R"ArborCtl: Configuration Wizard" S5 T0 L1 H247 F1 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizVFDAddress = { input }

; Get spindle ID
if { var.wizSpindleID == null || var.wizReset }
    M291 P"Which spindle ID would you like to assign to this VFD?<br/><br/>This is the spindle number you'll use with M3/M4/M5 commands." R"ArborCtl: Configuration Wizard" S5 T0 L0 H10 F0 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizSpindleID = { input }

; Get motor parameters first so we can pass them to the VFD configuration file
if { var.wizMotorPower == null || var.wizReset }
    M291 P"What is the rated power of your motor?<br/><br/>Enter the value in kW." R"ArborCtl: Configuration Wizard" S6 T0 L0 H100 F2.2 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizMotorPower = { input }

if { var.wizMotorPoles == null || var.wizReset }
    M291 P"How many poles does your motor have?<br/><br/>Most induction motors have either 2 or 4 poles." R"ArborCtl: Configuration Wizard" S4 T0 K{"2", "4", "6", "8"} F0 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizMotorPoles = { (input+1)*2 }

if { var.wizMotorVoltage == null || var.wizReset }
    M291 P"What is the rated voltage of your motor?<br/><br/>Enter the value in volts." R"ArborCtl: Configuration Wizard" S6 T0 L0 H1000 F220 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizMotorVoltage = { input }

if { var.wizMotorFrequency == null || var.wizReset }
    M291 P"What is the rated frequency of your motor?<br/><br/>Enter the value in Hz." R"ArborCtl: Configuration Wizard" S6 T0 L0 H800 F400 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizMotorFrequency = { input }

if { var.wizMotorCurrent == null || var.wizReset }
    M291 P"What is the rated current of your motor?<br/><br/>Enter the value in amperes." R"ArborCtl: Configuration Wizard" S6 T0 L0 H100 F10 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizMotorCurrent = { input }

if { var.wizMotorRotationSpeed == null || var.wizReset }
    ; Calculate default RPM based on frequency and poles
    var defaultRPM = { (var.wizMotorFrequency * 60 * 2) / var.wizMotorPoles }
    M291 P"What is the rated rotation speed of your motor?<br/><br/>Enter the value in RPM." R"ArborCtl: Configuration Wizard" S5 T0 L0 H24000 F{var.defaultRPM} J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    set var.wizMotorRotationSpeed = { input }

; Get baud rate for the UART port
if { var.wizBaudRate == null || var.wizReset }
    var baudRates = {"9600", "19200", "38400", "57600"}
    M291 P"Select the baud rate for your VFD communication:<br/><br/>Most VFDs work well with 38400 or 19200." R"ArborCtl: Configuration Wizard" S4 K{var.baudRates} F2 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    echo { "Selected baud rate: " ^ input }
    set var.wizBaudRate = { var.baudRates[input] }

; Ask user if they want to configure VFD now
M291 P"Do you want to configure your VFD and motor settings now?<br/><br/>The VFD must be correctly connected and powered on." R"ArborCtl: Configuration Wizard" S4 T0 K{"Yes", "No"} F0 J2
if { result == -1 }
    abort { "ArborCtl: Operator aborted configuration wizard!" }

if { input == 0 }
    ; Configure UART port with the selected baud rate and Modbus RTU format
    M291 P{"Configuring UART port " ^ var.wizChannel ^ " with baud rate " ^ var.wizBaudRate ^ " and Modbus RTU format..."} R"ArborCtl: Configuration Wizard" S1 T2
    M575 P{var.wizChannel} B{var.wizBaudRate} S7

    ; Ask if user wants to reset VFD to factory defaults first
    M291 P"Would you like to reset the VFD to factory defaults before configuring?<br/><br/><b>WARNING:</b> This will erase ALL existing VFD settings!" R"ArborCtl: Configuration Wizard" S4 T0 K{"Yes", "No"} F1 J2
    if { result == -1 }
        abort { "ArborCtl: Operator aborted configuration wizard!" }
    var resetVFD = { input == 0 }

    var configFile = { "arborctl/config/" ^ var.wizVFDType ^ ".g" }
    ; Configure the VFD - the VFD-specific file will handle both manual configuration guidance and automated settings
    M98 P{var.configFile} C{var.wizChannel} A{var.wizVFDAddress} S{var.wizSpindleID} W{var.wizMotorPower} P{var.wizMotorPoles} V{var.wizMotorVoltage} F{var.wizMotorFrequency} I{var.wizMotorCurrent} R{var.wizMotorRotationSpeed} D{var.resetVFD ? 1 : 0} T0
    ; Add other VFD types here in the future

; Create the actual user variables file
echo >"0:/sys/"{var.wizUVF} "; ArborCtl User Variables"
echo >>"0:/sys/"{var.wizUVF} ";"
echo >>"0:/sys/"{var.wizUVF} "; This file is automatically generated by the ArborCtl configuration wizard."
echo >>"0:/sys/"{var.wizUVF} "; You can edit this file manually at your own risk."
echo >>"0:/sys/"{var.wizUVF} ""

; Write the user-friendly configuration
echo >>"0:/sys/"{var.wizUVF} "; ArborCtl Configuration"
echo >>"0:/sys/"{var.wizUVF} "; UART Configuration"
echo >>"0:/sys/"{var.wizUVF} {"M575 P" ^ var.wizChannel ^ " B" ^ var.wizBaudRate ^ " S7 ; Configure UART for Modbus RTU"}
echo >>"0:/sys/"{var.wizUVF} ""

; VFD Configuration
echo >>"0:/sys/"{var.wizUVF} "; VFD Configuration"
echo >>"0:/sys/"{var.wizUVF} {"set global.arborVFDConfig[" ^ var.wizSpindleID ^ "] = "{"" ^ var.wizVFDType ^ """, " ^ var.wizChannel ^ ", " ^ var.wizVFDAddress ^ "}"}
echo >>"0:/sys/"{var.wizUVF} ""

; Remind users to add ArborCtL to config.g
M291 P"ArborCtl configuration complete!<br/><br/>Make sure to add <b>M98 P\"arborctl.g\"</b> to the end of your config.g file if you haven't already." R"ArborCtl: Configuration Wizard" S2 T0
if { result == -1 }
    abort { "ArborCtl: Operator aborted configuration wizard!" }

; Mark ArborCtl as loaded
global arborctlLdd = true
