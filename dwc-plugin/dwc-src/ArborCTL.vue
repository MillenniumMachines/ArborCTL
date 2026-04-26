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
                        <th class="text-left">Configured spindles</th>
                        <td>{{ configuredSpindles }}</td>
                    </tr>
                </tbody>
            </v-simple-table>

            <template v-if="loaded">
                <v-divider class="my-4" />
                <div class="text-subtitle-1 mb-1 d-flex align-center flex-wrap">
                    <v-icon class="mr-2" small>mdi-gauge</v-icon>
                    Spindle load &amp; telemetry
                </div>
                <p class="caption grey--text text--darken-1 mb-2">
                    From <code>arborVFDStatus</code> / <code>arborVFDPower</code> (daemon polling). Load % is
                    driver-defined (e.g. VFD power estimate, servo register, or 0). Feed protect when load &gt;
                    <b>{{ arborMaxLoadDisplay }}%</b> (<code>global.arborMaxLoad</code>).
                </p>
                <v-simple-table v-if="telemetryRows.length > 0" dense>
                    <thead>
                        <tr>
                            <th class="text-left">Spindle</th>
                            <th class="text-left">Drive</th>
                            <th class="text-left">Comm</th>
                            <th class="text-left">Run</th>
                            <th class="text-left">Dir</th>
                            <th class="text-right">Hz</th>
                            <th class="text-right">RPM</th>
                            <th class="text-left">Stable</th>
                            <th class="text-right">Power (W)</th>
                            <th class="text-left" style="min-width: 120px;">Load %</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr v-for="row in telemetryRows" :key="'tel-' + row.id">
                            <td>{{ row.id }}</td>
                            <td>{{ row.driveName }}</td>
                            <td>
                                <v-chip x-small label :color="row.commColor">{{ row.commLabel }}</v-chip>
                            </td>
                            <td>{{ row.running }}</td>
                            <td>{{ row.dir }}</td>
                            <td class="text-right">{{ row.hz }}</td>
                            <td class="text-right">{{ row.rpm }}</td>
                            <td>{{ row.stable }}</td>
                            <td class="text-right">{{ row.watts }}</td>
                            <td>
                                <div class="d-flex align-center">
                                    <span class="mr-2">{{ row.loadPct }}</span>
                                    <v-progress-linear
                                        v-if="row.loadBar >= 0"
                                        :value="row.loadBar"
                                        height="8"
                                        color="primary"
                                        class="flex-grow-1"
                                        style="max-width: 100px;"
                                    />
                                </div>
                            </td>
                        </tr>
                    </tbody>
                </v-simple-table>
                <v-alert v-else type="info" dense outlined class="mb-0">
                    No ArborCTL-configured spindles yet, or telemetry not available. Save a configuration and ensure the
                    arborctl daemon is running.
                </v-alert>
            </template>

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
                        :label="motorFreqLabel"
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

            <v-row v-if="isThServo" dense class="mt-1">
                <v-col cols="12">
                    <v-chip small class="mr-2" outlined>
                        Min RPM (RRF spindle vs rated): {{ spindleRpmLimits.t }}
                    </v-chip>
                    <v-chip small outlined>
                        Max RPM (RRF spindle vs rated): {{ spindleRpmLimits.e }}
                    </v-chip>
                </v-col>
            </v-row>
            <v-row v-else dense class="mt-1">
                <v-col cols="12">
                    <v-chip small class="mr-2" outlined>
                        Min Hz (from RRF spindle limits): {{ hzLimits.t }}
                    </v-chip>
                    <v-chip small outlined>
                        Max Hz (from RRF spindle limits): {{ hzLimits.e }}
                    </v-chip>
                </v-col>
            </v-row>
            <p v-if="isThServo" class="caption grey--text text--darken-1 mt-2 mb-0">
                TH Servo runs in <b>RPM</b>: the driver uses RRF spindle <b>min</b>/<b>max</b> (RPM) and nameplate rated RPM.
                <b>Frequency (Hz)</b> below is still saved for <b>G8001</b> / <code>arborWizardFreqLimits</code> compatibility; the TH driver does not use Hz for speed.
                Baud is not on the object model — set it here to match <b>M575</b>.
            </p>
            <p v-else class="caption grey--text text--darken-1 mt-2 mb-0">
                Hz limits match <b>G8001</b> (capped by motor rated frequency). Baud is not exposed on the object model;
                set it here to match <b>M575</b> in your user vars file.
            </p>

            <template v-if="isManualModbus">
                <v-divider class="my-4" />
                <div class="text-subtitle-1 mb-2">
                    Manual Modbus map
                    <v-chip x-small class="ml-2" color="amber" text-color="black" label>experimental</v-chip>
                </div>
                <p class="caption mb-2">
                    Eleven holding-register integers (FC3 / FC6). See
                    <a href="https://github.com/MillenniumMachines/ArborCTL/blob/main/doc/modbus-manual-experimental.md" target="_blank" rel="noopener">modbus-manual-experimental.md</a>
                    (or <code>doc/modbus-manual-experimental.md</code> in the repo).
                </p>
                <v-row dense>
                    <v-col cols="6" sm="4" md="3">
                        <v-text-field v-model.number="form.manualSpec[0]" type="number" label="Freq write reg" dense outlined hide-details="auto" />
                    </v-col>
                    <v-col cols="6" sm="4" md="3">
                        <v-text-field v-model.number="form.manualSpec[1]" type="number" label="Cmd reg" dense outlined hide-details="auto" />
                    </v-col>
                    <v-col cols="6" sm="4" md="3">
                        <v-text-field v-model.number="form.manualSpec[2]" type="number" label="Freq read reg (0=none)" dense outlined hide-details="auto" />
                    </v-col>
                    <v-col cols="6" sm="4" md="3">
                        <v-text-field v-model.number="form.manualSpec[10]" type="number" label="Probe reg (-1=skip)" dense outlined hide-details="auto" />
                    </v-col>
                    <v-col cols="4" sm="3" md="2">
                        <v-text-field v-model.number="form.manualSpec[3]" type="number" label="Run fwd value" dense outlined hide-details="auto" />
                    </v-col>
                    <v-col cols="4" sm="3" md="2">
                        <v-text-field v-model.number="form.manualSpec[4]" type="number" label="Run rev value" dense outlined hide-details="auto" />
                    </v-col>
                    <v-col cols="4" sm="3" md="2">
                        <v-text-field v-model.number="form.manualSpec[5]" type="number" label="Stop value" dense outlined hide-details="auto" />
                    </v-col>
                    <v-col cols="6" sm="4" md="3">
                        <v-text-field v-model.number="form.manualSpec[6]" type="number" label="Write scale num" dense outlined hide-details="auto" />
                    </v-col>
                    <v-col cols="6" sm="4" md="3">
                        <v-text-field v-model.number="form.manualSpec[7]" type="number" label="Write scale den" dense outlined hide-details="auto" />
                    </v-col>
                    <v-col cols="6" sm="4" md="3">
                        <v-text-field v-model.number="form.manualSpec[8]" type="number" label="Read scale num" dense outlined hide-details="auto" />
                    </v-col>
                    <v-col cols="6" sm="4" md="3">
                        <v-text-field v-model.number="form.manualSpec[9]" type="number" label="Read scale den" dense outlined hide-details="auto" />
                    </v-col>
                </v-row>
            </template>

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
                <v-btn
                    class="mr-2 mb-2"
                    outlined
                    color="deep-orange"
                    :disabled="uiFrozen || !canProbeModbus"
                    :loading="testProbing"
                    @click="testModbusProbe"
                >
                    <v-icon left small>mdi-network-outline</v-icon>
                    Test Modbus
                </v-btn>
                <v-btn class="mb-2" color="secondary" text href="https://github.com/MillenniumMachines/ArborCTL" target="_blank" rel="noopener">
                    <v-icon left small>mdi-github</v-icon>
                    Documentation
                </v-btn>
            </div>
            <p class="caption grey--text text--darken-1 mt-1 mb-0">{{ probeModbusCaption }}</p>
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

