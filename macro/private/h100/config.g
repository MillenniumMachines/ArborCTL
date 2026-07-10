; h100/config.g - H100 VFD configuration
; Standard Modbus RTU (FluidNC H100 map). Panel RS485: F001=2, F002=2, F163=addr, F164=baud, F165=3.
;
; Parameters:
; A - Modbus address
; B - Baud rate
; C - Communication channel (UART port)
; S - Spindle ID to configure
; T - Spindle Minimum Frequency (Hz)
; E - Spindle Maximum Frequency (Hz)
; W - Motor rated power (kW)
; U - Motor poles (2, 4, 6, 8)
; V - Motor rated voltage (V)
; F - Motor rated frequency (Hz)
; I - Motor rated current (A)
; R - Motor rated rotation speed (RPM)

if { !exists(param.A) }
    abort { "ArborCtl: H100 - No address specified!" }

if { !exists(param.B) }
    abort { "ArborCtl: H100 - No baud rate specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: H100 - No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: H100 - No spindle specified!" }

if { !exists(param.T) }
    abort { "ArborCtl: H100 - No spindle minimum frequency specified!" }

if { !exists(param.E) }
    abort { "ArborCtl: H100 - No spindle maximum frequency specified!" }

if { param.T > param.E }
    abort { "ArborCtl: H100 - Spindle minimum frequency cannot be greater than maximum frequency!" }

if { param.E > 599.9 }
    abort { "ArborCtl: H100 - Spindle maximum frequency " ^ param.E ^ " cannot be greater than 599.9Hz!" }

if { param.T < 0 || param.E < 0 }
    abort { "ArborCtl: H100 - Spindle minimum and maximum frequency must be positive!" }

if { !exists(param.W) }
    abort { "ArborCtl: H100 - No motor rated power specified!" }

if { !exists(param.U) }
    abort { "ArborCtl: H100 - No motor poles specified!" }

if { !exists(param.V) }
    abort { "ArborCtl: H100 - No motor rated voltage specified!" }

if { !exists(param.F) }
    abort { "ArborCtl: H100 - No motor rated frequency specified!" }

if { !exists(param.I) }
    abort { "ArborCtl: H100 - No motor rated current specified!" }

if { !exists(param.R) }
    abort { "ArborCtl: H100 - No motor rotation speed specified!" }

M98 P"arborctl/h100/settings.g"

; Configure serial port with the selected baud rate
M575 P{param.C} B{param.B} S7

var vfdResponding = { false }

while { !var.vfdResponding }
    ; Probe F005 (max frequency) via FC3 — same register FluidNC uses for get_max_rpm
    M2601 E0 P{param.C} A{param.A} F3 R{global.h100MaxFreqAddr} B1
    var maxFreqRaw = { global.arborRetVal }

    if { var.maxFreqRaw != null && #var.maxFreqRaw == 1 }
        set var.vfdResponding = { true }
        if { exists(global.arborVFDCommReady) }
            set global.arborVFDCommReady[param.S] = true
    else
        M291 P"Unable to communicate with H100 VFD. Configure RS485 on the panel first.<br/><br/>Show setup guidance?" R"ArborCtl: H100 Setup" S4 T0 K{"Yes, guide me", "No, skip and retry"} F0 J2
        if { result == -1 }
            abort { "ArborCtl: Operator aborted configuration wizard!" }

        if { input == 0 }
            M291 P{"These settings are entered on the VFD keypad (not via Modbus)."} R"ArborCtl: H100 Setup" S2 T0

            M291 P{"STEP 1: Set run command source<br/><br/>Set <b>F001</b> to <b>2</b> (communications / RS485)."} R"ArborCtl: H100 Setup" S2 T0

            M291 P{"STEP 2: Set frequency source<br/><br/>Set <b>F002</b> to <b>2</b> (communications / RS485)."} R"ArborCtl: H100 Setup" S2 T0

            var msg = "STEP 3: Set Modbus address<br/><br/>Set <b>F163</b> to <b>" ^ param.A ^ "</b> (must match ArborCTL address)."
            M291 P{var.msg} R"ArborCtl: H100 Setup" S2 T0

            ; F164 baud index varies by clone. Common: 1=9600, 2=19200 (unofficial SLB guide).
            var baudHint = { "confirm in your H100 manual" }
            if { param.B == 9600 }
                set var.baudHint = "often <b>1</b> for 9600"
            elif { param.B == 19200 }
                set var.baudHint = "often <b>2</b> for 19200 (SLB guide)"

            M291 P{"STEP 4: Set baud to " ^ param.B ^ "<br/><br/>Set <b>F164</b> so it matches (" ^ var.baudHint ^ ")."} R"ArborCtl: H100 Setup" S2 T0

            M291 P{"STEP 5: Set data format<br/><br/>Set <b>F165</b> to <b>3</b> (RTU 8N1)."} R"ArborCtl: H100 Setup" S2 T0

            M291 P{"STEP 6: Power-cycle the VFD, wait for the display to go dark, then power on again."} R"ArborCtl: H100 Setup" S2 T0

            M291 P"Press OK once the VFD has restarted to retry the connection." R"ArborCtl: H100 Setup" S2 T0 J2
            if { result == -1 }
                abort { "ArborCtl: Operator aborted configuration wizard!" }

; Store wizard motor + Hz limits for control.g (PD motor writes are not required)
set global.arborMotorSpec[param.S] = { param.W, param.U, param.V, param.F, param.I, param.R }
set global.arborWizardFreqLimits[param.S] = { param.T, param.E }

; Clear cached VFD state so control.g reloads limits
set global.arborState[param.S][0] = null
set global.arborState[param.S][3] = null

echo { "ArborCtl: H100 - Probe OK. Motor " ^ param.W ^ "kW, poles=" ^ param.U ^ ", Hz " ^ param.T ^ "-" ^ param.E }
M291 P{"H100 communication <b>OK</b>.<br/>Wizard motor and Hz limits saved. Ensure F001/F002=2 and F163–F165 match this UART."} R"ArborCtl: H100" S0 T5
