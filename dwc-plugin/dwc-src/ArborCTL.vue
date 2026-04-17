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
            RS485 spindle control for RepRapFirmware 3.6+. Edit all parameters on one page, save to
            <code>0:/sys/arborctl-user-vars.g</code>, then reboot or run VFD setup. The panel wizard (<b>G8001</b>) remains
            available as a fallback.
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
                ArborCTL has not loaded. Ensure <code>M98 P"arborctl.g"</code> is at the end of <code>config.g</code> and reset the board.
            </v-alert>

            <v-divider class="my-4" />

            <div class="text-subtitle-1 mb-2">UART &amp; drive</div>
            <v-row dense>
                <v-col cols="12" sm="6" md="4">
                    <v-select
                        v-model="form.channel"
                        :items="channelItems"
                        label="UART port"
                        dense
                        outlined
                        hide-details="auto"
                    />
                </v-col>
                <v-col cols="12" sm="6" md="4">
                    <v-select
                        v-model="form.baud"
                        :items="baudItems"
                        label="Baud rate"
                        dense
                        outlined
                        hide-details="auto"
                    />
                </v-col>
                <v-col cols="12" sm="6" md="4">
                    <v-text-field
                        v-model.number="form.address"
                        type="number"
                        label="Modbus / RS485 address"
                        min="1"
                        max="247"
                        dense
                        outlined
                        hide-details="auto"
                    />
                </v-col>
                <v-col cols="12" sm="6" md="6">
                    <v-select
                        v-model="form.typeIndex"
                        :items="modelItems"
                        item-text="text"
                        item-value="value"
                        label="VFD model"
                        dense
                        outlined
                        hide-details="auto"
                        @change="onModelChange"
                    />
                </v-col>
                <v-col cols="12" sm="6" md="6">
                    <v-select
                        v-model="form.spindleId"
                        :items="spindleSelectItems"
                        item-text="text"
                        item-value="value"
                        label="RRF spindle"
                        dense
                        outlined
                        hide-details="auto"
                    />
                </v-col>
            </v-row>

            <div class="text-subtitle-1 mb-2 mt-2">Motor nameplate</div>
            <v-row dense>
                <v-col cols="6" sm="4" md="3">
                    <v-text-field
                        v-model.number="form.motorW"
                        type="number"
                        label="Power (kW)"
                        step="0.01"
                        dense
                        outlined
                        hide-details="auto"
                    />
                </v-col>
                <v-col cols="6" sm="4" md="3">
                    <v-select
                        v-model.number="form.motorPoles"
                        :items="poleItems"
                        label="Poles"
                        dense
                        outlined
                        hide-details="auto"
                    />
                </v-col>
                <v-col cols="6" sm="4" md="3">
                    <v-text-field
                        v-model.number="form.motorV"
                        type="number"
                        label="Voltage (V)"
                        dense
                        outlined
                        hide-details="auto"
                    />
                </v-col>
                <v-col cols="6" sm="4" md="3">
                    <v-text-field
                        v-model.number="form.motorF"
                        type="number"
                        label="Frequency (Hz)"
                        dense
                        outlined
                        hide-details="auto"
                    />
                </v-col>
                <v-col cols="6" sm="4" md="3">
                    <v-text-field
                        v-model.number="form.motorI"
                        type="number"
                        label="Current (A)"
                        step="0.1"
                        dense
                        outlined
                        hide-details="auto"
                    />
                </v-col>
                <v-col cols="6" sm="4" md="3">
                    <v-text-field
                        v-model.number="form.motorR"
                        type="number"
                        label="Rated speed (RPM)"
                        dense
                        outlined
                        hide-details="auto"
                    />
                </v-col>
            </v-row>

            <v-row dense class="mt-1">
                <v-col cols="12">
                    <v-chip small class="mr-2" outlined>
                        Min Hz (from RRF spindle limits): {{ hzLimits.t }}
                    </v-chip>
                    <v-chip small outlined>
                        Max Hz (from RRF spindle limits): {{ hzLimits.e }}
                    </v-chip>
                </v-col>
            </v-row>
            <p class="caption grey--text text--darken-1 mt-2 mb-0">
                Hz limits match <b>G8001</b> (capped by motor rated frequency). Baud is not exposed on the object model;
                set it here to match <b>M575</b> in your user vars file.
            </p>

            <v-divider class="my-4" />

            <div class="d-flex flex-wrap align-center">
                <v-btn color="primary" class="mr-2 mb-2" :disabled="uiFrozen || !canSave" :loading="saving" @click="saveUserVars">
                    <v-icon left small>mdi-content-save</v-icon>
                    Save to arborctl-user-vars.g
                </v-btn>
                <v-btn color="secondary" class="mr-2 mb-2" :disabled="uiFrozen || !canSave" :loading="configuring" @click="saveAndConfigureVfd">
                    <v-icon left small>mdi-serial-port</v-icon>
                    Save &amp; run VFD config macro
                </v-btn>
                <v-btn class="mr-2 mb-2" outlined color="primary" :disabled="uiFrozen" @click="runWizard">
                    <v-icon left small>mdi-auto-fix</v-icon>
                    Run wizard (G8001)
                </v-btn>
                <v-btn class="mb-2" color="secondary" text href="https://github.com/MillenniumMachines/ArborCTL" target="_blank" rel="noopener">
                    <v-icon left small>mdi-github</v-icon>
                    Documentation
                </v-btn>
            </div>
            <v-alert v-if="saveError" type="error" dense outlined class="mt-2">{{ saveError }}</v-alert>
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

