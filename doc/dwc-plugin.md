# ArborCTL DWC plugin (`dwc-plugin/`)

The **ArborCTL** panel in [Duet Web Control](https://github.com/Duet3D/DuetWebControl) (DWC) is the canonical configuration UI: a single-page editor for `0:/sys/arborctl-user-vars.g`, optional **Manual Modbus** register maps, live **telemetry**, and **Modbus test** probes.

**Prerequisites:** RepRapFirmware **3.7+** (3.6 macros still run; plugin ZIP targets DWC 3.7), ArborCTL loaded (`M98 P"arborctl.g"` in `config.g`), host DWC version matching the ZIP’s exact `dwcVersion`.

**Stack (3.7):** Vue 3 + Vuetify 4 Options API, Pinia via [`dwc-src/compat/dwcStore.ts`](../dwc-plugin/dwc-src/compat/dwcStore.ts), registration from `@/plugins` (not Vue 2 `@/routes` / `@/store`).

---

## Installing the plugin

**Production:** Download **`ArborCTL-<version>.zip`** from GitHub **Releases** (built by CI when a **`v*`** tag is pushed), or build locally with **`dist/build-dwc-plugin.sh`**. Upload the ZIP through DWC **System → Files**; do not unzip on the PC before upload.

**Upgrading an existing install:** Pause the ArborCTL daemon first (**Pause daemon** on the plugin page, or `M98 P"arborctl/prepare-plugin-update.g"`). The daemon holds numbered metas such as `0:/sys/M2604.g` open while polling; DSF cannot replace them until the file is closed. Wait for the console echo (~5 s), then upload the ZIP. **Resume daemon** (`S1`) or reboot applies pending `*.install` files and restarts polling. The first upgrade from a ZIP that still listed live `M2604.g` **must** pause; later ZIPs ship `M2604.install` and usually do not need a pause.

**NeXT / data.nxt:** The ZIP also ships `sd/sys/plugins/arborctl/{arborctl-init,arborctl-daemon-hook}.g`. When NeXT’s catalog includes ArborCTL, the daemon dispatcher calls the hook (which runs `arborctl-daemon.g`). Standalone installs still use `sys/daemon.g.example`.

**Development:** See [dwc-development.md](dwc-development.md).

---

## Object model fields (read by the UI)

The panel reads **user globals** from `state.machine.model.global` (with a fallback to `machine.variables` in some DWC builds):

| Global | Purpose |
|--------|---------|
| `arborctlLdd` | ArborCTL loaded |
| `arborctlVer` | Version string |
| `arborVFDConfig` | Per-spindle `{ typeIndex, channel, address }` (type index selects the DWC catalog / driver folder) |
| `arborMotorSpec` | Per-spindle motor nameplate vector |
| `arborModbusManualSpec` | Manual Modbus 11-int register map (see [modbus-manual-experimental.md](modbus-manual-experimental.md)) |
| `arborVFDStatus` | Per-spindle `{ running, dir, Hz, RPM, stable }` |
| `arborVFDPower` | Per-spindle `{ watts, loadPercent }` — meaning depends on driver |
| `arborVFDCommReady` | Per-spindle comm gate after successful config probe |
| `arborMaxLoad` | Threshold (%) for overload feed logic in `control-spindle.g` |
| `arborctlDaemonEnabled` | Runtime poll gate; `false` while paused for plugin update |

Until you connect to a board, many fields are empty; the form still renders.

---

## VFD models (order in `arborctlApply.ts`)

| Index | Label | Internal folder |
|------|--------|-----------------|
| 0 | Shihlin SL3 | `shihlin-sl3` |
| 1 | Huanyang HY02D223 | `huanyang-hy02d223b` |
| 2 | Yalang YL620-A | `yalang-yl620a` |
| 3 | Manual Modbus (experimental) | `modbus-manual-experimental` |
| 4 | TH Servo (preliminary) | `th-servo` |
| 5 | H100 | `h100` |

**H100** — Standard Modbus RTU (FluidNC-compatible). See [h100-notes.md](h100-notes.md). Load % comes from the FC4 monitor block (output current, or native output power when the reply includes it).

**TH Servo (preliminary)** — RS485 servo spindle support. The UI shows **min/max RPM** instead of Hz summary chips.

**Manual Modbus (experimental)** — User-defined FC3/FC6 holding-register map. See [modbus-manual-experimental.md](modbus-manual-experimental.md).

---

## Saving configuration

1. **Save to arborctl-user-vars.g** — Writes `M575`, `arborVFDConfig`, `arborMotorSpec`, `arborWizardFreqLimits`, `arborWizardRamp`, and (if Manual is selected) `arborModbusManualSpec`.
2. **Save & run VFD config macro** — Uploads the file, runs `M98 P"0:/sys/arborctl-user-vars.g"`, then `M98 P"arborctl/<driver>/config.g"`.

---

## Live spindle telemetry

When ArborCTL is loaded, the panel lists **configured** spindles with Comm / Run / Dir / Hz / RPM / Stable / Power / Load from the object model globals above. **H100** estimates load from FC4 output current (Huanyang-style V×I) or native register `000C` when present; short clones stay at 0.

**Spindle-delay wait (`G4.9`):** ArborCTL’s numbered meta `G4.9 S<spindle>` waits until `arborVFDStatus[S][4]` (stable) is true after a speed/run change. It is the VFD ramp settle wait (default max from `arborWizardRamp`, else 30 s) — not NeXT `M3.9` / `M5.9` timed dwells. Already-stable spindles return immediately. Do not call `G4.9` from the daemon input.

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
| `macro/gcodes/*.g` | Numbered metas; ZIP stages them as `sd/sys/*.install` |
| `macro/private/prepare-plugin-update.g` | Pause / resume daemon for ZIP upgrade |
| `macro/private/apply-sys-gcodes.g` | `M471` `*.install` → live `M2600.g` / `M2604.g` / … |
| `macro/private/h100/*` | H100 driver |
| `macro/private/modbus-fc3-probe.g` | Shared FC3 test read |

---

## Troubleshooting

- **Plugin missing in `npm run dev`:** Real copy (not junction); clear localhost site data.
- **Test Modbus always fails:** Baud, address, UART channel (RRF 3.7: P2 first UART / Scylla RS485), termination, VFD powered; for FC3 confirm register `R`.
- **Telemetry empty:** Daemon running (standalone `daemon.g` or NeXT dispatcher), spindle configured, `arborVFDCommReady` true after config. If you paused for a plugin update, click **Resume daemon** (or reboot).
- **Plugin update fails (`M2604.g` in use / used by another process):** The Huanyang daemon tick keeps `0:/sys/M2604.g` open. Pause the daemon, wait for the console echo, then retry the ZIP. First upgrade from older ZIPs that listed live numbered metas always needs this pause; see [Installing the plugin](#installing-the-plugin).
- **`meta command: GCode command too long`:** Known RRF parser limit. In ArborCTL macro sources, avoid very long single lines (especially large `if { ... }` expressions and long string assignments). Split logic into temporary variables and build long messages in multiple `set` steps.

For upstream packaging and CNC dashboard defaults, see [dwc-development.md](dwc-development.md).

