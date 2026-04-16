; This file implements specific commands for the SCHNEIDER ALTIVAR ATV320 VFD
; updated 28 07 2025 by Twdgoust M182
;be sure to set this configuration to the VFD USING SOMOVE SOFTWARE

if { !exists(param.A) }
    abort { "ArborCtl: No address specified!" }

if { !exists(param.C) }
    abort { "ArborCtl: No channel specified!" }

if { !exists(param.S) }
    abort { "ArborCtl: No spindle specified!" }

; Define timing and register addresses (based on ATV320 Modbus map)
var cmdWait         = 50 ; Command delay in milliseconds
var motorAddr       = 9601 ;  Motor parameters ( RATED voltag = 9601, RATED current = 9603, rated speed = 9604)
var motorpwradd     = 9613 ;  Motor rated pwer * 0.1 to be in Kw
var motornpole      = 9618 ;  nbr pole  
var limitsAddr      = 3104;  Max frequency =3104 , min Frequency =3105
var statusAddr      = 3201 ; 
var freqAddr        = 8502 ; set Frequency  (0.1 Hz/unit)
var powerAddr       = 3211 ;  Output power 
var errorAddr       = 3250 ; Error code LRS 3250----to----3257 
var controlAddr     = 8501 ;  Control register (start/stop, direction)
var stopcmd         = 0 ; stop command
var forwardcmd      = 1 ;  runforword
var reversecmd      = 2 ;  runreverse

; Gather Motor Configuration from VFD if not already loaded
if { global.arborState[param.S][0] == null }
    
    ; Read motor rated  configurations  ( 0 = RATED voltag , 1 = rated frequancy, 2 =  RATED current , 3= rated speed)
    
    M261.1 P{param.C} A{param.A} F3 R{var.motorAddr} B4 V"rawmotorCfg"
    G4 P{var.cmdWait}

    ; Read motor rated  Motor rated pwer * 0.1 to be in Kw
    M261.1 P{param.C} A{param.A} F3 R{var.motorpwradd} B1 V"rawmotorpwr"
    G4 P{var.cmdWait}

    ; Read motor numbre pole
    M261.1 P{param.C} A{param.A} F3 R{var.motornpole} B1 V"rawnpole"
    G4 P{var.cmdWait}

   ; max Frequency =3104   , Min frequency =3105
    M261.1 P{param.C} A{param.A} F3 R{var.limitsAddr} B2 V"spindleLimits"
    G4 P{var.cmdWait}

    ; Check if we received all the necessary data
    if { var.rawmotorCfg == null || var.spindleLimits == null  }
        echo { "Unable to load necessary data from VFD for spindle control!"}
        M99
       
    ; Create a motor configuration vector [power, poles, voltage, frequency, current, speed]
    ; Adjust units based on ATV320 scaling
   
    var motorCfg = { vector(6, 0) }
    set var.motorCfg[0]      = { var.rawmotorpwr[0] * 10 * 0.81 } ; Calculate rated power w
    set var.motorCfg[1]      = { var.rawnpole[0]  }   ; numbre of  pole pairs 
    set var.motorCfg[2]      = { var.rawmotorCfg[0]  }   ; rated volte in V
    set var.motorCfg[3]      = { var.rawmotorCfg[1] * 0.1 } ; rated frequency in Hz 
    set var.motorCfg[4]      = { var.rawmotorCfg[2] * 0.1 } ; Rated current in A
    set var.motorCfg[5]      = { var.rawmotorCfg[3]} ;  rated speed  
    set var.spindleLimits[0] = { var.spindleLimits[0] * 0.1 } ; Max frequency in Hz
    set var.spindleLimits[1] = { var.spindleLimits[1] * 0.1 } ; Min frequency in Hz 

    
    ; Log configuration
    echo { "ArborCTL Altivar ATV320 Configuration: "}
    echo { "  Power=" ^ var.motorCfg[0] ^ "W, Poles=" ^ var.motorCfg[1] ^ ", Voltage=" ^ var.motorCfg[2] ^ "V" }
    echo { "  Current=" ^ var.motorCfg[4] ^ "A, Rated Speed=" ^ var.motorCfg[5] ^ "RPM" }
    echo { "  Max Freq=" ^ var.spindleLimits[0] ^ "Hz, Min Freq=" ^ var.spindleLimits[1] ^ "Hz"  }
    
    ; Create a frequency conversion vector for consistency with Shihlin
    var freqConv = { vector(1, 1.0) }

   ; Store VFD-specific configuration in internal state
    set global.arborState[param.S][0] = { var.motorCfg, var.freqConv }
    set global.arborState[param.S][3] = { var.spindleLimits }

    

