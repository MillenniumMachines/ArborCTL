# ArborCTL

**ArborCTL** is a macro framework for [RepRapFirmware](https://github.com/Duet3D/RepRapFirmware) **3.6+ / 3.7+** that implements **RS-485 / Modbus RTU** spindle control, status feedback, and optional load-aware behaviour across several VFD (and experimental servo) profiles. The DWC plugin targets **Duet Web Control 3.7** (Vue 3 / Vite; rebuild the ZIP against your host DWC version).

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
- **Drivers** under `0:/sys/arborctl/<model>/` — Shihlin SL3, Huanyang HY02D223, Yalang YL620-A, **Manual Modbus (experimental)**, **TH Servo (preliminary)**, **H100**.
- **Daemon** (`arborctl-daemon.g`) polling VFDs and filling **object model** globals (`arborVFDStatus`, `arborVFDPower`, etc.). With **NeXT**, polling is via the `data.nxt` daemon hook (catalog plugin).
- **[Duet Web Control](https://github.com/Duet3D/DuetWebControl) plugin** — one-page editor (the canonical configuration UI), live telemetry, **Test Modbus** probes.

---

## Documentation

| Doc | Contents |
|-----|----------|
| **[doc/vfd-modbus-maps.md](doc/vfd-modbus-maps.md)** | Supported drives: Modbus (and Huanyang) registers ArborCTL uses |
| **[doc/dwc-plugin.md](doc/dwc-plugin.md)** | DWC UI: fields, object model, telemetry, Test Modbus, troubleshooting |
| **[doc/dwc-development.md](doc/dwc-development.md)** | Local `npm run dev` with a DWC checkout |
| **[doc/modbus-manual-experimental.md](doc/modbus-manual-experimental.md)** | Manual Modbus 11-int register map |
| **[doc/hy02d223b-protocol-notes.md](doc/hy02d223b-protocol-notes.md)** | Huanyang protocol notes |
| **[doc/h100-notes.md](doc/h100-notes.md)** | H100 Modbus map and panel RS485 setup |
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
6. **Reset** the board. On first boot, ArborCtl will ask you to configure the spindle from the **DWC ArborCTL plugin**. Open it, fill in the form, click **Save & run VFD config macro**, then reset.

---

## Supported drives

Model list lives in **`dwc-plugin/dwc-src/arborctlApply.ts`** (`FALLBACK_ARBOR_MODELS` / `FALLBACK_ARBOR_INTERNAL_NAMES`); firmware picks the driver from a **local** id vector in **`control-spindle.g`** (not `key=global`). Defaults for address/baud stay in **`sys/arborctl-vars.g`**. Current entries include Shihlin, Huanyang, Yalang, Manual Modbus (experimental), TH Servo (preliminary), and **H100**. Each has **`config.g`**, **`control.g`**, and usually **`settings.g`** under **`macro/private/<internal-name>/`** (installed to **`0:/sys/arborctl/`**). Registers, function codes, and scales: **[doc/vfd-modbus-maps.md](doc/vfd-modbus-maps.md)**.

---

## DWC plugin

The **ArborCTL** panel is the canonical configuration UI. It edits **`arborctl-user-vars.g`**, supports **Manual Modbus** and **TH Servo** UX (e.g. RPM labelling for TH Servo), shows **load / telemetry**, and runs **Test Modbus** without saving. Details: **[doc/dwc-plugin.md](doc/dwc-plugin.md)**.

**Development** (hot reload): copy **`dwc-plugin/`** into a DWC **3.7.x** tree as **`src/plugins/ArborCTL`**, run **`tools/setup-dwc-dev.sh`** (or copy by hand on Windows), then **`npm run dev`**. See **[doc/dwc-development.md](doc/dwc-development.md)**. Local DWC clones (e.g. **`dwc-env/`**) are **gitignored**.

---

## Releases and packaging

**Official downloads are the DWC plugin ZIP only:** [**GitHub Releases**](https://github.com/MillenniumMachines/ArborCTL/releases), asset **`ArborCTL-<version>.zip`** (Vue UI + embedded **`sd/`** tree: `sys/`, `sys/arborctl/`, numbered metas as `*.install`, macros). Users install it through DWC **System → Files** upload. When upgrading an existing install, pause the daemon first (ArborCTL panel **Pause daemon**, or `M98 P"arborctl/prepare-plugin-update.g"`) so DSF can replace open files such as `M2604.g` — see [doc/dwc-plugin.md](doc/dwc-plugin.md).

### GitHub Releases (CI)

- Workflow: **[`.github/workflows/release.yml`](.github/workflows/release.yml)**.
- **Trigger:** push a **semver git tag** (`vMAJOR.MINOR.PATCH`, `v…-beta.N`, or `v…-rcN`, e.g. **`v0.2.0`**). Other `v*` tags are rejected by [`dist/verify-release-tag.sh`](dist/verify-release-tag.sh).
- **Action:** clones **DuetWebControl `v3.7.0-beta.1`**, runs **`npm install`**, resolves the version from the tag ([`dist/resolve-build-version.sh`](dist/resolve-build-version.sh)), runs **[`dist/build-dwc-plugin.sh`](dist/build-dwc-plugin.sh)** (no version argument), uploads **`dist/ArborCTL-<semver>.zip`** to a **published** GitHub Release (not draft) with generated release notes.

**Publish a release:**

```bash
git tag v0.2.0
git push origin v0.2.0
```

Use a **semver** tag. **Pre-releases:** `v0.2.0-rc1` or `v0.2.0-beta.1` (CI still publishes; mark as pre-release in the GitHub UI if needed).

### Manual build (maintainers)

Requires a **DuetWebControl** checkout with **`npm install`** (DWC **3.7.x**; `plugin.json` uses `dwcVersion: "auto"` so the ZIP stamps the exact host version). Node **^20.19 or ≥22.12**. Use Git Bash / WSL on Windows.

Version is **not** a CLI argument — it comes from git tags (exact tag on HEAD, otherwise the nearest tag). On an untagged commit the ZIP is `ArborCTL-<semver>-<sha>[-dirty].zip`.

```bash
cd /path/to/ArborCTL
bash dist/build-dwc-plugin.sh /path/to/DuetWebControl
# On tag v0.2.0: dist/ArborCTL-0.2.0.zip
# Untagged:      dist/ArborCTL-0.2.0-<sha>[-dirty].zip
```

### `dist/` folder

- **`dist/ArborCTL-<semver>.zip`** (or `…-<sha>[-dirty].zip` off-tag) is a local build output for maintainers.
- End users should download from **GitHub Releases** (canonical location).

---

## Development

- **Firmware / macros:** edit **`sys/`**, **`macro/`**; test on hardware or the Duet simulator where applicable.
- **Plugin:** edit **`dwc-plugin/dwc-src/`**; sync into a DWC tree for `npm run dev`.
- **Version string:** `%%ARBORCTL_VERSION%%` in **`sys/arborctl.g`** and packaged files is replaced at build/release time from the resolved git tag (no leading `v`).

---

## Safety

This project is **alpha / experimental** in areas (Manual Modbus, TH Servo). Always follow **safe spindle** practices: estop, interlocks, and verifying Modbus wiring and parameters before full-speed runs. **Testing is welcome; use at your own risk.**
