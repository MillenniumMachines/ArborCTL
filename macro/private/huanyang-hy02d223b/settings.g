; huanyang-hy02d223b/settings.g - Huanyang HY02D223B VFD settings
; This file stores the parameter addresses and values for the Huanyang HY02D223B VFD.
; Each config item is stored as { PD register, value width in bytes, value }.

if { !exists(global.hy02d223bSpecialParams) }
    ;                       Probe register, width
    global hy02d223bSpecialParams = { {0x05, 2} }

if { !exists(global.hy02d223bConfigParams) }
    global hy02d223bConfigParams = { vector(13, null) }

var minFreq = { ceil(param.T * 100) }
var maxFreq = { ceil(param.E * 100) }
var motorCurrent = { ceil(param.I * 10) }
var motorSpeed50Hz = { floor(((param.R * 50.0) / param.F) + 0.5) }
var baudRateValue = { param.B == 4800 ? 0 : param.B == 9600 ? 1 : param.B == 19200 ? 2 : param.B == 38400 ? 3 : -1 }

if { var.baudRateValue == -1 }
    abort { "ArborCtl: Huanyang HY02D223B - Invalid baud rate specified. Supported baud rates are 4800, 9600, 19200, and 38400." }

; PD000 - Parameter Lock: 0 (unlock so the remaining writes can succeed)
set global.hy02d223bConfigParams[0] = { {0x00, 1, 0} }

; PD141 - Rated motor voltage (V)
set global.hy02d223bConfigParams[1] = { {0x8D, 2, param.V} }

; PD142 - Rated motor current (A * 10)
set global.hy02d223bConfigParams[2] = { {0x8E, 2, var.motorCurrent} }

; PD143 - Motor poles
set global.hy02d223bConfigParams[3] = { {0x8F, 1, param.U} }

; PD144 - Rated motor revolution at 50Hz
set global.hy02d223bConfigParams[4] = { {0x90, 2, var.motorSpeed50Hz} }

; PD005 - Maximum operating frequency (Hz * 100)
set global.hy02d223bConfigParams[5] = { {0x05, 2, var.maxFreq} }

; PD011 - Frequency lower limit (Hz * 100)
set global.hy02d223bConfigParams[6] = { {0x0B, 2, var.minFreq} }

; PD023 - Reverse rotation enable
set global.hy02d223bConfigParams[7] = { {0x17, 1, 1} }

; PD001 - Operation commands from communication port
set global.hy02d223bConfigParams[8] = { {0x01, 1, 2} }

; PD002 - Operating frequency from communication port
set global.hy02d223bConfigParams[9] = { {0x02, 1, 2} }

; PD163 - RS485 address
set global.hy02d223bConfigParams[10] = { {0xA3, 1, param.A} }

; PD164 - RS485 baud rate
set global.hy02d223bConfigParams[11] = { {0xA4, 1, var.baudRateValue} }

; PD165 - RS485 data method: 3 = RTU 8N1
set global.hy02d223bConfigParams[12] = { {0xA5, 1, 3} }