; Determine if spindle should be running
var shouldRun = { (spindles[param.S].state == "forward" || spindles[param.S].state == "reverse") && spindles[param.S].active > 0 }

; Read status, frequency, and output data ATV320 
;0 = status  1 = output frequancy , 2 = req Freq (*10 Hz) , 3 = Output Current (*10 A), 4 = torque , 8 = Output Voltage (V)
M261.1 P{param.C} A{param.A} F3 R{var.statusAddr} B9 V"rawSpindleState" 
G4 P{var.cmdWait}

;read erreur ; Bit 1: (0=no fault, 1=drive fault)
M261.1 P{param.C} A{param.A} F3 R{var.errorAddr} B2 V"rawerror" 
G4 P{var.cmdWait}
var vfderror = { vector(1, 0) }
set var.vfderror[0] = { mod(floor(var.rawerror[0] / 2), 2) }

; Create a spindleState vector [Status, Req Freq, Output Freq, Output Current, Output Voltage, Error, torque] for consistency with sl3
; Adjust units based on YAL620 scaling
var spindleState = { vector(7, 0) }
set var.spindleState[0] = { var.rawSpindleState[0] }        ;0 = Status,
set var.spindleState[1] = { var.rawSpindleState[2] * 0.1 }  ;1 = Req Freq,
set var.spindleState[2] = { var.rawSpindleState[1] * 0.1 }  ;2 = Output Freq,
set var.spindleState[3] = { var.rawSpindleState[3] * 0.1 }  ;3 = Output Current,
set var.spindleState[4] = { var.rawSpindleState[8] }        ;4 = Output Voltage,
set var.spindleState[5] = var.vfderror[0]                    ;5 = Error 
set var.spindleState[6] = { var.rawSpindleState[4] }        ;6 = torque ,

; read spindle  output power
M261.1 P{param.C} A{param.A} F3 R{var.powerAddr} B1 V"spindlePower" 
G4 P{var.cmdWait}

; Check for valid data
if { var.spindleState == null }
    M260.1 P{param.C} A{param.A} F6 R{var.controlAddr} B{var.stopcmd} ; Stop command
    G4 P{var.cmdWait}
    M260.1 P{param.C} A{param.A} F6 R{var.freqAddr} B0
    G4 P{var.cmdWait}
    M5
    abort { "ArborCtl: Failed to read spindle state!" }

; Check for VFD errors 
if { var.spindleState[5] > 0 }
    M260.1 P{param.C} A{param.A} F6 R{var.controlAddr} B{var.stopcmd} ; Stop command
    G4 P{var.cmdWait}
    M260.1 P{param.C} A{param.A} F6 R{var.freqAddr} B0
    G4 P{var.cmdWait}
    echo { "ArborCtl: VFD Error detected. Code=" ^ var.spindleState[5] }
    set global.arborState[param.S][4] = true
    M99

; Extract status bits from spindleState (ATV320 register 3201) using modulo and division
;Bit 2: Running (0=stopped, 1=running)
;Bit 15: Direction (0=forward, 1=reverse)
;Bit 10: Speed reached (0=not reached, 1=reached)

var vfdRunning = { mod(floor(var.spindleState[0] / 4), 2) == 1 };  // Bit 2
var vfdSpeedReached = { mod(floor(var.spindleState[0] / 1024), 2) == 1 };  // Bit 10
var vfdForward = { mod(floor(var.spindleState[0] / 32768), 2) == 0 }; ;  // Bit 15 = 0 means forward
var vfdReverse = { mod(floor(var.spindleState[0] / 32768), 2) == 1 };  // Bit 15 = 1 means reverse
var vfdInputFreq = var.spindleState[1];  // Input frequency
var vfdOutputFreq = var.spindleState[2];  // Output frequency

; Check for invalid spindle state and call emergency stop on the VFD 
if { (var.vfdRunning && !var.vfdForward && !var.vfdReverse) }
    M260.1 P{param.C} A{param.A} F6 R{var.controlAddr} B{var.stopcmd} ; Stop command
    G4 P{var.cmdWait}
    M260.1 P{param.C} A{param.A} F6 R{var.freqAddr} B0
    G4 P{var.cmdWait}
    echo { "ArborCtl: Invalid spindle state detected - emergency VFD stop issued!" }
    M112
