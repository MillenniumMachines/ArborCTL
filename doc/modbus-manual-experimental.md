# Manual Modbus (experimental)

This driver is for **VFDs or servo-style drives** that speak **Modbus RTU holding registers** (function 3 read / function 6 write single register) but are **not** covered by the built-in Shihlin / Huanyang / Yalang presets. It pairs with the same **wizard motor data**, **Hz limits**, **M575 UART**, and **comm-ready** behaviour as the rest of ArborCTL.

If you maintain a **separate “servo” branch** locally, merge or cherry-pick these files and extend `arborModbusManualSpec` or fork `modbus-manual-experimental/control.g` for vendor-specific command sequencing.

## `global.arborModbusManualSpec[spindle]` — 11 integers

| Index | Meaning |
|------|---------|
| 0 | **rFreqW** — Holding register address written with **commanded speed** (UINT16). |
| 1 | **rCmd** — Holding register for **run / direction / enable** command (UINT16). |
| 2 | **rFreqR** — Holding register to **read back** speed (UINT16). Use **0** to skip reads (UI uses commanded value). |
| 3 | **vFwd** — Value written to **rCmd** for **forward** run. |
| 4 | **vRev** — Value written to **rCmd** for **reverse** run. |
| 5 | **vStop** — Value written to **rCmd** when **stopped**. |
| 6 | **wrNum** — Scale: raw write = `floor(abs(RRF_RPM) * wrNum / wrDen)`, clamped 0–65535. |
| 7 | **wrDen** — Must be non-zero. |
| 8 | **rdNum** — Scale: Hz from read raw = `raw * rdNum / rdDen`. |
| 9 | **rdDen** — Must be non-zero. |
| 10 | **rProbe** | Register read once at **config** time (function 3, 1 word). Use **-1** to skip probe and still mark comm-ready (only if you know wiring is correct). |

**Example** (placeholder registers — replace with your drive’s map):

```gcode
set global.arborModbusManualSpec[0] = {5000, 5001, 5002, 1, 2, 0, 1, 1, 1, 100, 5000}
```

Tuning **wrNum/wrDen**: if the drive expects RPM × 10 in the frequency register, use `wrNum=10`, `wrDen=1`. If it expects 0–10000 = 0–max RPM, set `wrNum`/`wrDen` so `maxRPM * wrNum / wrDen` fits in 65535.

**rdNum/rdDen**: match the drive’s **feedback raw word** to Hz the same way (ArborCTL converts Hz → RPM for DWC using motor poles).

## Flow

1. Open the **DWC** plugin: pick **Manual Modbus (experimental)**, set motor, UART, address.
2. Set **`arborModbusManualSpec[spindle]`** (DWC “Manual Modbus map” section or hand-edit `arborctl-user-vars.g`).
3. **Save** and **Save & run VFD config** (or `M98` to `arborctl/modbus-manual-experimental/config.g` with the same parameters as other drivers).
4. **Reboot** if needed, then exercise the spindle from RRF.

## Limits

- **Function codes** are fixed to **F3 read / F6 write single holding** (same as Shihlin path in this repo). FC16 / input registers / 32-bit are not implemented here.
- **No** automatic register discovery — you are the preset.
- Label stays **(experimental)** until validated on hardware.

## See also

DWC plugin (form fields, saving, Test Modbus register defaults): [dwc-plugin.md](dwc-plugin.md).