/** RRF user globals sometimes appear under machine.variables in DWC. */
function getOmGlobal(key: string): any {
    const v = getGlobal(key);
    if (v !== undefined) {
        return v;
    }
    const vars = (store.state as any)?.machine?.variables;
    if (vars && vars[key] !== undefined) {
        return vars[key];
    }
    return undefined;
}

interface TelemetryRow {
    id: number;
    driveName: string;
    commLabel: string;
    commColor: string;
    running: string;
    dir: string;
    hz: string;
    rpm: string;
    stable: string;
    watts: string;
    loadPct: string;
    loadBar: number;
}

function fmtTelemetryNum(v: any, decimals: number): string {
    if (v === null || v === undefined || typeof v !== "number" || !Number.isFinite(v)) {
        return "—";
    }
    return decimals <= 0 ? String(Math.round(v)) : v.toFixed(decimals);
}

function fmtTelemetryBool(v: any): string {
    if (v === null || v === undefined) {
        return "—";
    }
    return v ? "Yes" : "No";
}

function fmtTelemetryDir(v: any): string {
    if (v === null || v === undefined) {
        return "—";
    }
    if (v === 1) {
        return "Fwd";
    }
    if (v === -1) {
        return "Rev";
    }
    return "Stop";
}

const BAUD_LIST = [4800, 9600, 19200, 38400, 57600];

