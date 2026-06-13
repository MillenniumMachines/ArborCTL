; M8111.g
; This file implements a VFD restart if it is in emergency for the Shihlin-SL3 VFD only
;
; Parameters:
; S - Spindle number

M98 P{"arborctl/restart-spindle.g"} S{param.S}
