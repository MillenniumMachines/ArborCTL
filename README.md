# ArborCTL

**ArborCTL** is a macro framework for [RepRapFirmware](https://github.com/Duet3D/RepRapFirmware) **3.6+** that implements **RS-485 / Modbus RTU** spindle control, status feedback, and optional load-aware behaviour across several VFD (and experimental servo) profiles.

---

## Table of contents

- [What you get](#what-you-get)
- [Documentation](#documentation)
- [Quick start (machine install)](#quick-start-machine-install)
- [Supported drives](#supported-drives)
- [DWC plugin](#dwc-plugin)
- [Releases and packaging](#releases-and-packaging)
- [Development](#development)
- [Safety](#safety)

---

## What you get

- **Per-spindle configuration** (UART, baud, Modbus address, motor nameplate, Hz limits from RRF).
- **Drivers** under `0:/sys/arborctl/<model>/` — Shihlin SL3, Huanyang HY02D223, Yalang YL620-A, **Manual Modbus (experimental)**, **TH Servo (preliminary)**.
- **Daemon** (`arborctl-daemon.g`) polling VFDs and filling **object model** globals (`arborVFDStatus`, `arborVFDPower`, etc.).
- **Optional [Duet Web Control](https://github.com/Duet3D/DuetWebControl) plugin** — one-page editor, live telemetry, **Test Modbus** probes.

---

## Documentation

| Doc | Contents |
|-----|----------|
| **[doc/dwc-plugin.md](doc/dwc-plugin.md)** | DWC UI: fields, object model, telemetry, Test Modbus, troubleshooting |
| **[doc/dwc-development.md](doc/dwc-development.md)** | Local `npm run dev` with a DWC checkout, Windows Copy vs junction |
| **[doc/modbus-manual-experimental.md](doc/modbus-manual-experimental.md)** | Manual Modbus 11-int register map |
| **[doc/hy02d223b-protocol-notes.md](doc/hy02d223b-protocol-notes.md)** | Huanyang protocol notes |
| **`sys/config.g.example`**, **`sys/daemon.g.example`** | Snippets for your board |

---

## Quick start (machine install)

1. **Get the DWC plugin ZIP** from GitHub **Releases**: [**latest release**](https://github.com/MillenniumMachines/ArborCTL/releases/latest), asset name **`ArborCTL-<version>.zip`** (e.g. **`ArborCTL-0.2.0.zip`**) — built by CI from each **`v*`** tag. Do *not* download “Source code” from the green **Code** button unless you intend to build from source.
2. In **Duet Web Control** → **System** → **Files**, **upload that ZIP as a single file** (do **not** unzip on your PC first). DWC installs the plugin and deploys the bundled on-card files.
3. Add to the end of **`0:/sys/config.g`**:

   ```gcode
   M98 P"arborctl.g"
   ```

4. Configure your **spindle** in RRF (pins, tool, limits) *before* that line; enable/direction/speed must be defined even if unused.
5. Merge **`sys/daemon.g.example`** ideas into your **`0:/sys/daemon.g`** so the daemon runs (include **`arborctl-daemon.g`** as in the example).
6. **Reset** the board. If no user vars exist, the **G8001** wizard can run; otherwise use the **DWC ArborCTL** plugin or edit **`0:/sys/arborctl-user-vars.g`**.

---

## Supported drives

Model list and defaults live in **`sys/arborctl-vars.g`** (`arborAvailableModels`, `arborModelInternalNames`). Current entries include Shihlin, Huanyang, Yalang, Manual Modbus (experimental), and TH Servo (preliminary). Each has **`config.g`**, **`control.g`**, and usually **`settings.g`** under **`macro/private/<internal-name>/`** (installed to **`0:/sys/arborctl/`**).

---

## DWC plugin

The **ArborCTL** panel (optional) edits **`arborctl-user-vars.g`**, supports **Manual Modbus** and **TH Servo** UX (e.g. RPM labelling for TH Servo), shows **load / telemetry**, and runs **Test Modbus** without saving. Details: **[doc/dwc-plugin.md](doc/dwc-plugin.md)**.

**Development** (hot reload): copy **`dwc-plugin/`** into a DWC **3.6.x** tree as **`src/plugins/ArborCTL`**, run **`tools/setup-dwc-dev.ps1`**, then **`npm run dev`**. See **[doc/dwc-development.md](doc/dwc-development.md)**. Local DWC clones (e.g. **`dwc-env/`**) are **gitignored**.

---

## Releases and packaging

**Official downloads are the DWC plugin ZIP only:** [**GitHub Releases**](https://github.com/MillenniumMachines/ArborCTL/releases), asset **`ArborCTL-<version>.zip`** (Vue UI + embedded **`sd/`** tree: `sys/`, `sys/arborctl/`, gcodes, macros). Users install it through DWC **System → Files** upload.

### GitHub Releases (CI)

- Workflow: **[`.github/workflows/release.yml`](.github/workflows/release.yml)**.
- **Trigger:** push a **git tag** matching **`v*`** (e.g. **`v0.2.0`**).
- **Action:** clones **DuetWebControl `v3.6.1`**, runs **`npm install`**, runs **[`dist/build-dwc-plugin.sh`](dist/build-dwc-plugin.sh)** (same staging as **[`dist/build-dwc-plugin.ps1`](dist/build-dwc-plugin.ps1)**), uploads **`dist/ArborCTL-<version>.zip`** to a **published** GitHub Release (not draft) with generated release notes.

**Publish a release:**

```bash
git tag v0.2.0
git push origin v0.2.0
```

Use a **semver** tag. **Pre-releases:** create a pre-release in the GitHub UI after the workflow runs, or use a tag like `v0.2.0-rc1` and adjust release metadata as needed.

### Manual build (maintainers)

Requires a **DuetWebControl** checkout with **`npm install`** (same **3.6.x** line as **`dwc-plugin/plugin.json`** `dwcVersion`).

**Linux / macOS / WSL:**

```bash
cd /path/to/ArborCTL
bash dist/build-dwc-plugin.sh /path/to/DuetWebControl v0.2.0
# Output: dist/ArborCTL-0.2.0.zip
```

**Windows:**

```powershell
cd ArborCTL
powershell -ExecutionPolicy Bypass -File .\dist\build-dwc-plugin.ps1 -DwcRepo C:\path\to\DuetWebControl-3.6.1 -Version 0.2.0
```

### `dist/` folder

- **`dist/_runtime_stage/`** — optional mirror of staged files for review; **not** what CI uses (CI stages from **`sys/`** and **`macro/`** via the build scripts above).
- **`dist/ArborCTL-<version>.zip`** is a local build output for maintainers.
- End users should download from **GitHub Releases** (canonical location).

---

## Development

- **Firmware / macros:** edit **`sys/`**, **`macro/`**; test on hardware or the Duet simulator where applicable.
- **Plugin:** edit **`dwc-plugin/dwc-src/`**; sync into a DWC tree for `npm run dev`.
- **Version string:** `%%ARBORCTL_VERSION%%` in **`sys/arborctl.g`** and packaged files is replaced at build/release time.

---

## Safety

This project is **alpha / experimental** in areas (Manual Modbus, TH Servo). Always follow **safe spindle** practices: estop, interlocks, and verifying Modbus wiring and parameters before full-speed runs. **Testing is welcome; use at your own risk.**
