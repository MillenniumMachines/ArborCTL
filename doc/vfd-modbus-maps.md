# VFD / drive register maps (ArborCTL)

This is **what ArborCTL uses**, not a vendor-manual reprint. Addresses, function codes, and scales come from `macro/private/<model>/control.g` and `settings.g`. Index order matches [`dwc-plugin/dwc-src/arborctlApply.ts`](../dwc-plugin/dwc-src/arborctlApply.ts) (`FALLBACK_ARBOR_MODELS` / `FALLBACK_ARBOR_INTERNAL_NAMES`). **Do not renumber** existing indices (saved `arborctl-user-vars.g` ABI).

Per-driver deep dives:

- [H100 panel RS485 and FC4 monitor](h100-notes.md)
- [Huanyang HY02D223B protocol](hy02d223b-protocol-notes.md)
- [Manual Modbus 11-int spec](modbus-manual-experimental.md)
- [Apply / probe matrix](arborctl-apply.md)

---

## Shared object model

Every driver fills the same per-spindle vectors (see [`sys/arborctl-vars.g`](../sys/arborctl-vars.g)):

| Global | Layout |
|--------|--------|
| `arborVFDStatus[S]` | `{ running, dir, Hz-or-RPM, RPM, stable }` — TH Servo stores RPM in both `[2]` and `[3]` |
| `arborVFDPower[S]` | `{ watts, loadPercent }` — meaning is driver-defined; `{0, 0}` if unavailable |

Helpers:

| Helper | Use |
|--------|-----|
| `M2600` / `M2601` | Standard Modbus **FC6 write** / **FC3 or FC4 read** (with retries) |
| `M260.1 F5` | Coil write (H100 run/stop). Do not use `M2600` — it verifies with FC3 |
| `M2604` | Huanyang **custom** frames (not FC3/FC6) |

`loadPercent` compared to `global.arborMaxLoad` (default 80) in [`macro/private/control-spindle.g`](../macro/private/control-spindle.g) can reduce feed (`M220`).

---

## Index matrix

| Index | Display name | Folder | Default addr | Default baud | Protocol | Test Modbus |
|------:|--------------|--------|-------------:|-------------:|----------|-------------|
| 0 | Shihlin SL3 | `shihlin-sl3` | 1 | 9600 | Modbus RTU FC3/FC6 | FC3 `@ 0x005A` (90) |
| 1 | Huanyang HY02D223 | `huanyang-hy02d223b` | 1 | 9600 | Custom (`M2604`) | `huanyang-quick-probe.g` |
| 2 | Yalang YL620-A | `yalang-yl620a` | **10** | **19200** | Modbus RTU FC3/FC6 | FC3 `@ 0x0D01` (3329) |
| 3 | Manual Modbus (experimental) | `modbus-manual-experimental` | 1 | 9600 | FC3/FC6, user map | FC3 `@ spec[10]` |
| 4 | TH Servo (preliminary) | `th-servo` | 1 | **19200** | Modbus RTU FC3/FC6 | FC3 `@ 4096` |
| 5 | H100 | `h100` | 1 | 9600 | FC3/FC4/FC5/FC6 | FC3 `@ 0x0005` (F005) |

Sources: `arborModelDefaultAddress` / `arborModelDefaultBaudRateIndex` and [`doc/arborctl-apply.md`](arborctl-apply.md).

---

## 0 — Shihlin SL3

Standard Modbus RTU. Files: `macro/private/shihlin-sl3/{config,control,settings}.g`.

### Runtime (control.g)

| Addr (dec) | Hex | FC | Access | Scale / values | ArborCTL use |
|-----------:|-----|----|--------|----------------|--------------|
| 4097 | `0x1001` | 3 / 6 | R/W | See status block | Status; write `0` stop, `2` forward, `4` reverse, `128` e-stop |
| 4098 | `0x1002` | 6 | W | Hz × 100 | Frequency setpoint |
| 4123 | `0x101B` | 3 | R | × 10 → watts | `arborVFDPower[0]`; fallback `I × V` if null |

FC3 read of **7** holding registers starting at **4097**:

| Offset | Field | Notes |
|-------:|-------|-------|
| 0 | Status | Bit 0 running, bit 1 forward, bit 2 reverse, bit 3 speed reached. `128` = e-stop |
| 1 | Requested frequency | Raw (Hz × 100) |
| 2 | Output frequency | → `arborVFDStatus[2]` as Hz (`× 0.01`) |
| 3 | Output current | Used in power fallback |
| 4 | Output voltage | Used in power fallback |
| 5 | Error 1 | Non-zero → `arborState[S][4]` |
| 6 | Error 2 | |

RPM = `120 × Hz / poles`. Load % = watts / (nameplate kW × 1000).

### Config / probe

| Addr (dec) | Hex | FC | Notes |
|-----------:|-----|----|-------|
| 90 | `0x005A` | 3 | Probe / Test Modbus (model) |
| 10501 | `0x2905` | 3 | Motor block B6: power (W×100), poles, V, Hz×100, A×100, RPM/10 |
| 10100 | `0x2774` | 3 | Max / min frequency (Hz × 100) |
| 10008 | `0x2718` | 3 | Speed-display scaling (RPM at 60 Hz) |

