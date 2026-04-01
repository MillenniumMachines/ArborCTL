# ArborCTL Web Plugin (Vue Frontend)

This directory contains the Vue components needed to inject ArborCTL's dashboard into Duet Web Control (DWC).

Because this is a DWC 3.3+ Plugin, it must be compiled into static Javascript by DWC's specific Webpack Pipeline.

### How to Re-Compile The Plugin
If you make changes to `Dashboard.vue` or `plugin.json` and want to build a new `.zip` release, follow these steps:

1. In the root of your project, clone the official DWC repository (this requires \`git\` and \`Node.js\`):
   \`\`\`bash
   git clone https://github.com/Duet3D/DuetWebControl.git dwc-env --depth 1
   \`\`\`
2. Copy this entire \`frontend\` folder into DWC's plugin registry under the name \`ArborCtl\`:
   \`\`\`bash
   Copy-Item "frontend\*" -Destination "dwc-env\src\plugins\ArborCtl\" -Recurse
   \`\`\`
3. Change your terminal path into the \`dwc-env\` directory and install dependencies:
   \`\`\`bash
   cd dwc-env
   npm install
   \`\`\`
4. Run DWC's specific plugin-build command which will output the new UI Zip file to \`dwc-env/dist/ArborCtl-0.1.0.zip\`:
   \`\`\`bash
   npm run build-plugin ArborCtl
   \`\`\`

5. Finally, merge this plugin zip with your backend \`.g\` code! (Use the provided \`dist/release.ps1\` script to generate \`ArborCtl-Plugin.zip\`).
