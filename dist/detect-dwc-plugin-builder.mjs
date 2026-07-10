#!/usr/bin/env node
/**
 * Detect whether a DuetWebControl tree uses the Vite external-plugin builder (3.7+)
 * or the legacy webpack/vue-cli builder (3.6.x).
 *
 * Usage: node dist/detect-dwc-plugin-builder.mjs <path-to-DuetWebControl>
 * Prints: vite | webpack
 */
import fs from "node:fs";
import path from "node:path";

const dwcRoot = process.argv[2];
if (!dwcRoot) {
	console.error("usage: node dist/detect-dwc-plugin-builder.mjs <path-to-DuetWebControl>");
	process.exit(1);
}

const buildPluginJs = path.join(dwcRoot, "scripts", "build-plugin.js");
const buildPluginPkgJs = path.join(dwcRoot, "scripts", "build-plugin-pkg.js");

if (!fs.existsSync(buildPluginJs) && !fs.existsSync(buildPluginPkgJs)) {
	console.error(`error: missing ${buildPluginJs} (and no build-plugin-pkg.js)`);
	process.exit(1);
}

if (!fs.existsSync(buildPluginJs)) {
	process.stdout.write("webpack\n");
	process.exit(0);
}

const src = fs.readFileSync(buildPluginJs, "utf8");
const isVite =
	/\bfrom\s+["']vite["']/.test(src) ||
	/entryFileNames:\s*`\$\{manifest\.id\}-\[hash\]\.js`/.test(src) ||
	/createZip\(assembleDir,\s*zipPath\)/.test(src);

process.stdout.write(isVite ? "vite\n" : "webpack\n");
