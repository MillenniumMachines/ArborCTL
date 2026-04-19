# DWC plugin development (ArborCTL)

Duet Web Control loads **third-party plugin ZIPs only in production builds**. In `npm run dev`, `loadDwcResources` refuses external chunks. The supported workflow is to treat ArborCTL like a **built-in plugin**: copy this repository’s `dwc-plugin` folder into the DWC tree as `src/plugins/ArborCTL` (same layout as a packaged plugin: `plugin.json` + `dwc-src/`).

DWC’s webpack plugin (`webpack/lib/auto-imports-plugin.js`) scans `src/plugins/*/plugin.json` and registers `dwc-src/index.ts` in development, so you get **hot module reload** while editing `ArborCTL.vue`.

## Windows: use Copy, not a junction

On Windows, a **directory junction** to your repo is often reported by Node as a **symbolic link** with `Dirent.isDirectory() === false`. The auto-import plugin only keeps **directory** entries, so **ArborCTL is silently omitted** from `src/plugins/imports.ts` and never loads. The setup script therefore defaults to **Copy** mode (a real folder under `src/plugins/ArborCTL`).

## Prerequisites

- **Node.js** LTS and npm
- A **matching DuetWebControl** tree. `dwc-plugin/plugin.json` declares `"dwcVersion": "3.6"` — use a **3.6.x** DWC tag (e.g. `v3.6.1`).

Clone and install:

```text
git clone https://github.com/Duet3D/DuetWebControl.git
cd DuetWebControl
git checkout v3.6.1
npm install
```

## One-time setup (Windows)

From the ArborCTL repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\setup-dwc-dev.ps1 -DwcRepo C:\path\to\DuetWebControl
```

This **copies** `dwc-plugin` into `src/plugins/ArborCTL`, sets `plugin.json` version to `dev` (replacing the release placeholder), patches **default enabled plugins** to include `ArborCTL`, and sets the **default DWC dashboard** to **CNC** (`DashboardMode.cnc`) for the local UI.

Optional: omit CNC default with `-CncDashboard:$false`.

## One-time setup (macOS / Linux)

```bash
chmod +x tools/setup-dwc-dev.sh
cp -r dwc-plugin /path/to/DuetWebControl/src/plugins/ArborCTL
# Manually add "ArborCTL" to default enabledPlugins in src/store/settings.ts (see Windows script), or enable in Settings → Plugins after start.
```

## Run the dev server

```bash
cd /path/to/DuetWebControl
npm run dev
```

Open the URL printed in the terminal (often `http://localhost:8080`). Use the sidebar **Plugins → ArborCTL**.

Feature reference (telemetry, Test Modbus, TH Servo UI, Manual Modbus): [dwc-plugin.md](dwc-plugin.md).

## CNC appearance vs machine mode

**Dashboard mode “CNC”** in DWC (Settings → General → Appearance, or the setup script default) only changes the **web UI** (panels, icons). The **machine mode** (FFF vs CNC) still comes from **RepRapFirmware** when you connect to a board (`state.machineMode` in the object model).

## Connect to a real board

Use the connection dialog as usual. For a browser on another host, you may need CORS on the Duet (`M586 C"*"` in `config.g`) — see DWC’s README; use only on trusted networks.

## Production plugin ZIP (unchanged)

Release builds still use `dist/build-dwc-plugin.ps1`; that does **not** require `src/plugins/ArborCTL` in the DWC tree.

## Troubleshooting

- **`imports.ts` has no ArborCTL**: You likely used a **junction** on Windows; remove `src/plugins/ArborCTL` and re-run the setup script (Copy mode).
- **Plugin still not listed after fix**: **Clear site data** for `http://localhost:8080` (old `settings` in localStorage can override new defaults and skip loading ArborCTL).
- **Compile errors**: Match DWC version to `dwcVersion` in `plugin.json`.
- **Disconnected / empty globals**: The UI still renders; object model fields fill in after connecting to a board.
