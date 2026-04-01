import { registerRoute } from "@/routes";
import Dashboard from "./Dashboard.vue";

registerRoute(Dashboard, {
	Plugins: {
		ArborCtl: {
			icon: "mdi-fan",
			caption: "ArborCtl Spindle",
			path: "/Plugins/ArborCtl"
		}
	}
});
