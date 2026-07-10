/**
 * ArborCTL DWC plugin entry (DuetWebControl 3.7+).
 *
 * Compatibility: plugin.json uses dwcVersion "auto" / rrfVersion "auto-major".
 * Rebuild the ZIP against the host DWC version. Reference pin: 3.7.0-beta.1 (NeXT v0.7.0).
 */
import { registerRoute } from "@/plugins";

import ArborCTL from "./ArborCTL.vue";

registerRoute(ArborCTL, {
	Plugins: {
		ArborCTL: {
			icon: "mdi-cog-transfer",
			caption: "ArborCTL",
			path: "/Plugins/ArborCTL"
		}
	}
});

export default ArborCTL;