Apply also writes CU mode, EEPROM, acc/dec, DC brake, comm retries, etc. Full list: [`macro/private/shihlin-sl3/settings.g`](../macro/private/shihlin-sl3/settings.g).

---

## 1 — Huanyang HY02D223

**Not** standard FC3/FC6. Frames go through `M2604`. Details: [hy02d223b-protocol-notes.md](hy02d223b-protocol-notes.md).

### Runtime command families (control.g)

| Cmd | Payload | Scale | ArborCTL use |
|-----|---------|-------|--------------|
| `0x04` | `0x03, 0x00, 0, 0` | Hz × 100 | Set frequency |
| `0x04` | `0x03, 0x01, 0, 0` | Hz × 100 | Output frequency → `arborVFDStatus[2]` |
| `0x04` | `0x03, 0x02, 0, 0` | A × 10 | Output current |
| `0x05` | `0x02, hi, lo` | Hz × 100 | Frequency setpoint |
| `0x03` | `0x01, 0x01` | — | Forward |
| `0x03` | `0x01, 0x11` | — | Reverse |
| `0x03` | `0x01, 0x08` | — | Stop |

Direction is **command-tracked** (status frames do not report dir). Watts = `√3 × ratedV × I × 0.8`. Load % = watts / nameplate kW, capped at 100.

### Config PD writes (settings.g, cmd `0x02`)

| PD | Reg | Width | Value |
|----|-----|------:|-------|
| PD000 | `0x00` | 1 | Unlock `0` |
| PD141 | `0x8D` | 2 | Rated V |
| PD142 | `0x8E` | 2 | Rated A × 10 |
| PD143 | `0x8F` | 1 | Poles |
| PD144 | `0x90` | 2 | RPM at 50 Hz |
| PD005 | `0x05` | 2 | Max Hz × 100 |
| PD011 | `0x0B` | 2 | Min Hz × 100 |
| PD014 | `0x0E` | 2 | Accel (0.1 s) |
| PD015 | `0x0F` | 2 | Decel (0.1 s) |
| PD023 | `0x17` | 1 | Reverse enable `1` |
| PD001 | `0x01` | 1 | Run from comm `2` |
| PD002 | `0x02` | 1 | Freq from comm `2` |
| PD163 | `0xA3` | 1 | Modbus address |
| PD164 | `0xA4` | 1 | Baud index (0=4800 … 3=38400) |
| PD165 | `0xA5` | 1 | RTU 8N1 `3` |

Cold-start motor/Hz reads use cmd `0x01` when the clone supports them; otherwise wizard `arborMotorSpec` / `arborWizardFreqLimits`. Probe is a `0x04` status read, not FC3.

---

## 2 — Yalang YL620-A

Standard Modbus RTU FC3/FC6. Default slave **10**, baud **19200**.

### Runtime (control.g)

| Addr | Hex | FC | Access | Scale / values | ArborCTL use |
|------|-----|----|--------|----------------|--------------|
| 8192 | `0x2000` | 6 | W | `0x0012` fwd, `0x0022` rev, `0x0001` stop | Run / direction |
| 8193 | `0x2001` | 6 | W | Hz × 10 | Frequency setpoint |
| 8200 | `0x2008` | 3 / 6 | R/W | See state block | Status poll (B9); write `10` = e-stop |

FC3 read of **9** holdings starting at **`0x2008`**:

| Offset | Field | Notes |
|-------:|-------|-------|
| 0 | Error bitmap | Non-zero → `arborState[S][4]` (decoded in control.g) |
| 1 | Inverter state | Non-zero = running; bit 1 fwd, bit 2 rev |
| 2 | Target frequency | Raw (Hz × 10) |
| 3 | Output frequency | → Hz (`× 0.1`) → `arborVFDStatus[2]` |
| 4 | Output current | Power estimate |
| 5 | Output voltage | Power estimate |
| 6 | Bus voltage | |
| 7 | Multi-rate field count | |
| 8 | Accel/decel flags | `0` = speed reached (`stable`) |

Watts ≈ `I × V` (also `freq × I` in one path). Load % = watts / (nameplate kW × 1000). Motor cfg in `arborState` is `{ current_A, voltage, poles }` (current from VFD ÷ 10).

### Config / probe (settings.g)

| Addr | Hex | Notes |
|------|-----|-------|
| 3329 | `0x0D01` | Probe / Test Modbus (hardware version) |
| 3072 | `0x0C00` | Motor B3: A×10, V, poles |
| 5 | `0x0005` | Max frequency (deci-Hz) |
| 9 | `0x0009` | Min frequency (deci-Hz) |
| 0 | `0x0000` | Main frequency (rated Hz × 10) |
| 1 | `0x0001` | Command source `3` (Modbus) |
| 772 | `0x0304` | Modbus timeout 2000 ms |
| 1800 | `0x0708` | Frequency source `5` (RS485) |
| 8194 | `0x2002` | Accel / decel (0.01 s) |
| 19 | `0x0013` | Reset write `0x000A` |

