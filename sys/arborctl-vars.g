; arborctl-vars.g - Variables required for ArborCtl RS485 spindle control

; Available Spindle / VFD models
global arborAvailableModels = { "Shihlin SL3", "Huanyang HY02D223", "Yalang YL620-A" }
global arborModelInternalNames = { "shihlin-sl3", "huanyang-hy02d223b", "yalang-yl620a" }
global arborModelDefaultAddress = { 1, 1, 10 }
global arborModelDefaultBaudRateIndex = { 1, 1, 2 }

; Drive existence cache - to avoid repeated file existence checks
global arborSpindleDriverExists = { vector(limits.spindles, null) }

; Return value for last M2600 or M2601 command
global arborRetVal = { null }

; Maximum load percentage before triggering overload condition 
global arborMaxLoad = 80

; Maximum number of retries for RS485 communication commands
global arborMaxRetries = 3

; Internal state structure - used by ArborCtl implementation only
; This structure contains internal data not meant for external use
; 0: VFD-specific data storage
; 1: Command change flag (true when command was just sent)
; 2: Previous stability flag (for detecting changes)
; 3: Min/max frequency limits from VFD
; 4: Error state (true when VFD has an error condition)
; 5: Pending request to be acknowledged by control daemon when desired state has been set (e.g. thru M3.9)
global arborState = { vector(limits.spindles, { null, false, false, null, false, false }) }

; USER-FRIENDLY VARIABLES - indexed by spindle number
; These are public and intended for external script use

; Configuration variables - all in one vector
; [0]: VFD type index
; [1]: UART channel
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