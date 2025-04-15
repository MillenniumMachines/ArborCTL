; arborctl-vars.g - Variables required for ArborCtl RS485 spindle control

; Available Spindle / VFD models
global arborAvailableModels = { "shihlin-sl3", "huanyang-hy02d223b" }

global arborMaxLoad = 80

; Internal state structure - used by ArborCtl implementation only
; This structure contains internal data not meant for external use
; 0: VFD-specific data storage
; 1: Command change flag (true when command was just sent)
; 2: Previous stability flag (for detecting changes)
; 3: Min/max frequency limits from VFD
; 4: Error state (true when VFD has an error condition)
global arborState = { vector(limits.spindles, { null, false, false, null, false }) }

; USER-FRIENDLY VARIABLES - indexed by spindle number
; These are public and intended for external script use

; Configuration variables - all in one vector
; [0]: VFD type string (e.g. "shihlin-sl3")
; [1]: UART channel number
; [2]: Modbus address
global arborVFDConfig = { vector(limits.spindles, null) }

; Motor specification variables - all in one vector
; [0]: power in kW, [1]: number of poles, [2]: rated voltage in V
; [3]: rated frequency in Hz, [4]: rated current in A, [5]: rated speed in RPM
global arborMotorSpec = { vector(limits.spindles, null) }

; VFD status variables - all in one vector
; [0]: running status (bool), [1]: direction (0=stopped, 1=forward, -1=reverse)
; [2]: current frequency in Hz, [3]: current speed in RPM, [4]: stable at requested speed (bool)
global arborVFDStatus = { vector(limits.spindles, null) }

; VFD power variables - all in one vector
; [0]: current power consumption in watts, [1]: load as percentage of rated power
global arborVFDPower = { vector(limits.spindles, null) }