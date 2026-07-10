; 0:/sys/plugins/arborctl/arborctl-daemon-hook.g — NeXT data.nxt daemon hook
; RepRapFirmware 3.6+ / 3.7+
;
; Periodic spindle polling. Called from nxt-plugin-daemon-dispatch.g when
; ArborCTL is registered in the NeXT plugin catalog.

if { fileexists("0:/sys/arborctl/arborctl-daemon.g") }
    M98 P"arborctl/arborctl-daemon.g"
