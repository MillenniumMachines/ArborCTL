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

1. **Get a release asset** (recommended): GitHub **Releases** → download **`arborctl-release-<tag>.zip`** for a tagged version — *not* “Source code” from the green Code button.
2. In **Duet Web Control** → **System** → **Files**, **upload the ZIP as a single file** (do **not** unzip on your PC first).
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

There are **two different ZIPs** people confuse:

| Artifact | What it is | How it is produced |
|----------|------------|-------------------|
| **SD card bundle** | `sys/`, `sys/arborctl/`, `sys/*.g` gcodes, `macros/ArborCtl/` — what you upload to the **Duet** | **[`dist/release.sh`](dist/release.sh)** (bash): copies from **`sys/`**, **`macro/public/`**, **`macro/private/`**, **`macro/gcodes/`**, substitutes **`%%ARBORCTL_VERSION%%`** with `git describe`, zips to **`dist/<chosen-name>.zip`** |
| **DWC plugin only** | Installable DWC plugin (UI + embedded SD layout for the plugin package) | **[`dist/build-dwc-plugin.ps1`](dist/build-dwc-plugin.ps1)** (PowerShell): needs a **DuetWebControl** clone with **`npm install`**, runs DWC’s **`scripts/build-plugin-pkg.js`**; writes **`dist/ArborCTL-<version>.zip`** |

### GitHub Releases (CI)

- Workflow: **[`.github/workflows/release.yml`](.github/workflows/release.yml)**.
- **Trigger:** push a **git tag** matching **`v*`** (e.g. **`v0.1.0`**).
- **Action:** runs **`dist/release.sh arborctl-release-$TAG_NAME`**, uploads **`dist/arborctl-release-<tag>.zip`** to a **draft** GitHub Release (publish the draft when ready).
- **Note:** this workflow builds the **SD bundle** only. The **DWC plugin ZIP** is **not** built in CI today; build it locally with **`build-dwc-plugin.ps1`** if you need to attach it to the release manually.

### Should you create a GitHub Release?

- **Yes**, when you want users to download a **versioned, tested** SD bundle from **Releases** — matches the README “download from Releases” flow.
- Use a **semver tag** (`v0.2.0`), write release notes (what changed, any config migration), publish the draft release.
- **Pre-releases** are fine for alpha (`v0.2.0-rc1` + mark prerelease in GitHub).

### The `dist/` folder

- **`dist/`** is the **output directory** for scripts (`release.sh`, `build-dwc-plugin.ps1`).
- **`dist/_runtime_stage/`** is a **staged mirror** of macros/sys for review or packaging; **`release.sh`** reads **`macro/`** and **`sys/`** at the repo root, not `_runtime_stage` — keep sources in sync when you change drivers.
- **Committing `*.zip` into `dist/`** is optional. Some repos track release artifacts for convenience; others gitignore them and only attach zips to GitHub Releases. **Do not** rely on random ad-hoc zips in `dist/` as the official distribution path unless they are named and documented — **tagged Releases** are clearer for end users.

### Manual build (maintainers)

**Linux / macOS / WSL** (SD bundle):

```bash
cd /path/to/ArborCTL
bash dist/release.sh arborctl-release-$(git describe --tags --always).zip
# Output: dist/arborctl-release-<name>.zip
```

**Windows** (DWC plugin — adjust `-DwcRepo`):

```powershell
cd ArborCTL
powershell -ExecutionPolicy Bypass -File .\dist\build-dwc-plugin.ps1 -DwcRepo C:\path\to\DuetWebControl-3.6.1
# Output: dist\ArborCTL-<version>.zip
```

---

## Development

- **Firmware / macros:** edit **`sys/`**, **`macro/`**; test on hardware or the Duet simulator where applicable.
- **Plugin:** edit **`dwc-plugin/dwc-src/`**; sync into a DWC tree for `npm run dev`.
- **Version string:** `%%ARBORCTL_VERSION%%` in **`sys/arborctl.g`** and packaged files is replaced at build/release time.

---

## Safety

This project is **alpha / experimental** in areas (Manual Modbus, TH Servo). Always follow **safe spindle** practices: estop, interlocks, and verifying Modbus wiring and parameters before full-speed runs. **Testing is welcome; use at your own risk.**
