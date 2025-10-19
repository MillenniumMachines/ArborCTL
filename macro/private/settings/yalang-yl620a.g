; settings/yalang-yl620-a.g - Yalang YL620-A VFD settings
; This file stores the register addresses and values for the Yalang YL620-A VFD

if { !exists(global.yl620aSpecialParams) }
    ;                                Hardware Version   Reset                Reboot
    global yl620aSpecialParams = { { 0x0d01, {null}}, { 0x0013, {0x000a}}, { null, {null}} }

; Pre-allocate the configuration parameters vector - increased to handle split params
if { !exists(global.yl620aConfigParams) }
    global yl620aConfigParams = { vector(9, null) }  ; Increased size to accommodate new parameter

; ========== MOTOR PARAMETERS ==========
; P12 00 - Motor rated current (A * 10)
; P12 01 - Motor rated voltage (V)
; P12 02 - Motor pole count
set global.yl620aConfigParams[0] = { {0x0c00, {ceil(param.I * 10), param.V, param.U }} }

; ========== FREQUENCY PARAMETERS ==========
; P00 00 - Main Frequency
set global.yl620aConfigParams[1] = { {0x0000, vector(1, param.F * 10)} }

var minFreq = { ceil(param.T * 10) }
var maxFreq = { ceil(param.E * 10) }

; P00 04 - Highest Frequency Output
; P00 05 - Frequency at max voltage
set global.yl620aConfigParams[2] = { {0x0004, {param.F * 10, var.maxFreq}} }

; P00 07 - Mid Frequency Output
set global.yl620aConfigParams[3] = { {0x0007, vector(1, ceil(var.minFreq + (var.maxFreq - var.minFreq) * 0.02))} }

; P00 09 - Min Frequency Output
set global.yl620aConfigParams[4] = { {0x0009, vector(1, var.minFreq)} }

; ========== MODBUS OPERATION =========
; P00 01 - Command Source
; P03 04 - Modbus timeout (ms)
; P07 08 - Frequency source 1

set global.yl620aConfigParams[5] = { {0x0001, vector(1, 3)}}
set global.yl620aConfigParams[6] = { {0x0304, vector(1, 2000)}}
set global.yl620aConfigParams[7] = { {0x0708, vector(1, 5)}}

; ========== OPERATION SETTINGS ==========
; P20 02 - Acceleration time: 2.5s
; P20 03 - Acceleration time: 2.5s
set global.yl620aConfigParams[8] = { {0x2002, { 250, 250 }} }

