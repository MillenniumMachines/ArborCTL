; settings/shihlin-sl3.g - Shihlin SL3 VFD settings
; This file stores the register addresses and values for the Shihlin SL3 VFD

; Pre-allocate the configuration parameters vector - increased to handle split params
global sl3ConfigParams = { vector(15, null) }

; ========== EEPROM WRITE SETTINGS (FIRST) ==========
; P.34/07-11 - EEPROM write selection: 1 (enable writes to persist to EEPROM)
; Note: This must be set first to ensure all subsequent parameter changes are saved to EEPROM
set global.sl3ConfigParams[0] = { {10711, {1}} }

; ========== CONFIGURATION MODE SETTINGS (SECOND) ==========
; P.990/00-25 - Parameter mode setting: 1 (group mode)
; Note: This should be set second to ensure all other parameter addresses work correctly
set global.sl3ConfigParams[1] = { {10990, {1}} }

; ========== SYSTEM SETTINGS ==========
; P.259/00-09 - Speed unit selection: 0 (Hz - frequency display)
set global.sl3ConfigParams[2] = { {10009, {0}} }

; P.189/00-24 - 50Hz/60Hz switch selection: 1 (60Hz system)
set global.sl3ConfigParams[3] = { {10024, {1}} }

; ========== MOTOR PARAMETERS (CONSECUTIVE REGISTERS) ==========
; P.301/05-01 - Motor rated power (W × 100)
; P.303/05-02 - Motor poles
; P.304/05-03 - Motor rated voltage (V)
; P.305/05-04 - Motor rated frequency (Hz × 100)
; P.306/05-05 - Motor rated current (A × 100)
; P.307/05-06 - Motor rated rotation speed (RPM)
set global.sl3ConfigParams[4] = { {10501, {param.W * 100, param.P, param.V, param.F * 100, param.I * 100, param.R}} }

; ========== FREQUENCY PARAMETERS (CONSECUTIVE REGISTERS) ==========
; P.1/01-00 - Maximum frequency: 400.00Hz
; P.2/01-01 - Minimum frequency: 33.33Hz
; P.18/01-02 - High-speed maximum frequency: 400.00Hz
set global.sl3ConfigParams[5] = { {10100, {40000, 3333, 40000}} }

; P.3/01-03 - Base frequency: 400.00Hz
set global.sl3ConfigParams[6] = { {10103, {40000}} }

; P.29/01-05 - Acceleration/deceleration curve selection: 1
set global.sl3ConfigParams[7] = { {10105, {1}} }

; ========== OPERATION SETTINGS (CONSECUTIVE REGISTERS) ==========
; P.20/01-09 - Acc/Dec reference frequency: 400.00Hz
; P.0/01-10 - Torque boost: 5.0%
; P.13/01-11 - Starting frequency: 33.33Hz
; P.14/01-12 - Load pattern selection: 1
set global.sl3ConfigParams[8] = { {10109, {40000, 5, 3333, 1}} }

; P.28/01-15 - Output frequency filter time: 1
set global.sl3ConfigParams[9] = { {10115, {1}} }

; ========== CONTROL SETTINGS ==========
; P.79/00-16 - Operation mode selection: 3 (Communication control mode)
set global.sl3ConfigParams[10] = { {10016, {3}} }

; P.161/00-07 - Multi-Function display: 5 (Output current)
set global.sl3ConfigParams[11] = { {10007, {5}} }

; ========== COMMUNICATION SETTINGS (CONSECUTIVE REGISTERS) ==========
; P.52/07-08 - Number of communication retries: 1
; P.53/07-09 - Communication check time interval: 2.5s (in 0.1s units)
; P.153/07-10 - Communication error handling: 0 (alarm and stop)
set global.sl3ConfigParams[12] = { {10708, {1, 25, 0}} }

; ========== ALARM SETTINGS ==========
; P.288/06-40 - Alarm code query: 12
set global.sl3ConfigParams[13] = { {10640, {12}} }

; ========== FINAL SETTINGS ==========
; P.34/07-11 - EEPROM write selection: 0 (disable writes to persist to EEPROM)
; Note: This must be set last to ensure all subsequent parameter changes are not persisted
set global.sl3ConfigParams[14] = { {10711, {0}} }