var commandChange = false

; Stop spindle if it should not be running
if { !var.shouldRun && var.vfdRunning }
     echo { "ArborCtl: Stopping spindle " ^ param.S }
     M260.1 P{param.C} A{param.A} F6 R{var.controlAddr} B{var.stopcmd} ; Stop (bit 0-1 = 01)
     G4 P{var.cmdWait}
     M260.1 P{param.C} A{param.A} F6 R{var.freqAddr} B0 ; Set frequency to 0
     G4 P{var.cmdWait}

     set var.commandChange = true

elif { var.shouldRun }
    ; Calculate the frequency to set based on the rpm requested,
    ; the max and min frequencies, the number of poles
    ; and the conversion factor.
    ; The conversion factor is the RPM that the spindle runs at with a 60Hz input.
    var numPoles   = { global.arborState[param.S][0][0][1] }
    var convFactor = { global.arborState[param.S][0][1][0] }
    var maxFreq    = { global.arborState[param.S][3][0] }
    var minFreq    = { global.arborState[param.S][3][1] }
    
    ; Clamp the frequency to the limits and ensure we get a valid result
    var  scaledFreq = { min(var.maxFreq, max(var.minFreq, (abs(spindles[param.S].current) * var.numPoles) / 120)) }
    var  newFreq = { floor(var.scaledFreq * 10) } ;  Hz/unit
    
    ; Set input frequency if it doesn't match the RRF value
    if { var.vfdInputFreq != var.scaledFreq }
        M260.1 P{param.C} A{param.A} F6 R{var.freqAddr} B{var.newFreq}
        G4 P{var.cmdWait}
        set var.commandChange = true

    ; Set spindle direction forward if needed
    if { spindles[param.S].state == "forward" && (!var.vfdRunning || !var.vfdForward) }
         M260.1 P{param.C} A{param.A} F6 R{var.controlAddr} B{var.forwardcmd}; set direction forward
         G4 P{var.cmdWait}
         set var.commandChange = true

    ; Set spindle direction reverse if needed
    elif { spindles[param.S].state == "reverse" && (!var.vfdRunning || !var.vfdReverse) }
          M260.1 P{param.C} A{param.A} F6 R{var.controlAddr} B{var.reversecmd} ; set reverse direction
          G4 P{var.cmdWait}
          set var.commandChange = true

; calculate current RPM 
var currentRPM       = { var.vfdOutputFreq * 60 / (global.arborState[param.S][0][0][1] / 2) } ; frequancy alredy in hz
; Check if frequency is stable (within 5% of target)
var targetFreq = { var.shouldRun ? var.vfdInputFreq : 0 }
var freqDiff = { abs(var.vfdOutputFreq - var.targetFreq) }
var isStable = { var.freqDiff < (var.targetFreq * 0.05) || var.freqDiff < 0.5 }
;var isStable         = { var.vfdRunning && var.vfdSpeedReached }
; Save previous stability flag for stability change detection
set global.arborState[param.S][2] = { global.arborVFDStatus[param.S] != null ? global.arborVFDStatus[param.S][4] : false }

; Update internal state
set global.arborState[param.S][1] = { var.commandChange }
set global.arborState[param.S][4] = { var.spindleState[5] > 0 }

; Update public status variables
; Set or initialize VFD status array
if { global.arborVFDStatus[param.S] == null }
    set global.arborVFDStatus[param.S] = { vector(5, 0) }

set global.arborVFDStatus[param.S][0] = { var.vfdRunning }
set global.arborVFDStatus[param.S][1] = { var.vfdRunning ? (var.vfdReverse ? -1 : 1) : 0 }
set global.arborVFDStatus[param.S][2] = { var.vfdOutputFreq }
set global.arborVFDStatus[param.S][3] = { var.currentRPM }
set global.arborVFDStatus[param.S][4] = { var.isStable }

; Set or initialize VFD power array
if { global.arborVFDPower[param.S] == null }
    set global.arborVFDPower[param.S] = { vector(2, 0) }

set global.arborVFDPower[param.S][0] = { var.spindlePower }

; Calculate and update load percentage if motor power is known
if { global.arborMotorSpec[param.S] != null }
    var loadPercent = { var.spindlePower / (global.arborState[param.S][0][0][0] * 1000) * 100 }
    set global.arborVFDPower[param.S][1] = { var.loadPercent }





