; check-motor-nameplate.g - Abort if rated RPM is not ~ 120 * Hz / poles
;
; Parameters:
; U - Motor poles (must be > 0)
; F - Motor rated frequency (Hz, must be > 0)
; R - Motor rated rotation speed (RPM, must be > 0)
;
; Synchronous identity: RPM = 120 * Hz / poles
; 2-pole 400 Hz = 24000 RPM; 4-pole 400 Hz = 12000 RPM.

if { !exists(param.U) || param.U <= 0 }
    abort { "ArborCtl: Nameplate check - poles (U) must be positive!" }

if { !exists(param.F) || param.F <= 0 }
    abort { "ArborCtl: Nameplate check - rated frequency (F) must be positive!" }

if { !exists(param.R) || param.R <= 0 }
    abort { "ArborCtl: Nameplate check - rated RPM (R) must be positive!" }

var impliedRpm = { floor(((120 * param.F) / param.U) + 0.5) }
var rpmDelta = { abs(param.R - var.impliedRpm) }
var rpmTol = { max(50, var.impliedRpm * 0.01) }
var nameplateBad = { var.rpmDelta > var.rpmTol }

if { var.nameplateBad }
    var npMsg = { "ArborCtl: Rated RPM " ^ param.R ^ " != 120*Hz/poles " ^ var.impliedRpm }
    set var.npMsg = { var.npMsg ^ " (poles=" ^ param.U ^ " Hz=" ^ param.F ^ ")" }
    abort { var.npMsg }
