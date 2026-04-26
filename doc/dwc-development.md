# DWC plugin development (ArborCTL)

Duet Web Control loads **third-party plugin ZIPs only in production builds**. In `npm run dev`, `loadDwcResources` refuses external chunks. The supported workflow is to treat ArborCTL like a **built-in plugin**: copy this repository's `dwc-plugin` folder into the DWC tree as `src/plugins/ArborCTL` (same layout as a packaged plugin: `plugin.json` + `dwc-src/`).

DWC **3.7+** discovers plugins under `src/plugins/*/plugin.json` (Vite / virtual builtin plugins). Older **3.6.x** trees used webpack `auto-imports-plugin.js`.

## Windows: use Copy, not a junction

On Windows, a **directory junction** to your repo is often reported by Node as a **symbolic link** with `Dirent.isDirectory() === false`. The auto-import plugin only keeps **directory** entries, so **ArborCTL is silently omitted**. Use a real recursive copy (or run the setup script under WSL).

## Prerequisites

- **Node.js** **^20.19 or ≥22.12** (22 LTS recommended) for DWC 3.7 Vite/rolldown builds
- A **matching DuetWebControl** tree. `plugin.json` uses `"dwcVersion": "auto"` — build against the host you will run (reference pin: **`v3.7.0-beta.1`**, same as NeXT `v0.7.0`).

Clone and install:

```text
git clone https://github.com/Duet3D/DuetWebControl.git
cd DuetWebControl
git checkout v3.7.0-beta.1
npm install
```

## One-time setup (macOS / Linux / WSL)

```bash
chmod +x tools/setup-dwc-dev.sh
./tools/setup-dwc-dev.sh /path/to/DuetWebControl
```

The script symlinks `dwc-plugin` into `src/plugins/ArborCTL`. After `npm run dev`, enable **ArborCTL** under **Settings → Plugins**.

## One-time setup (Windows, plain shell)

```powershell
xcopy /E /I .\dwc-plugin C:\path\to\DuetWebControl\src\plugins\ArborCTL
```

Then enable **ArborCTL** under **Settings → Plugins** in the running dev server.

## Run the dev server

```bash
cd /path/to/DuetWebControl
npm run dev
```

Open the URL printed in the terminal. Use the sidebar **Plugins → ArborCTL**.

Feature reference (telemetry, Test Modbus, TH Servo UI, Manual Modbus, H100): [dwc-plugin.md](dwc-plugin.md).

## CNC appearance vs machine mode

**Dashboard mode “CNC”** in DWC (Settings → General → Appearance) only changes the **web UI**. The **machine mode** (FFF vs CNC) still comes from **RepRapFirmware** when you connect to a board.

## Connect to a real board

Use the connection dialog as usual. On **RRF 3.7**, HTTP must be enabled (`M586 P0 S1`). For a browser on another host, you may need CORS on the Duet (`M586 C"*"`) — use only on trusted networks.

## Production plugin ZIP

```bash
bash dist/build-dwc-plugin.sh /path/to/DuetWebControl v0.7.0
# Output: dist/ArborCTL-0.7.0.zip
```

Release CI clones **DWC `v3.7.0-beta.1`**. The ZIP’s `dwcVersion` must **exactly** match the host DWC.

## Troubleshooting

- **Plugin missing in `npm run dev`:** Use a real recursive copy, not a junction on Windows; re-run `setup-dwc-dev.sh`; clear site data for `localhost` if old DWC `localStorage` hides the plugin.
- **Compile / Vite errors:** Match DWC checkout to the version you build against; use Node ≥20.19.
- **Disconnected / empty globals:** The UI still renders; object model fields fill in after connecting to a board.
- **`meta command: GCode command too long` on RRF:** Keep ArborCTL macro source lines short. Very long single-line expressions (especially `if { ... }` chains and long string literals) can exceed RRF parser limits; split into helper vars and incremental string concatenation.

