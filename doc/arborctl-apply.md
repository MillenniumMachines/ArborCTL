# ArborCTL Apply contract

Operator path used by the ArborCTL DWC plugin (**Apply VFD config**) and the nxt **VFD** tab when ArborCTL is installed:

1. Upload/write `0:/sys/arborctl-user-vars.g` (`arborVFDConfig[S] = {typeIndex, uart, address}`, motor/Hz specs).
2. `M98 P"0:/sys/arborctl-user-vars.g"` so OM updates without requiring reboot when already loaded.
3. `M98 P"arborctl/<internal>/config.g" …` → closes `arborVFDCommReady`, UART/`M575`, Modbus probe (with channel fallback), then sets CommReady true.
4. Daemon (NeXT `plugins/arborctl/arborctl-daemon-hook.g` or standalone `arborctl-daemon.g`) → `control-spindle.g` → that driver’s `control.g`.

Shared builders live in:

- ArborCTL: `dwc-plugin/dwc-src/arborctlApply.ts`
- NeXT (mirror): `ui/src/utils/arborctlApply.ts`

Keep both files in sync when changing the user-vars format or config.g argument list.

## Driver index matrix (append-only)

| Index | Display name | Internal folder | Default addr | Default baud | Probe | Test Modbus |
|------:|--------------|-----------------|-------------:|-------------:|-------|-------------|
| 0 | Shihlin SL3 | `shihlin-sl3` | 1 | 9600 | FC3 `@ 0x005A` via `uart-channel-probe.g` | `modbus-fc3-probe.g` |
| 1 | Huanyang HY02D223 | `huanyang-hy02d223b` | 1 | 9600 | custom `M2604` (channel fallback in config / quick-probe) | `huanyang-quick-probe.g` |
| 2 | Yalang YL620-A | `yalang-yl620a` | **10** | **19200** | FC3 `@ 0x0d01` via `uart-channel-probe.g` | `modbus-fc3-probe.g` |
| 3 | Manual Modbus (experimental) | `modbus-manual-experimental` | 1 | 9600 | FC3 `@ arborModbusManualSpec[S][10]` | `modbus-fc3-probe.g` |
| 4 | TH Servo (preliminary) | `th-servo` | 1 | **19200** | FC3 `@ 4096` via `uart-channel-probe.g` | `modbus-fc3-probe.g` |
| 5 | H100 | `h100` | 1 | 9600 | FC3 `@ 0x0005` via `uart-channel-probe.g` | `modbus-fc3-probe.g` |

Defaults come from `arborModelDefaultAddress` / `arborModelDefaultBaudRateIndex` in `sys/arborctl-vars.g` (`BAUD_LIST` index 1=9600, 2=19200).

Do not renumber existing indices (saved `arborctl-user-vars.g` ABI).

## Modbus bring-up (all drivers)

1. **`arborVFDCommReady[S]=false`** at `config.g` start (daemon cannot interleave).
2. **`M575 … S7`** then probe. FC3 drivers use **`uart-channel-probe.g`**
   (preferred UART `C`, then **2**, **3**, then **1**). Huanyang uses the same
   candidate order with `M2604`.
   On RRF 3.7: **P2** is the first UART (Scylla RS485 PA9/PA10 once
   `serial.aux.rxTxPins={A.10, A.9}` is set); **P3** is aux2 (PD8/PD9 header);
   **P0/P1** are USB CDC and are **not** offered in the UI. Apply defaults to P2;
   a saved USB channel is coerced to P2.
3. On success, update `arborVFDConfig[S][1]` and optionally append a corrected line to `arborctl-user-vars.g`.
4. Set **`arborVFDCommReady[S]=true`** only after a successful probe (and after config writes where the driver performs them).
5. Runtime pacing: Huanyang uses `G4 P250`; other drivers use `delay-for-command.g` (default **100 ms**, **`S250`** on control write/status paths).

## Validation checklist (per model)

1. Apply writes correct `typeIndex` + runs `arborctl/<internal>/config.g`.
2. Probe succeeds → `arborVFDCommReady[S]=true` (and `arborProbeChannel` set for FC3).
3. Daemon `control.g` issues Modbus (no early return from `control-spindle.g`).
4. Test Modbus from ArborCTL advanced panel returns OK for that driver’s probe.