---

## 3 — Manual Modbus (experimental)

No fixed vendor map. Operator supplies **11 integers** in `global.arborModbusManualSpec[S]`. FC3 read / FC6 write only. `arborVFDPower` is always `{0, 0}`.

| Index | Name | Meaning |
|------:|------|---------|
| 0 | rFreqW | Holding written with commanded speed |
| 1 | rCmd | Run / direction / enable |
| 2 | rFreqR | Feedback speed; **0** = skip read |
| 3 | vFwd | Value for forward |
| 4 | vRev | Value for reverse |
| 5 | vStop | Value for stop |
| 6–7 | wrNum / wrDen | `raw = floor(\|RPM\| × wrNum / wrDen)` |
| 8–9 | rdNum / rdDen | `Hz = raw × rdNum / rdDen` |
| 10 | rProbe | Config FC3 probe; **-1** skips probe |

Full description: [modbus-manual-experimental.md](modbus-manual-experimental.md).

---

## 4 — TH Servo (preliminary)

Standard Modbus RTU FC3/FC6. Status `[2]` and `[3]` are **RPM** (not Hz). Default baud **19200**.

### Runtime (control.g)

| Addr (dec) | Hex | FC | Access | Scale / values | ArborCTL use |
|-----------:|-----|----|--------|----------------|--------------|
| 4096 | `0x1000` | 3 | R | RPM | Motor speed → `arborVFDStatus[2]` and `[3]` |
| 4107 | `0x100B` | 3 | R | × 0.1 A | Instant current |
| 4110 | `0x100E` | 3 | R | RPM | Commanded speed (stability) |
| 4120 | `0x1018` | 3 | R | % | `arborVFDPower[1]` load rate |
| 4122 | `0x101A` | 3 | R | code | Alarm; non-zero → error |
| 76 | `0x004C` | 6 | W | RPM | Target speed |
| 4112 | `0x1010` | 6 | W | `8738` (`0x2222`) fwd, `4369` (`0x1111`) rev, `0` stop | Mode / enable |
| 4100 | `0x1004` | 6 | W | `4112` | Clear pending alarms (once at init) |

Watts = `220 × I × √3 × 0.8` (voltage is hardcoded 220 V). Probe / Test Modbus: FC3 `@ 4096`.

---

## 5 — H100

Standard Modbus RTU. FluidNC-compatible coils + frequency; V1.8 **input-register** block for load. Panel keypad setup (F001/F002/F163–F165): [h100-notes.md](h100-notes.md).

### Runtime

| Addr | Hex | FC | Access | Scale / values | ArborCTL use |
|------|-----|----|--------|----------------|--------------|
| 73 | `0x0049` | 5 | W | coil on | Forward |
| 74 | `0x004A` | 5 | W | coil on | Reverse |
| 75 | `0x004B` | 5 | W | coil on | Stop |
| 513 | `0x0201` | 6 | W | Hz × 10 (deci-Hz) | Set frequency (**F169** = 1 vs 2 decimals) |
| 0 | `0x0000` | 4 | R | See FC4 table | Monitor (FluidNC **B2**; optional wider) |
| 5 | `0x0005` | 3 | R | deci-Hz | F005 max Hz (config + Test Modbus) |
| 11 | `0x000B` | 3 | R | deci-Hz | F011 min Hz |

Frequency set is **`M260.1` FC6** (not `M2600` — FC3 verify of `0x0201` fails on H100). Coils are **`M260.1` FC5**.

FC4 starting at **`0x0000`** (FluidNC uses 2 words; V1.8 docs list through `000C`):

| Offset | Name | Scale | ArborCTL use |
|-------:|------|-------|--------------|
| 0 | Output frequency | ÷ 10 → Hz | `arborVFDStatus[2]`; running if > 0 |
| 1 | Set frequency | deci-Hz | Compare to commanded setpoint |
| 2 | Output current | ÷ 10 → A | Load estimate |
| 3 | Output speed | — | Not used (RPM from poles × Hz) |
| 4 | DC voltage | — | Unused |
| 5 | AC voltage | ÷ 10 → V | Power estimate; else wizard nameplate V |
| 6–9 | temp / counter / PID | — | Unused |
| 10 | Current fault (`000A`) | code | Non-zero → `arborState[S][4]` |
| 11 | Operating hours | — | Unused |
| 12 | Output power (`000C`) | see notes | Watts if plausible vs V×I |

Watts = `√3 × Vac × I × 0.8` unless native `000C` is consistent with that estimate (try ×100 as 0.1 kW, else raw watts). Load % = watts / nameplate kW when that estimate is positive; else **I / rated A**. Default FC4 is **2 words**; when running, a supplemental **`R2 B4`** supplies current/AC V. Stopped spindles leave power/load at 0.

Config stores wizard `arborMotorSpec` / `arborWizardFreqLimits`; it does not write motor PDs over Modbus. Probe: FC3 `@ 0x0005`.