/** Index of "Manual Modbus (experimental)" in arborAvailableModels / arborModelInternalNames */
const MANUAL_MODBUS_INDEX = 3;

/** Index of "TH Servo (preliminary)" — driver from PR #17 (jayem1427/feature/th-servo-support) */
const TH_SERVO_INDEX = 4;

const DEFAULT_MANUAL_SPEC = [5000, 5001, 5002, 1, 2, 0, 1, 1, 1, 100, 5000];

export default Vue.extend({
    name: "ArborCTL",
    data() {
        return {
            saving: false,
            configuring: false,
            testProbing: false,
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
                motorR: 24000,
                manualSpec: DEFAULT_MANUAL_SPEC.slice() as number[]
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
        configuredSpindles(): number {
            const cfg = getOmGlobal("arborVFDConfig");
            if (!Array.isArray(cfg)) {
                return 0;
            }
            return cfg.filter((v: any) => v !== null && v !== undefined).length;
        },
        arborMaxLoadDisplay(): string {
            const v = getOmGlobal("arborMaxLoad");
            if (typeof v === "number" && Number.isFinite(v)) {
                return String(v);
            }
            return "80";
        },
        telemetryRows(): TelemetryRow[] {
            const cfg = getOmGlobal("arborVFDConfig");
            if (!Array.isArray(cfg)) {
                return [];
            }
            const models = getOmGlobal("arborAvailableModels");
            const internal = getOmGlobal("arborModelInternalNames");
            const st = getOmGlobal("arborVFDStatus");
            const pw = getOmGlobal("arborVFDPower");
            const comm = getOmGlobal("arborVFDCommReady");
            const rows: TelemetryRow[] = [];
            for (let i = 0; i < cfg.length; i++) {
                if (cfg[i] == null) {
                    continue;
                }
                const typeIdx = cfg[i][0];
                let driveName = `Type ${typeIdx}`;
                if (Array.isArray(models) && models[typeIdx] != null) {
                    driveName = String(models[typeIdx]);
                } else if (Array.isArray(internal) && internal[typeIdx] != null) {
                    driveName = String(internal[typeIdx]);
                }
                const s = Array.isArray(st) ? st[i] : null;
                const p = Array.isArray(pw) ? pw[i] : null;
                let commLabel = "—";
                let commColor = "grey";
                if (Array.isArray(comm) && comm[i] === true) {
                    commLabel = "OK";
                    commColor = "success";
                } else if (Array.isArray(comm) && comm[i] === false) {
                    commLabel = "Off";
                    commColor = "warning";
                }
                const load1 = p != null && Array.isArray(p) ? p[1] : null;
                let loadBar = -1;
                if (typeof load1 === "number" && Number.isFinite(load1)) {
                    loadBar = Math.min(100, Math.max(0, load1));
                }
                rows.push({
                    id: i,
                    driveName,
                    commLabel,
                    commColor,
                    running: fmtTelemetryBool(s != null && Array.isArray(s) ? s[0] : null),
                    dir: fmtTelemetryDir(s != null && Array.isArray(s) ? s[1] : null),
                    hz: fmtTelemetryNum(s != null && Array.isArray(s) ? s[2] : null, 2),
                    rpm: fmtTelemetryNum(s != null && Array.isArray(s) ? s[3] : null, 0),
                    stable: fmtTelemetryBool(s != null && Array.isArray(s) ? s[4] : null),
                    watts: fmtTelemetryNum(p != null && Array.isArray(p) ? p[0] : null, 0),
                    loadPct: fmtTelemetryNum(load1, 1),
                    loadBar
                });
            }
            return rows;
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
                    { text: "Yalang YL620-A", value: 2 },
                    { text: "Manual Modbus (experimental)", value: MANUAL_MODBUS_INDEX },
                    { text: "TH Servo (preliminary)", value: TH_SERVO_INDEX }
                ];
            }
            return m.map((text: string, i: number) => ({ text, value: i }));
        },
        isManualModbus(): boolean {
            return this.form.typeIndex === MANUAL_MODBUS_INDEX;
        },
        isThServo(): boolean {
            return this.form.typeIndex === TH_SERVO_INDEX;
        },
        motorFreqLabel(): string {
            return this.isThServo ? "Frequency (Hz, legacy file field)" : "Frequency (Hz)";
        },
        /** RRF spindle min/max RPM as used by th-servo/control.g (rated RPM caps max). */
        spindleRpmLimits(): { t: number; e: number } {
            const model = (store.state as any)?.machine?.model;
            const spindles = model?.spindles;
            const sid = this.form.spindleId;
            const ratedR = Number(this.form.motorR);
            const s = spindles && spindles[sid];
            if (!s) {
                return {
                    t: 0,
                    e: Number.isFinite(ratedR) && ratedR > 0 ? ratedR : 0
                };
            }
            const minRpm = s.min != null ? Number(s.min) : 0;
            let maxRpm = s.max != null ? Number(s.max) : 0;
            if (maxRpm <= 0 && Number.isFinite(ratedR) && ratedR > 0) {
                maxRpm = ratedR;
            }
            const t = Math.max(0, minRpm);
            let e = maxRpm > 0 ? maxRpm : ratedR;
            if (Number.isFinite(ratedR) && ratedR > 0) {
                e = Math.min(e, ratedR);
            }
            e = Math.max(t, e);
            return { t, e };
        },
        manualSpecValid(): boolean {
            const s = this.form.manualSpec;
            if (!Array.isArray(s) || s.length !== 11) {
                return false;
            }
            for (let i = 0; i < 11; i++) {
                if (typeof s[i] !== "number" || !Number.isFinite(s[i])) {
                    return false;
                }
            }
            if (s[6] === 0 || s[7] === 0 || s[8] === 0 || s[9] === 0) {
                return false;
            }
            if (s[0] < 0 || s[1] < 0) {
                return false;
            }
            if (s[2] < 0 || s[10] < -1) {
                return false;
            }
            return true;
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
            const fallback = [
                "shihlin-sl3",
                "huanyang-hy02d223b",
                "yalang-yl620a",
                "modbus-manual-experimental",
                "th-servo"
            ];
            return fallback[this.form.typeIndex] || "huanyang-hy02d223b";
        },
        canSave(): boolean {
            const hz = this.hzLimits;
            const base =
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
                hz.e >= hz.t;
            if (!base) {
                return false;
            }
            if (this.isManualModbus && !this.manualSpecValid) {
                return false;
            }
            return true;
        },
        /** Holding register for FC3 test read (Huanyang uses a separate macro). */
        probeRegisterForQuickTest(): number {
            const int = this.internalName;
            if (int === "huanyang-hy02d223b") {
                return -1;
            }
            if (this.form.typeIndex === MANUAL_MODBUS_INDEX) {
                const pr = this.form.manualSpec[10];
                if (typeof pr === "number" && pr >= 0) {
                    return pr;
                }
                const fw = this.form.manualSpec[0];
                if (typeof fw === "number" && fw >= 0) {
                    return fw;
                }
                return -1;
            }
            if (int === "th-servo") {
                return 4096;
            }
            if (int === "shihlin-sl3") {
                return 0x005a;
            }
            if (int === "yalang-yl620a") {
                return 0x0d01;
            }
            return 5000;
        },
        canProbeModbus(): boolean {
            if (this.form.address < 1 || this.form.address > 247) {
                return false;
            }
            const ch = this.form.channel;
            if (ch < 1 || ch > 3) {
                return false;
            }
            if (this.internalName === "huanyang-hy02d223b") {
                return true;
            }
            return this.probeRegisterForQuickTest >= 0;
        },
        probeModbusCaption(): string {
            if (this.internalName === "huanyang-hy02d223b") {
                return "Test Modbus: Huanyang uses the same raw-frame read as config (not FC3). Result is echoed on the Duet console.";
            }
            const r = this.probeRegisterForQuickTest;
            if (r < 0) {
                return "Test Modbus: set Manual probe reg (≥0) or freq-write reg for an FC3 read.";
            }
            return `Test Modbus: FC3 read of holding register ${r} using baud/channel/address above (console shows OK/FAIL).`;
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
            const spec = getGlobal("arborModbusManualSpec");
            if (Array.isArray(spec) && spec[sid] != null) {
                const row = spec[sid];
                if (Array.isArray(row) && row.length === 11) {
                    this.form.manualSpec = row.slice() as number[];
                }
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
            if (f.typeIndex === MANUAL_MODBUS_INDEX) {
                lines.push(
                    `set global.arborModbusManualSpec[${f.spindleId}] = {${f.manualSpec.join(
                        ", "
                    )}} ; Manual Modbus (experimental) — see doc/modbus-manual-experimental.md`,
                    ""
                );
            }
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
                // Reload user vars so globals (e.g. arborModbusManualSpec) match the file we just uploaded
                // before config.g reads them — especially for Manual Modbus (experimental).
                await store.dispatch("machine/sendCode", {
                    code: 'M98 P"0:/sys/arborctl-user-vars.g"'
                });
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
                await store.dispatch("machine/sendCode", { code: "G8001" });
            } catch (e) {
                console.error("[ArborCTL] Failed to start wizard", e);
            }
        },
        async testModbusProbe(): Promise<void> {
            this.saveError = "";
            this.testProbing = true;
            try {
                const f = this.form;
                const int = this.internalName;
                if (f.address < 1 || f.address > 247) {
                    this.saveError = "Modbus address must be between 1 and 247.";
                    return;
                }
                if (int === "huanyang-hy02d223b") {
                    await store.dispatch("machine/sendCode", {
                        code: `M98 P"arborctl/huanyang-quick-probe.g" B${f.baud} C${f.channel} A${f.address}`
                    });
                    return;
                }
                const r = this.probeRegisterForQuickTest;
                if (typeof r !== "number" || !Number.isFinite(r) || r < 0) {
                    this.saveError =
                        "Set a valid FC3 register (Manual: probe reg ≥ 0, or use freq-write reg when probe is skipped).";
                    return;
                }
                await store.dispatch("machine/sendCode", {
                    code: `M98 P"arborctl/modbus-fc3-probe.g" B${f.baud} C${f.channel} A${f.address} R${r}`
                });
            } catch (e) {
                this.saveError = e instanceof Error ? e.message : String(e);
                console.error("[ArborCTL] Test Modbus failed", e);
            } finally {
                this.testProbing = false;
            }
        }
    }
});
</script>
