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

; Check that we can talk to the VFD by reading the model number
M261.1 P{param.C} A{param.A} F3 R2710 B1 V"vfdModel"

; Extract the power rating and voltage from the model number