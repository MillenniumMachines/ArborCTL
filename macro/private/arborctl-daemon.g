; arbor-daemon.g - ArborCtl daemon control file
; This file runs the appropriate VFD control file and handles spindle stability monitoring

while { iterations < limits.spindles }
    if { spindles[iterations].state == "unconfigured" }
        continue

    ; Ensure VFD is configured for this spindle
    if { global.arborVFDConfig[iterations] == null }
        continue

    M98 P"arborctl/control-spindle.g" S{iterations}
