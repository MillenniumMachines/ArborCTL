; arbor-vars.g - Variables required for ArborCtl RS485 spindle control

; Available Spindle / VFD models
global arborCtlAvailableModels = { "shihlin-sl3", "huanyang-hy02d223b" }

global arborCtlMaxLoad = 80

; Current state of spindles
; MODEL:       Spindle model identifier, also name of the model-specific file
; CHANNEL:     Aux channel number
; ADDR:        RS485 address
; RUN:         True if spindle is running in forward or reverse
; DIR:         True if spindle is in reverse
; ERR:         True if spindle has an error
; STABLE:      True if spindle is at requested frequency
; OLD_STABLE:  True if spindle was at requested frequency
; CMD_CHANGE:  True if spindle has been commanded to change
; LOAD:        Current load on spindle, as a percentage
; MODEL_SPECIFIC: Model specific data
; MOTOR_SPECIFIC: Motor Nameplate data (Voltage, Current, Power, Frequency, Poles) - DO NOT MODIFY

;                                                   MODEL, CHANNEL, ADDRESS,   RUN,   DIR,   ERR, STABLE, OLD_STABLE, CMD_CHANGE, LOAD, MODEL_SPECIFIC, MOTOR_SPECIFIC }
global arborCtlState  = { vector(limits.spindles, {  null,    null,    null, false, false, false,  false,      false,      false,    0,           null,           null }) }