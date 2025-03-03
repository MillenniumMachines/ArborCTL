; arbor-vars.g - Variables required for ArborCtl RS485 spindle control

; Available Spindle / VFD models
global arborCtlModels = { "shihlin-sl3", "huanyang-hy02d223b" }

global arborCtlMaxLoad = 80

global arborCtlCfg = {{60}}

; Current state of spindles as reported by VFD
; Each spindle has a vector of 6 values:
; [RUN, DIR, STABLE, FREQ, POWER, CURRENT]
; RUN:         True if spindle is running in forward or reverse
; DIR:         True if spindle is in reverse
; STABLE:      True if spindle is at requested frequency
; OLD_STABLE:  True if spindle was at requested frequency
; CMD_CHANGE:  True if spindle has been commanded to change
; LOAD:        Current load on spindle, as a percentage
; MODEL_SPECIFIC: Model specific data

;                                                     RUN,   DIR, STABLE, OLD_STABLE, CMD_CHANGE, LOAD, MODEL_SPECIFIC }
global arborCtlState  = { vector(limits.spindles, { false, false,  false,      false,      false,    0,           null }) }