# ArborCTL

A daemon macro framework for RepRapFirmware v3.6+, which helps to implement RS485 Spindle Control, Monitoring and Feedback across different VFD types.

## Instructions

 - Download from the RELEASES page, not the code view
 - Upload the Zip to the system -> files tab in DWC. Do NOT unzip the file locally before upload
 - Add `M98 P"arborctl.g"` to the end of your `config.g` file.
   - Your spindle needs to be configured before the include. Make sure this has the correct pins defined (enable, direction, speed) even if these are not connected.
 - Edit your `daemon.g` file to include `arborctl-daemon.g`. Check `sys/daemon.g.example` for hints on how to do this.

## Notes

This is alpha and untested. Testing appreciated, but be careful.
