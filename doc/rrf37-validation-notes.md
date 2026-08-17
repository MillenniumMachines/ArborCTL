# RRF / DWC 3.7 validation notes

Pin: **DWC / RRF evaluation `3.7.0-beta.1`** (same as NeXT `ci/dwc-build-ref`).

## Completed (this unify line)

- ArborCTL ZIP built with `./dist/build-dwc-plugin.sh …/DuetWebControl 0.7.1` — **vue-tsc passed**; output `dist/ArborCTL-0.7.1.zip` with `dwcVersion: 3.7.0-beta.1`.
- NeXT ZIP built with `./dist/build-plugin.sh …/DuetWebControl` after VFD tab — **vue-tsc passed**; `dwcVersion: 3.7.0-beta.1`.
- Macro hygiene: Huanyang auto-correct channel line split to ≤200 chars; pre-existing long `M291` wizard strings in Shihlin/Yalang remain (interactive dialogs, not boot path).
- No `M98` of numbered `M####`/`G####` in ArborCTL `macro/` / `sys/` for Apply path.
- NeXT catalog staging still pulls `plugins/arborctl/*` from sibling ArborCTL.

## Manual runtime gate (before release tag)

On a board with RRF 3.7.x + matching DWC:

1. `M586 P0 S1` (HTTP)
2. Install both ZIPs; start nxt + ArborCTL
3. VFD tab visible only with ArborCTL; Apply → CommReady; daemon via nxt dispatcher
4. Advanced → `/Plugins/ArborCTL`
