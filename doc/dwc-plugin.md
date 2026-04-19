# ArborCTL DWC plugin (`dwc-plugin/`)

The **ArborCTL** panel in [Duet Web Control](https://github.com/Duet3D/DuetWebControl) (DWC) is a single-page editor for `0:/sys/arborctl-user-vars.g`, optional **Manual Modbus** register maps, live **telemetry**, and **Modbus test** probes. The text wizard (**G8001**) remains the canonical fallback.

**Prerequisites:** RepRapFirmware 3.6+, ArborCTL loaded (`M98 P"arborctl.g"` in `config.g`), matching `plugin.json` / `dwcVersion` for your DWC build.

---

## Installing the plugin

**Production:** Download **`ArborCTL-<version>.zip`** from GitHub **Releases** (built by CI when a **`v*`** tag is pushed), or build locally with **`dist/build-dwc-plugin.sh`** / **`dist/build-dwc-plugin.ps1`**. Upload the ZIP through DWC **System → Files** as usual; do not unzip on the PC before upload.

**Development:** See [dwc-development.md](dwc-development.md) — copy `dwc-plugin/` into `DuetWebControl/src/plugins/ArborCTL`, run `tools/setup-dwc-dev.ps1`, then `npm run dev`. A local **DuetWebControl** clone (e.g. `dwc-env/`) should stay **out of git**; add it to `.gitignore` if you clone beside this repo.

---

## Object model fields (read by the UI)

The panel reads **user globals** from `state.machine.model.global` (with a fallback to `machine.variables` in some DWC builds):

| Global | Purpose |
|--------|---------|
| `arborctlLdd` | ArborCTL loaded |
| `arborctlVer` | Version string |
| `arborctlErr` | Last error, if any |
| `arborAvailableModels` / `arborModelInternalNames` | VFD list and macro folder names |
| `arborVFDConfig` | Per-spindle `{ typeIndex, channel, address }` |
| `arborMotorSpec` | Per-spindle motor nameplate vector |
| `arborModbusManualSpec` | Manual Modbus 11-int register map (see [modbus-manual-experimental.md](modbus-manual-experimental.md)) |
| `arborVFDStatus` | Per-spindle `{ running, dir, Hz, RPM, stable }` |
| `arborVFDPower` | Per-spindle `{ watts, loadPercent }` — meaning depends on driver |
| `arborVFDCommReady` | Per-spindle comm gate after successful config probe |
| `arborMaxLoad` | Threshold (%) for overload feed logic in `control-spindle.g` |

Until you connect to a board, many fields are empty; the form still renders.

---

## VFD models (order in `arborctl-vars.g`)

| Index | Label | Internal folder |
|------|--------|-----------------|
| 0 | Shihlin SL3 | `shihlin-sl3` |
| 1 | Huanyang HY02D223 | `huanyang-hy02d223b` |
| 2 | Yalang YL620-A | `yalang-yl620a` |
| 3 | Manual Modbus (experimental) | `modbus-manual-experimental` |
| 4 | TH Servo (preliminary) | `th-servo` |

**TH Servo (preliminary)** — RS485 servo spindle support merged from upstream work (e.g. [PR #17](https://github.com/MillenniumMachines/ArborCTL/pull/17)). The UI shows **min/max RPM** (from RRF spindle limits and rated RPM) instead of Hz summary chips, and labels the Hz nameplate field as a legacy G8001 file field. Firmware: `macro/private/th-servo/`.

**Manual Modbus (experimental)** — User-defined FC3/FC6 holding-register map (`arborModbusManualSpec`). See [modbus-manual-experimental.md](modbus-manual-experimental.md).

---

## Saving configuration

1. **Save to arborctl-user-vars.g** — Writes `M575`, `arborVFDConfig`, `arborMotorSpec`, `arborWizardFreqLimits`, and (if Manual is selected) `arborModbusManualSpec`.
2. **Save & run VFD config macro** — Uploads the file, runs `M98 P"0:/sys/arborctl-user-vars.g"` so globals match the file, then `M98 P"arborctl/<driver>/config.g"` with the same parameters as G8001 (`B` baud, `C` channel, `A` address, motor and Hz limits). Required so **Manual Modbus** `config.g` sees `arborModbusManualSpec` before probing.

**Run wizard (G8001)** — Opens the stock ArborCTL configuration wizard macro.

---

## Live spindle telemetry

When ArborCTL is loaded, the panel lists **configured** spindles (`arborVFDConfig` slots) with:

- **Comm** — `arborVFDCommReady` (OK / Off / —)
- **Run / Dir / Hz / RPM / Stable** — `arborVFDStatus`
- **Power (W) / Load %** — `arborVFDPower`, plus a load bar when load is numeric

**Load %** is **driver-defined**: e.g. VFD power estimate, servo drive register, or `0` if not implemented (Manual Modbus currently zeros power). The caption references **`global.arborMaxLoad`** used by `macro/private/control-spindle.g` for overload feed reduction.

---

## Test Modbus (diagnostic)

**Test Modbus** sends a **single probe** using the **baud, UART channel, and slave address** from the form (no save required). Check the **Duet console** for `echo` lines (OK/FAIL and values).

| Driver | Mechanism | Macro on `0:/sys/arborctl/` |
|--------|-----------|------------------------------|
| Huanyang | Same **raw-frame** probe as full config (`M2604`), not FC3 | `huanyang-quick-probe.g` — params `B` `C` `A` |
| All others | **FC3** read of one **holding register** | `modbus-fc3-probe.g` — params `B` `C` `A` `R` |

**Default FC3 register `R` (decimal):**

- **TH Servo:** 4096  
- **Shihlin:** 90 (`0x005A`, first probe in `settings.g` / `config.g`)  
- **Yalang:** 3329 (`0x0D01`)  
- **Manual:** `arborModbusManualSpec[10]` (probe reg) if ≥ 0, else `manualSpec[0]` (freq-write reg)  
- **Fallback:** 5000 if no better default applies  

Huanyang ignores `R`; use **Test Modbus** to confirm wiring and addressing before running full **Save & run VFD config**.

---

## File map (reference)

| Path | Role |
|------|------|
| `dwc-plugin/dwc-src/ArborCTL.vue` | Plugin UI |
| `dwc-plugin/plugin.json` | Plugin id / DWC version |
| `macro/private/modbus-fc3-probe.g` | Shared FC3 test read |
| `macro/private/huanyang-quick-probe.g` | Huanyang-only probe |
| `macro/private/th-servo/*` | TH Servo driver |
| `macro/private/modbus-manual-experimental/*` | Manual Modbus driver |
| `dist/_runtime_stage/` | Staged copy for release scripts (keep in sync with `macro/` and `sys/` where applicable) |

---

## Troubleshooting

- **Plugin missing in `npm run dev`:** Use **Copy** not a junction on Windows; re-run `setup-dwc-dev.ps1`; clear site data for `localhost` if old DWC `localStorage` hides the plugin.
- **Test Modbus always fails:** Baud, address, AUX port, termination, and that the VFD is powered; for FC3, confirm register `R` matches the manual.
- **Telemetry empty:** Daemon running, spindle configured in ArborCTL, and `arborVFDCommReady` true after a successful config.

For upstream packaging and CNC dashboard defaults, see [dwc-development.md](dwc-development.md).
