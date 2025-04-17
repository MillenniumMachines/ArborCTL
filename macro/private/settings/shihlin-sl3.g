; settings/shihlin-sl3.g - Shihlin SL3 VFD settings
; This file stores the register addresses and values for the Shihlin SL3 VFD

if { !exists(global.sl3SpecialParams) }
    ;                             Model              Reset                Reboot
    global sl3SpecialParams = { { 0x005A, {null}}, { 0x1105, {0x55AA}}, { 0x1101, {0x9696}} }

; Pre-allocate the configuration parameters vector - increased to handle split params
if { !exists(global.sl3ConfigParams) }
    global sl3ConfigParams = { vector(18, null) }  ; Increased size to accommodate new parameter

; ========== CU MODE SETTINGS (FIRST) ==========
; P.79/0016 - Operation mode selection: 0 (CU mode)
set global.sl3ConfigParams[0] = { {10016, {3,}} }

; ========== EEPROM WRITE SETTINGS (SECOND) ==========
; P.34/07-11 - EEPROM write selection: 0 (enable writes to persist to EEPROM)
; Note: This must be set first to ensure all subsequent parameter changes are saved to EEPROM
set global.sl3ConfigParams[1] = { {10711, {0,}} }

; ========== SYSTEM SETTINGS ==========
; P.37/00-08 - Speed display scaling: Set to the equivalent RPM at 60Hz
; This value represents what RPM the display should show when running at 60Hz
; P.259/00-09 - Speed unit selection: 0 (Hz - frequency display)
set global.sl3ConfigParams[2] = { {10008, { ceil((param.R / param.F) * 60), 0}} }

; P.189/00-24 - 50Hz/60Hz switch selection: 1 (60Hz system)
set global.sl3ConfigParams[3] = { {10024, {1,}} }

; ========== MOTOR PARAMETERS (CONSECUTIVE REGISTERS) ==========
; P.301/05-01 - Motor rated power (W × 100)
; P.303/05-02 - Motor poles
; P.304/05-03 - Motor rated voltage (V)
; P.305/05-04 - Motor rated frequency (Hz × 100)
; P.306/05-05 - Motor rated current (A × 100)
; P.307/05-06 - Motor rated rotation speed (RPM)
set global.sl3ConfigParams[4] = { {10501, {ceil(param.W * 100), param.U, param.V, ceil(param.F * 100), ceil(param.I * 100), ceil(param.R/10)}} }

; ========== FREQUENCY PARAMETERS ==========
; P.3/01-03 - Base frequency: 400.00Hz

; Multiply by 100 to match VFD register format
var minFreq = { ceil(param.T * 100) }
var maxFreq = { ceil(param.E * 100) }

set global.sl3ConfigParams[5] = { {10103, {var.maxFreq,}} }

; P.18/01-02 - High-speed maximum frequency: var.maxFreq (set first)
; P.1/01-00 - Maximum frequency: var.maxFreq
; P.2/01-01 - Minimum frequency: var.minFreq

set global.sl3ConfigParams[6] = { {10102, { var.maxFreq, }} }
set global.sl3ConfigParams[7] = { {10100, { var.maxFreq, var.minFreq, }} }

; ========== OPERATION SETTINGS (CONSECUTIVE REGISTERS) ==========
; P.20/01-09 - Acc/Dec reference frequency: var.maxFreq
; P.0/01-10 - Torque boost: 5.0%
; P.13/01-11 - Starting frequency: 3.33Hz
; P.14/01-12 - Load pattern selection: 1 (variable torque load)
set global.sl3ConfigParams[8] = { {10109, {var.maxFreq, 50, 333, 1}} }

; P.29/01-05 - Acceleration/deceleration curve selection: 1
; P.4/01-06 - Acceleration time: 2.5s
; P.5/01-07 - Deceleration time: 2.5s
set global.sl3ConfigParams[9] = { {10105, {1, 250, 250}} }

; P.28/01-15 - Output frequency filter time: 1
set global.sl3ConfigParams[10] = { {10115, {1,}} }

; P.10/10-00 - DC Brake Operating Frequency: 120Hz
; P.11/10-01 - DC Brake Time: 1.0s
; P.12/10-02 - DC Brake Operating Voltage Percent: 30%
set global.sl3ConfigParams[11] = { {11000, {12000, 10, 300}} }

; P.22/06-01 - Stall Prevention Operation Level: 150%
set global.sl3ConfigParams[12] = { {10601, {1500,}} }

; ========== CONTROL SETTINGS ==========
; P.161/00-07 - Multi-Function display: 5 (Output current)
set global.sl3ConfigParams[13] = { {10007, {5,}} }

; ========== COMMUNICATION SETTINGS (CONSECUTIVE REGISTERS) ==========
; P.52/07-08 - Number of communication retries: 1
; P.53/07-09 - Communication check time interval: 1.0s (in 0.1s units)
; P.153/07-10 - Communication error handling: 0 (alarm and stop)
set global.sl3ConfigParams[14] = { {10708, {1, 10, 0}} }

; ========== ALARM SETTINGS ==========
; P.288/06-40 - Alarm code query: 12
set global.sl3ConfigParams[15] = { {10640, {12,}} }

; ========== FINAL SETTINGS ==========
; P.79/0016 - Operation mode selection: 0 (CU mode)
set global.sl3ConfigParams[16] = { {10016, {3,}} }

; P.34/07-11 - EEPROM write selection: 1 (disable writes to persist to EEPROM)
; Note: This must be set last to ensure all subsequent parameter changes are not persisted
set global.sl3ConfigParams[17] = { {10711, {1,}} }