const BAUD_LIST = [4800, 9600, 19200, 38400, 57600];

export default Vue.extend({
    name: "ArborCTL",
    data() {
        return {
            saving: false,
            configuring: false,
            saveError: "" as string,
            form: {
                channel: 1,
                baud: 9600,
                address: 1,
                typeIndex: 1,
                spindleId: 0,
                motorW: 1.5,
                motorPoles: 4,
                motorV: 220,
                motorF: 400,
                motorI: 4.0,
                motorR: 24000
            }
        };
    },
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
        },
        channelItems(): Array<{ text: string; value: number }> {
            return [
                { text: "AUX 0 (first port)", value: 1 },
                { text: "AUX 1 (second port)", value: 2 },
                { text: "AUX 2 (third port)", value: 3 }
            ];
        },
        baudItems(): number[] {
            return BAUD_LIST;
        },
        poleItems(): number[] {
            return [2, 4];
        },
        modelItems(): Array<{ text: string; value: number }> {
            const m = getGlobal("arborAvailableModels");
            if (!Array.isArray(m)) {
                return [
                    { text: "Shihlin SL3", value: 0 },
                    { text: "Huanyang HY02D223", value: 1 },
                    { text: "Yalang YL620-A", value: 2 }
                ];
            }
            return m.map((text: string, i: number) => ({ text, value: i }));
        },
        spindleSelectItems(): Array<{ text: string; value: number }> {
            const model = (store.state as any)?.machine?.model;
            const spindles = model?.spindles;
            const maxS = model?.limits?.spindles ?? 8;
            const items: Array<{ text: string; value: number }> = [];
            for (let i = 0; i < maxS; i++) {
                const s = spindles && spindles[i];
                if (s && s.state !== "unconfigured") {
                    items.push({ text: `Spindle ${i}`, value: i });
                }
            }
            if (items.length === 0) {
                items.push({ text: "Spindle 0", value: 0 });
            }
            return items;
        },
        hzLimits(): { t: number; e: number } {
            const model = (store.state as any)?.machine?.model;
            const spindles = model?.spindles;
            const sid = this.form.spindleId;
            const poles = this.form.motorPoles;
            const mf = Number(this.form.motorF);
            const s = spindles && spindles[sid];
            if (!s || !poles || !mf) {
                return { t: 0, e: 0 };
            }
            const minRpm = s.min != null ? Number(s.min) : 0;
            const maxRpm = s.max != null ? Number(s.max) : 0;
            const t = Math.min(mf, Math.ceil((minRpm / 120) * poles));
            const e = Math.min(mf, Math.ceil((maxRpm / 120) * poles));
            return { t, e };
        },
        modelTypeName(): string {
            const items = this.modelItems;
            const found = items.find((x) => x.value === this.form.typeIndex);
            return found ? found.text : "";
        },
        internalName(): string {
            const names = getGlobal("arborModelInternalNames");
            if (Array.isArray(names) && names[this.form.typeIndex] != null) {
                return names[this.form.typeIndex];
            }
            const fallback = ["shihlin-sl3", "huanyang-hy02d223b", "yalang-yl620a"];
            return fallback[this.form.typeIndex] || "huanyang-hy02d223b";
        },
        canSave(): boolean {
            const hz = this.hzLimits;
            return (
                this.form.address >= 1 &&
                this.form.address <= 247 &&
                this.form.motorW > 0 &&
                this.form.motorPoles > 0 &&
                this.form.motorV > 0 &&
                this.form.motorF > 0 &&
                this.form.motorI > 0 &&
                this.form.motorR > 0 &&
                Number.isFinite(hz.t) &&
                Number.isFinite(hz.e) &&
                hz.e >= hz.t
            );
        }
    },
    mounted() {
        this.loadFromMachine();
        this.$nextTick(() => this.onModelChange());
    },
    methods: {
        onModelChange(): void {
            const idxArr = getGlobal("arborModelDefaultBaudRateIndex");
            if (Array.isArray(idxArr) && idxArr[this.form.typeIndex] != null) {
                const i = idxArr[this.form.typeIndex];
                if (i >= 0 && i < BAUD_LIST.length) {
                    this.form.baud = BAUD_LIST[i];
                }
            }
        },
        loadFromMachine(): void {
            const cfg = getGlobal("arborVFDConfig");
            const motor = getGlobal("arborMotorSpec");
            if (Array.isArray(cfg)) {
                for (let i = 0; i < cfg.length; i++) {
                    if (cfg[i] != null) {
                        const c = cfg[i];
                        this.form.typeIndex = c[0];
                        this.form.channel = c[1];
                        this.form.address = c[2];
                        this.form.spindleId = i;
                        break;
                    }
                }
            }
            const sid = this.form.spindleId;
            if (Array.isArray(motor) && motor[sid] != null) {
                const m = motor[sid];
                this.form.motorW = m[0];
                this.form.motorPoles = m[1];
                this.form.motorV = m[2];
                this.form.motorF = m[3];
                this.form.motorI = m[4];
                this.form.motorR = m[5];
            }
        },
        buildUserVarsFile(): string {
            const f = this.form;
            const hz = this.hzLimits;
            const typeName = this.modelTypeName;
            const lines = [
                "; ArborCtl User Variables",
                ";",
                "; This file is automatically generated by the ArborCTL DWC plugin.",
                "; You can edit this file manually at your own risk.",
                "",
                "; ArborCtl Configuration",
                "; UART Configuration",
                `M575 P${f.channel} B${f.baud} S7 ; Configure UART for Modbus RTU`,
                "",
                "; VFD Configuration",
                `; Type: ${typeName} Channel: ${f.channel} Address: ${f.address}`,
                `set global.arborVFDConfig[${f.spindleId}] = {${f.typeIndex}, ${f.channel}, ${f.address}} ; VFD configuration`,
                `set global.arborMotorSpec[${f.spindleId}] = {${f.motorW}, ${f.motorPoles}, ${f.motorV}, ${f.motorF}, ${f.motorI}, ${f.motorR}} ; Wizard motor (kW,poles,V,Hz,A,RPM)`,
                `set global.arborWizardFreqLimits[${f.spindleId}] = {${hz.t}, ${hz.e}} ; Min/max Hz from spindle limits`,
                ""
            ];
            return lines.join("\n");
        },
        async saveUserVars(options?: { quiet?: boolean }): Promise<void> {
            this.saveError = "";
            this.saving = true;
            try {
                const content = this.buildUserVarsFile();
                await store.dispatch("machine/upload", {
                    filename: "0:/sys/arborctl-user-vars.g",
                    content,
                    showSuccess: !options?.quiet
                });
            } catch (e) {
                this.saveError = e instanceof Error ? e.message : String(e);
                console.error("[ArborCTL] Save failed", e);
            } finally {
                this.saving = false;
            }
        },
        async saveAndConfigureVfd(): Promise<void> {
            this.saveError = "";
            this.configuring = true;
            try {
                await this.saveUserVars({ quiet: true });
                if (this.saveError) {
                    return;
                }
                const f = this.form;
                const hz = this.hzLimits;
                const internal = this.internalName;
                const code =
                    `M98 P"arborctl/${internal}/config.g" B${f.baud} C${f.channel} A${f.address} S${f.spindleId} ` +
                    `W${f.motorW} U${f.motorPoles} V${f.motorV} F${f.motorF} I${f.motorI} R${f.motorR} T${hz.t} E${hz.e}`;
                await store.dispatch("machine/sendCode", { code });
            } catch (e) {
                this.saveError = e instanceof Error ? e.message : String(e);
                console.error("[ArborCTL] VFD config failed", e);
            } finally {
                this.configuring = false;
            }
        },
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
