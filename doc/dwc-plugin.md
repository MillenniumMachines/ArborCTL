# ArborCTL DWC plugin (`dwc-plugin/`)

The **ArborCTL** panel in [Duet Web Control](https://github.com/Duet3D/DuetWebControl) (DWC) is the canonical configuration UI: a single-page editor for `0:/sys/arborctl-user-vars.g`, optional **Manual Modbus** register maps, live **telemetry**, and **Modbus test** probes.

**Prerequisites:** RepRapFirmware **3.7+** (3.6 macros still run; plugin ZIP targets DWC 3.7), ArborCTL loaded (`M98 P"arborctl.g"` in `config.g`), host DWC version matching the ZIP’s exact `dwcVersion`.

**Stack (3.7):** Vue 3 + Vuetify 4 Options API, Pinia via [`dwc-src/compat/dwcStore.ts`](../dwc-plugin/dwc-src/compat/dwcStore.ts), registration from `@/plugins` (not Vue 2 `@/routes` / `@/store`).

---

## Installing the plugin

**Production:** Download **`ArborCTL-<version>.zip`** from GitHub **Releases** (built by CI when a **`v*`** tag is pushed), or build locally with **`dist/build-dwc-plugin.sh`**. Upload the ZIP through DWC **System → Files**; do not unzip on the PC before upload.

**NeXT / data.nxt:** The ZIP also ships `sd/sys/plugins/arborctl/{arborctl-init,arborctl-daemon-hook}.g`. When NeXT’s catalog includes ArborCTL, the daemon dispatcher calls the hook (which runs `arborctl-daemon.g`). Standalone installs still use `sys/daemon.g.example`.

**Development:** See [dwc-development.md](dwc-development.md).

---

## Object model fields (read by the UI)

The panel reads **user globals** from `state.machine.model.global` (with a fallback to `machine.variables` in some DWC builds):

| Global | Purpose |
|--------|---------|
| `arborctlLdd` | ArborCTL loaded |
| `arborctlVer` | Version string |
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
| 5 | H100 | `h100` |

**H100** — Standard Modbus RTU (FluidNC-compatible). See [h100-notes.md](h100-notes.md).

**TH Servo (preliminary)** — RS485 servo spindle support. The UI shows **min/max RPM** instead of Hz summary chips.

**Manual Modbus (experimental)** — User-defined FC3/FC6 holding-register map. See [modbus-manual-experimental.md](modbus-manual-experimental.md).

---

## Saving configuration

1. **Save to arborctl-user-vars.g** — Writes `M575`, `arborVFDConfig`, `arborMotorSpec`, `arborWizardFreqLimits`, and (if Manual is selected) `arborModbusManualSpec`.
2. **Save & run VFD config macro** — Uploads the file, runs `M98 P"0:/sys/arborctl-user-vars.g"`, then `M98 P"arborctl/<driver>/config.g"`.

---

## Live spindle telemetry

When ArborCTL is loaded, the panel lists **configured** spindles with Comm / Run / Dir / Hz / RPM / Stable / Power / Load from the object model globals above.

---

## Test Modbus (diagnostic)

**Test Modbus** sends a **single probe** using baud, UART channel, and slave address from the form (no save required). Check the **Duet console**.

| Driver | Mechanism | Macro |
|--------|-----------|-------|
| Huanyang | Raw-frame (`M2604`) | `huanyang-quick-probe.g` |
| All others | FC3 holding register | `modbus-fc3-probe.g` |

**Default FC3 register `R` (decimal):**

- **TH Servo:** 4096  
- **Shihlin:** 90 (`0x005A`)  
- **Yalang:** 3329 (`0x0D01`)  
- **H100:** 5 (`0x0005`, F005)  
- **Manual:** probe reg if ≥ 0, else freq-write reg  
- **Fallback:** 5000  

---

## File map (reference)

| Path | Role |
|------|------|
| `dwc-plugin/dwc-src/ArborCTL.vue` | Plugin UI |
| `dwc-plugin/dwc-src/compat/dwcStore.ts` | Pinia Vuex-shaped shim |
| `dwc-plugin/plugin.json` | Plugin id / DWC version / `data.nxt` |
| `sd/sys/plugins/arborctl/*.g` | NeXT catalog entrypoints |
| `macro/private/h100/*` | H100 driver |
| `macro/private/modbus-fc3-probe.g` | Shared FC3 test read |

---

## Troubleshooting

- **Plugin missing in `npm run dev`:** Real copy (not junction); clear localhost site data.
- **Test Modbus always fails:** Baud, address, AUX port, termination, VFD powered; for FC3 confirm register `R`.
- **Telemetry empty:** Daemon running (standalone `daemon.g` or NeXT dispatcher), spindle configured, `arborVFDCommReady` true after config.
