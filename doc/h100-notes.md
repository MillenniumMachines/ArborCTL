# H100 VFD (standard Modbus RTU)

See also the catalog of all ArborCTL drive maps: [vfd-modbus-maps.md](vfd-modbus-maps.md).

ArborCTL’s **H100** driver talks **standard Modbus RTU** over RS-485. It is **not** the Huanyang custom protocol (`M2604`).

Register map follows [FluidNC `H100.cpp`](https://github.com/bdring/FluidNC/blob/main/FluidNC/src/Spindles/VFD/H100.cpp) / `H100Protocol.md`. Panel RS485 steps align with the unofficial SLB/gSender guide (F001/F002/F163–F165), adapted for Duet/ArborCTL instead of gSender `$` settings.

## Panel settings (before Modbus)

Enter these on the VFD keypad:

| Param | Typical value | Meaning |
|-------|---------------|---------|
| F001 | 2 | Run command from communications |
| F002 | 2 | Frequency from communications |
| F163 | *n* | Modbus slave address (match ArborCTL) |
| F164 | *baud index* | Baud — often `1` = 9600, `2` = 19200 (confirm in your manual; clones vary) |
| F165 | 3 | RTU 8N1 |

Also set motor / frequency limits (F003–F011, F140–F144, etc.) for your spindle before relying on RS-485. ArborCTL stores wizard motor + Hz limits and will use F005/F011 when readable.

## Wiring

- VFD **485+** → controller **A**
- VFD **485−** → controller **B**
- If there is no response, try swapping A/B. Prefer no shared signal ground unless your hardware requires it.

## Modbus map (ArborCTL)

| Action | FC | Address | Notes |
|--------|----|---------|-------|
| Forward | 5 | `0x0049` | Coil on (`M260.1 F5 … B{1,}`) |
| Reverse | 5 | `0x004A` | Coil on |
| Stop | 5 | `0x004B` | Coil on |
| Set frequency | 6 | `0x0201` | Value = Hz × 10 (deci-Hz). **F169** only affects this write (1 vs 2 decimal places). |
| Read monitor | 4 | `0x0000` | 13 input regs (`0000`–`000C`); see below |
| Max Hz (F005) | 3 | `0x0005` | Holding; deci-Hz |
| Min Hz (F011) | 3 | `0x000B` | Holding; deci-Hz |

FC4 starting at `0x0000` (H100 V1.8 input-register table):

| Offset | Name | ArborCTL use |
|--------|------|----------------|
| `0000` | Output frequency | Running Hz (÷10) |
| `0001` | Set frequency | Commanded deci-Hz compare |
| `0002` | Output current | Load estimate (÷10 → A) |
| `0005` | AC voltage | Power estimate (÷10 → V); else wizard nameplate |
| `000A` | Current fault | Sets `arborState` error if non-zero |
| `000C` | Output power | Used for watts when the value is plausible vs the V×I estimate |

`arborVFDPower` is `{ watts, loadPercent }`. Watts are `sqrt(3)×Vac×I×0.8` (same form as Huanyang) unless native `000C` looks consistent with that estimate (0.1 kW units ×100, or raw watts if ×100 exceeds 2× nameplate). Load % is watts / nameplate kW. Stopped spindles and **short replies** (clones that only return the FluidNC 2 frequency words, or that reject the long read) leave power/load at 0; frequency control still uses word 0.

**Test Modbus** in the DWC plugin uses FC3 on register `5` (F005).

## Files

- `macro/private/h100/{config,control,settings}.g` → installed as `0:/sys/arborctl/h100/`
- Model index **5** in `sys/arborctl-vars.g` (`"H100"` / `"h100"`)
- Default baud index: **1** (9600 in the shared baud list)

## Notes

- Coil writes use **`M260.1 F5`** directly. ArborCTL’s `M2600` verify path reads back with FC3 and is unsuitable for coils.
- Frequency writes use **`M2600` F6** (verified holding-register write).
- Current and voltage scales assume **0.1 units** (3.0 A → register 30), matching the keypad monitors. Confirm against SHIFT display on first bring-up; native `000C` power scale varies by clone.
