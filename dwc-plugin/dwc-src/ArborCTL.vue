<template>
    <v-card class="ma-3">
        <v-card-title class="d-flex align-center">
            <v-icon class="mr-2">mdi-cog-transfer</v-icon>
            ArborCTL
            <v-spacer />
            <v-chip small label :color="loaded ? 'success' : 'warning'">
                {{ loaded ? "Loaded" : "Not loaded" }}
            </v-chip>
        </v-card-title>

        <v-card-subtitle>
            RS485 Spindle Control, Monitoring and Feedback for RepRapFirmware 3.6+
        </v-card-subtitle>

        <v-card-text>
            <v-simple-table dense>
                <tbody>
                    <tr>
                        <th class="text-left" style="width: 220px;">Version</th>
                        <td>{{ version || "Unknown" }}</td>
                    </tr>
                    <tr>
                        <th class="text-left">Last error</th>
                        <td>{{ lastError || "None" }}</td>
                    </tr>
                    <tr>
                        <th class="text-left">Configured spindles</th>
                        <td>{{ configuredSpindles }}</td>
                    </tr>
                </tbody>
            </v-simple-table>

            <v-alert v-if="!loaded" class="mt-4" type="warning" outlined dense>
                ArborCTL daemon has not loaded. Make sure
                <code>M98 P"arborctl.g"</code> is included at the end of your
                <code>config.g</code> and that the board has been reset.
            </v-alert>

            <div class="mt-4">
                <v-btn
                    color="primary"
                    :disabled="uiFrozen"
                    @click="runWizard"
                >
                    <v-icon class="mr-1">mdi-auto-fix</v-icon>
                    Run Configuration Wizard
                </v-btn>

                <v-btn
                    class="ml-2"
                    color="secondary"
                    href="https://github.com/benagricola/ArborCTL"
                    target="_blank"
                    rel="noopener"
                >
                    <v-icon class="mr-1">mdi-github</v-icon>
                    Documentation
                </v-btn>
            </div>
        </v-card-text>
    </v-card>
</template>

<script lang="ts">
import Vue from "vue";

import store from "@/store";

function getGlobal(key: string): any {
    const model = (store.state as any)?.machine?.model;
    if (!model || !model.global) return undefined;
    if (model.global instanceof Map) {
        return model.global.get(key);
    }
    return model.global[key];
}

export default Vue.extend({
    name: "ArborCTL",
    computed: {
        uiFrozen(): boolean {
            return store.getters["uiFrozen"];
        },
        loaded(): boolean {
            return Boolean(getGlobal("arborctlLdd"));
        },
        version(): string | null {
            return getGlobal("arborctlVer") ?? null;
        },
        lastError(): string | null {
            return getGlobal("arborctlErr") ?? null;
        },
        configuredSpindles(): number {
            const cfg = getGlobal("arborVFDConfig");
            if (!Array.isArray(cfg)) {
                return 0;
            }
            return cfg.filter((v: any) => v !== null && v !== undefined).length;
        }
    },
    methods: {
        async runWizard(): Promise<void> {
            try {
                await store.dispatch("machine/sendCode", {
                    code: 'M98 P"0:/macros/ArborCtl/Run Configuration Wizard.g"'
                });
            } catch (e) {
                console.error("[ArborCTL] Failed to start wizard", e);
            }
        }
    }
});
</script>
