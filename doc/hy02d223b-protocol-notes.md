# HY02D223B protocol and ArborCtl implementation notes

This note documents the Huanyang HY02D223B work that was added to ArborCtl and the protocol decisions behind it.

## Source of truth

The implementation was aligned to these repo-local references, in this order:

1. `doc/Huanyang HY02D223B VFD manual.pdf`
2. `doc/HuanyangProtocol.cpp`

The earlier screenshot-based suggestion was treated as non-authoritative once the manual and C++ reference were reviewed.

## Huanyang command families

The HY02D223B does not expose a single Modbus-style register interface for everything. The bundled manual and `HuanyangProtocol.cpp` both show multiple command families being used side by side:

| Purpose | Command bytes | Notes |
| --- | --- | --- |
| Read parameter / function data | `0x01, 0x03, reg, 0x00, 0x00` | Used for PD parameter reads such as `PD005`, `PD011`, `PD143`, `PD144` |
| Write parameter / function data | `0x02, len, reg, data...` | Used by the new HY02D223B `config.g` for parameter writes |
| Write runtime control command | `0x03, 0x01, cmd` | Start/stop/direction runtime commands |
| Read runtime status | `0x04, 0x03, cfg, 0x00, 0x00` | Set/output frequency, output current, etc. |
| Write runtime frequency | `0x05, 0x02, hi, lo` | Frequency setpoint in 0.01 Hz units |

Because of that split, HY02D223B cannot be configured with ArborCtl's generic Modbus helper alone. It needs its own model-specific configuration logic.

## Runtime control changes

`macro/private/huanyang-hy02d223b/control.g` was updated to follow the documented HY command split:

- cold-start motor/config reads use documented function-`0x01` parameter reads
- runtime set/output/current polling uses function-`0x04`
- frequency writes use function-`0x05`
- start/stop/direction commands use function-`0x03`

Additional corrections made while aligning to the manual and `HuanyangProtocol.cpp`:

- `PD011` is used as the lower frequency limit instead of `PD006`
- parameter parsing now distinguishes between one-byte and two-byte values
- frequency limits are decoded in `0.01 Hz`
- motor current is decoded in `0.1 A`
- read failures are checked using `null` instead of treating zero as a failure

## Direction handling

The documented HY runtime status reads do not provide a direct direction readback in the same way as some other VFDs in ArborCtl.

To keep the behavior safe, the HY02D223B runtime logic now tracks the last commanded direction internally. If ArborCtl restarts and finds the spindle already running with an unknown direction, it stops the spindle first before reissuing the requested direction instead of guessing.

## New HY02D223B model files

The HY02D223B folder now mirrors the per-model structure already used by the Shihlin SL3 and Yalang YL620-A drivers:

- `macro/private/huanyang-hy02d223b/control.g`
- `macro/private/huanyang-hy02d223b/config.g`
- `macro/private/huanyang-hy02d223b/settings.g`

### `settings.g`

`settings.g` defines a conservative, manual-backed parameter set for auto-configuration:

- `PD000` parameter unlock
- `PD141` rated motor voltage
- `PD142` rated motor current
- `PD143` pole count
- `PD144` rated RPM at `50 Hz`
- `PD005` maximum operating frequency
- `PD011` lower frequency limit
- `PD023` reverse rotation enable
- `PD001` run commands from communication
- `PD002` frequency source from communication
- `PD163` RS485 address
- `PD164` baud rate
- `PD165` RTU 8N1 communication format

`PD004` was intentionally left out of the first auto-config set because the manual is not as clear about its unit/usage as the parameters above, and `HuanyangProtocol.cpp` does not depend on it.

### `config.g`

`config.g` performs the HY-specific setup flow:

1. Validate wizard inputs
2. Load HY parameter definitions from `settings.g`
3. Configure UART with `M575`
4. Probe the drive with a HY function-`0x01` parameter read
5. Offer manual setup guidance for `PD001`, `PD002`, `PD163`, `PD164`, and `PD165`
6. Write HY parameters with function `0x02`
7. Verify each parameter with function `0x01` readback
8. Invalidate cached ArborCtl spindle state so the next control pass rereads the VFD configuration

## Practical limitation

The HY parameter write path is implemented from the protocol documentation available in this repo, but the manual's protocol section is noisier and less internally consistent than the Shihlin/Yalang documentation.

For that reason, the HY02D223B auto-config set was kept intentionally conservative and limited to parameters that are directly relevant to RS485 control and motor/frequency mapping.
