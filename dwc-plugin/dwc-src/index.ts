import { registerRoute } from "@/routes";

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
