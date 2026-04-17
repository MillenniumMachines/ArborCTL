# ArborCTL

A daemon macro framework for RepRapFirmware v3.6+, which helps to implement RS485 Spindle Control, Monitoring and Feedback across different VFD types.

## Instructions

 - Download from the RELEASES page, not the code view
 - Upload the Zip to the system -> files tab in DWC. Do NOT unzip the file locally before upload
 - Add `M98 P"arborctl.g"` to the end of your `config.g` file.
   - Your spindle needs to be configured before the include. Make sure this has the correct pins defined (enable, direction, speed) even if these are not connected.
 - Edit your `daemon.g` file to include `arborctl-daemon.g`. Check `sys/daemon.g.example` for hints on how to do this.

## DWC plugin development

To run **Duet Web Control** locally with hot reload for `dwc-plugin/` (the ArborCTL UI), copy this repo’s `dwc-plugin` into a [DuetWebControl](https://github.com/Duet3D/DuetWebControl) **3.6.x** checkout as `src/plugins/ArborCTL` (on Windows, **do not use a directory junction** — see doc), then `npm install` and `npm run dev`. Use `tools/setup-dwc-dev.ps1` to copy, enable the plugin by default, and set the CNC dashboard. Full steps: [doc/dwc-development.md](doc/dwc-development.md).

## Notes

This is alpha and untested. Testing appreciated, but be careful.
