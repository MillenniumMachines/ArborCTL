# Spindle overload / feed protection (design notes)

## Current behavior

- **Load telemetry** — per-driver `arborVFDPower[S] = { watts, loadPercent }` from VFD polling; shown in DWC.
- **Instability pause** — unexpected loss of spindle stability or VFD error still pauses the job via `M25` in [`macro/private/control-spindle.g`](../macro/private/control-spindle.g).
- **No automatic feed change** — daemon does **not** call `M220` when load exceeds a threshold.

## Removed (why)

Earlier builds reduced feed when `loadPercent > global.arborMaxLoad` (default 80) by calling **`M220`** from the daemon poll loop. That was removed because:

1. **`M220` is the global feed override** — same knob as the DWC feed % slider (`move.speedFactor`). Daemon reduce/restore fought operator intent.
2. **All feed moves are scaled** — including positioning travel, not only cutting engagement.
3. **Ratchet side effects** — repeated 0.95× steps without a clean restore made overall machine travel unreliable.

## Reserved global

`global.arborMaxLoad` (default **80**, declared in [`sys/arborctl-vars.g`](../sys/arborctl-vars.g)) remains in the object model as a **reserved threshold** for a future overload response. It is **not** applied by firmware today.

## Future direction (not implemented)

If spindle protection returns, the intent is to **reduce overall feed rate percentage** when cutting is overloaded — **not** to repeat daemon-driven `M220` from the poll loop.

| Approach | Notes |
|----------|--------|
| **Advisory** | Console / DWC warning when load > `arborMaxLoad`; operator lowers feed % manually. |
| **UI-integrated override** | Plugin shows recommended feed %; operator accepts (no silent `move.speedFactor` writes from firmware poll). |
| **Cutting-only scale** | Only if RRF or job integration can scope override to material-engagement moves (research; `M220` does not separate G0 vs cut today). |
| **Spindle RPM pullback** | Reduce commanded RPM (`M3`/`M4` S…) when load is high; protects spindle without slowing XY positioning feed. |
| **Pause on sustained overload** | `M25` (same pattern as instability), no feed change. |

**Explicit non-goal:** daemon `M220` reduce/restore from `control-spindle.g`, even if log text refers to “feed rate percentage.”

## Related files

- [`macro/private/control-spindle.g`](../macro/private/control-spindle.g) — instability pause only
- [`doc/vfd-modbus-maps.md`](vfd-modbus-maps.md) — per-driver load semantics
- [`doc/dwc-plugin.md`](dwc-plugin.md) — OM globals and telemetry panel
