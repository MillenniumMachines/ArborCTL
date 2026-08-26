<template>
    <v-card class="ma-3">
        <v-card-title class="d-flex align-center">
            <v-icon class="mr-2" icon="mdi-cog-transfer" />
            ArborCTL
            <v-spacer />
            <v-chip size="small" label :color="loaded ? 'success' : 'warning'">
                {{ loaded ? "Loaded" : "Not loaded" }}
            </v-chip>
            <v-chip v-if="loaded && daemonPaused" size="small" label color="warning" class="ml-2">
                Daemon paused
            </v-chip>
        </v-card-title>

        <v-card-subtitle>
            RS485 spindle control for RepRapFirmware 3.7+. Edit all parameters on one page, save to
            <code>0:/sys/arborctl-user-vars.g</code>, then reboot or run VFD setup.
        </v-card-subtitle>

        <v-card-text>
            <v-table density="compact">
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
            </v-table>

            <template v-if="loaded">
                <v-divider class="my-4" />
                <div class="text-subtitle-1 mb-1 d-flex align-center flex-wrap">
                    <v-icon class="mr-2" size="small" icon="mdi-gauge" />
                    Spindle load &amp; telemetry
                </div>
                <p class="text-caption text-medium-emphasis mb-2">
                    From <code>arborVFDStatus</code> / <code>arborVFDPower</code> (daemon polling). Load % is
                    driver-defined (e.g. VFD power estimate, H100 FC4 current/power, servo register, or 0).
                    Automatic feed override is disabled.
                    <code>global.arborMaxLoad</code> (<b>{{ arborMaxLoadDisplay }}%</b>) is a reserved threshold
                    for future spindle protection (feed % strategy, not daemon <code>M220</code>).
                </p>
                <v-table v-if="telemetryRows.length > 0" density="compact">
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
                                <v-chip size="x-small" label :color="row.commColor">{{ row.commLabel }}</v-chip>
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
                                        :model-value="row.loadBar"
                                        height="8"
                                        color="primary"
                                        class="flex-grow-1"
                                        style="max-width: 100px;"
                                    />
                                </div>
                            </td>
                        </tr>
                    </tbody>
                </v-table>
                <v-alert v-else type="info" density="compact" variant="outlined" class="mb-0">
                    No ArborCTL-configured spindles yet, or telemetry not available. Save a configuration and ensure the
                    arborctl daemon is running.
                </v-alert>
            </template>

            <v-alert v-if="!loaded" class="mt-4" type="warning" variant="outlined" density="compact">
                ArborCTL has not loaded. Ensure <code>M98 P"arborctl.g"</code> is at the end of <code>config.g</code> and reset the board.
            </v-alert>

            <v-alert v-if="!hasConfiguredSpindle" class="mt-4" type="warning" variant="outlined" density="compact">
                No RRF spindle is configured. Define a spindle with <code>M950 R...</code> in <code>config.g</code> before binding it to a VFD here.
            </v-alert>

            <v-alert
                v-if="loaded"
                class="mt-4"
                :type="daemonPaused ? 'warning' : 'info'"
                variant="outlined"
                density="compact"
            >
                <div class="font-weight-medium mb-1">Plugin update</div>
                <p class="text-caption mb-2">
                    {{ daemonPaused ? pluginUpdatePausedHint : pluginUpdateIdleHint }}
                </p>
                <div class="d-flex flex-wrap">
                    <v-btn
                        class="mr-2 mb-1"
                        color="warning"
                        variant="outlined"
                        size="small"
                        :disabled="uiFrozen || preparingUpdate || resumingUpdate"
                        :loading="preparingUpdate"
                        @click="preparePluginUpdate"
                    >
                        Pause daemon
                    </v-btn>
                    <v-btn
                        class="mb-1"
                        color="primary"
                        variant="outlined"
                        size="small"
                        :disabled="uiFrozen || preparingUpdate || resumingUpdate || !daemonPaused"
                        :loading="resumingUpdate"
                        @click="resumePluginUpdate"
                    >
                        Resume daemon
                    </v-btn>
                </div>
            </v-alert>

            <v-divider class="my-4" />

            <div class="text-subtitle-1 mb-2">UART &amp; drive</div>
            <v-row dense>
                <v-col cols="12" sm="6" md="4">
                    <v-select
                        v-model="form.channel"
                        :items="channelItems"
                        item-title="text"
                        item-value="value"
                        label="UART port"
                        density="compact"
                        variant="outlined"
                        hide-details="auto"
                    />
                </v-col>
                <v-col cols="12" sm="6" md="4">
                    <v-select
                        v-model="form.baud"
                        :items="baudItems"
                        label="Baud rate"
                        density="compact"
                        variant="outlined"
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
                        density="compact"
                        variant="outlined"
                        hide-details="auto"
                    />
                </v-col>
                <v-col cols="12" sm="6" md="6">
                    <v-select
                        v-model="form.typeIndex"
                        :items="modelItems"
                        item-title="text"
                        item-value="value"
                        label="VFD model"
                        density="compact"
                        variant="outlined"
                        hide-details="auto"
                        @update:model-value="onModelChange"
                    />
                </v-col>
                <v-col cols="12" sm="6" md="6">
                    <v-select
                        v-model="form.spindleId"
                        :items="spindleSelectItems"
                        item-title="text"
                        item-value="value"
                        label="RRF spindle"
                        density="compact"
                        variant="outlined"
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
                        density="compact"
                        variant="outlined"
                        hide-details="auto"
                    />
                </v-col>
                <v-col cols="6" sm="4" md="3">
                    <v-select
                        v-model.number="form.motorPoles"
                        :items="poleItems"
                        label="Poles"
                        density="compact"
                        variant="outlined"
                        hide-details="auto"
                    />
                </v-col>
                <v-col cols="6" sm="4" md="3">
                    <v-text-field
                        v-model.number="form.motorV"
                        type="number"
                        label="Voltage (V)"
                        density="compact"
                        variant="outlined"
                        hide-details="auto"
                    />
                </v-col>
                <v-col cols="6" sm="4" md="3">
                    <v-text-field
                        v-model.number="form.motorF"
                        type="number"
                        :label="motorFreqLabel"
                        density="compact"
                        variant="outlined"
                        hide-details="auto"
                    />
                </v-col>
                <v-col cols="6" sm="4" md="3">
                    <v-text-field
                        v-model.number="form.motorI"
                        type="number"
                        label="Current (A)"
                        step="0.1"
                        density="compact"
                        variant="outlined"
                        hide-details="auto"
                    />
                </v-col>
                <v-col cols="6" sm="4" md="3">
                    <v-text-field
                        v-model.number="form.motorR"
                        type="number"
                        label="Rated speed (RPM)"
                        density="compact"
                        variant="outlined"
                        hide-details="auto"
                    />
                </v-col>
                <v-col cols="6" sm="4" md="3">
                    <v-text-field
                        v-model.number="form.accelSec"
                        type="number"
                        step="0.1"
                        min="0.1"
                        label="Accel (s)"
                        density="compact"
                        variant="outlined"
                        hide-details="auto"
                    />
                </v-col>
                <v-col cols="6" sm="4" md="3">
                    <v-text-field
                        v-model.number="form.decelSec"
                        type="number"
                        step="0.1"
                        min="0.1"
                        label="Decel (s)"
                        density="compact"
                        variant="outlined"
                        hide-details="auto"
                    />
                </v-col>
            </v-row>

            <v-row v-if="isThServo" dense class="mt-1">
                <v-col cols="12">
                    <v-chip size="small" class="mr-2" variant="outlined">
                        Min RPM (RRF spindle vs rated): {{ spindleRpmLimits.t }}
                    </v-chip>
                    <v-chip size="small" variant="outlined">
                        Max RPM (RRF spindle vs rated): {{ spindleRpmLimits.e }}
                    </v-chip>
                </v-col>
            </v-row>
            <v-row v-else dense class="mt-1">
                <v-col cols="12">
                    <v-chip size="small" class="mr-2" variant="outlined">
                        Min Hz (from RRF spindle limits): {{ hzLimits.t }}
                    </v-chip>
                    <v-chip size="small" variant="outlined">
                        Max Hz (from RRF spindle limits): {{ hzLimits.e }}
                    </v-chip>
                </v-col>
            </v-row>
            <v-row dense class="mt-1">
                <v-col cols="12">
                    <v-chip size="small" class="mr-2" variant="outlined">
                        Implied max RPM (120 × Hz / poles): {{ impliedMaxRpm }}
                    </v-chip>
                    <v-chip size="small" variant="outlined">
                        Preview: {{ previewCmdRpm }} RPM → {{ previewHz }} Hz
                    </v-chip>
                </v-col>
            </v-row>
            <v-alert
                v-if="nameplateRpmMismatch"
                type="error"
                density="compact"
                variant="outlined"
                class="mt-2"
            >
                Rated RPM {{ form.motorR }} does not match 120 × Hz / poles = {{ impliedMaxRpm }}.
                2-pole 400 Hz is 24000 RPM; 4-pole 400 Hz is 12000 RPM.
            </v-alert>
            <v-alert
                v-if="rrfMaxExceedsNameplate"
                type="error"
                density="compact"
                variant="outlined"
                class="mt-2"
            >
                RRF spindle max exceeds nameplate {{ impliedMaxRpm }} RPM. Frequency would clamp and that RPM would never be reached.
            </v-alert>
            <p v-if="isThServo" class="text-caption text-medium-emphasis mt-2 mb-0">
                TH Servo runs in <b>RPM</b>: the driver uses RRF spindle <b>min</b>/<b>max</b> (RPM) and nameplate rated RPM.
                <b>Frequency (Hz)</b> is still saved into <code>arborWizardFreqLimits</code> for compatibility; the TH driver does not use Hz for speed.
                Rated RPM must still match <b>120 × Hz / poles</b>. Baud is not on the object model — set it here to match <b>M575</b>.
            </p>
            <p v-else class="text-caption text-medium-emphasis mt-2 mb-0">
                Hz = |RPM| × poles / 120 (2-pole 400 Hz = 24k RPM). Limits come from RRF spindle min/max, capped by rated Hz.
                Accel/decel are written to the VFD on Apply (the start lag after the run command is this ramp, not daemon lag).
                Baud is not exposed on the object model; set it here to match <b>M575</b> in your user vars file.
            </p>

            <template v-if="isManualModbus">
                <v-divider class="my-4" />
                <div class="text-subtitle-1 mb-2">
                    Manual Modbus map
                    <v-chip size="x-small" class="ml-2" color="amber" label>experimental</v-chip>
                </div>
                <p class="text-caption mb-2">
                    Eleven holding-register integers (FC3 / FC6). See
                    <a href="https://github.com/MillenniumMachines/ArborCTL/blob/main/doc/modbus-manual-experimental.md" target="_blank" rel="noopener">modbus-manual-experimental.md</a>
                    (or <code>doc/modbus-manual-experimental.md</code> in the repo).
                </p>
                <v-row dense>
                    <v-col cols="6" sm="4" md="3">
                        <v-text-field v-model.number="form.manualSpec[0]" type="number" label="Freq write reg" density="compact" variant="outlined" hide-details="auto" />
                    </v-col>
                    <v-col cols="6" sm="4" md="3">
                        <v-text-field v-model.number="form.manualSpec[1]" type="number" label="Cmd reg" density="compact" variant="outlined" hide-details="auto" />
                    </v-col>
                    <v-col cols="6" sm="4" md="3">
                        <v-text-field v-model.number="form.manualSpec[2]" type="number" label="Freq read reg (0=none)" density="compact" variant="outlined" hide-details="auto" />
                    </v-col>
                    <v-col cols="6" sm="4" md="3">
                        <v-text-field v-model.number="form.manualSpec[10]" type="number" label="Probe reg (-1=skip)" density="compact" variant="outlined" hide-details="auto" />
                    </v-col>
                    <v-col cols="4" sm="3" md="2">
                        <v-text-field v-model.number="form.manualSpec[3]" type="number" label="Run fwd value" density="compact" variant="outlined" hide-details="auto" />
                    </v-col>
                    <v-col cols="4" sm="3" md="2">
                        <v-text-field v-model.number="form.manualSpec[4]" type="number" label="Run rev value" density="compact" variant="outlined" hide-details="auto" />
                    </v-col>
                    <v-col cols="4" sm="3" md="2">
                        <v-text-field v-model.number="form.manualSpec[5]" type="number" label="Stop value" density="compact" variant="outlined" hide-details="auto" />
                    </v-col>
                    <v-col cols="6" sm="4" md="3">
                        <v-text-field v-model.number="form.manualSpec[6]" type="number" label="Write scale num" density="compact" variant="outlined" hide-details="auto" />
                    </v-col>
                    <v-col cols="6" sm="4" md="3">
                        <v-text-field v-model.number="form.manualSpec[7]" type="number" label="Write scale den" density="compact" variant="outlined" hide-details="auto" />
                    </v-col>
                    <v-col cols="6" sm="4" md="3">
                        <v-text-field v-model.number="form.manualSpec[8]" type="number" label="Read scale num" density="compact" variant="outlined" hide-details="auto" />
                    </v-col>
                    <v-col cols="6" sm="4" md="3">
                        <v-text-field v-model.number="form.manualSpec[9]" type="number" label="Read scale den" density="compact" variant="outlined" hide-details="auto" />
                    </v-col>
                </v-row>
            </template>

            <v-divider class="my-4" />

            <div class="d-flex flex-wrap align-center">
                <v-btn color="primary" class="mr-2 mb-2" :disabled="uiFrozen || !canSave" :loading="configuring" @click="saveAndConfigureVfd">
                    <v-icon start size="small" icon="mdi-serial-port" />
                    Apply VFD config
                </v-btn>
                <v-btn color="secondary" class="mr-2 mb-2" :disabled="uiFrozen || !canSave" :loading="saving" @click="saveUserVars">
                    <v-icon start size="small" icon="mdi-content-save" />
                    Save vars only
                </v-btn>
                <v-btn
                    class="mr-2 mb-2"
                    variant="outlined"
                    color="deep-orange"
                    :disabled="uiFrozen || !canProbeModbus"
                    :loading="testProbing"
                    @click="testModbusProbe"
                >
                    <v-icon start size="small" icon="mdi-network-outline" />
                    Test Modbus
                </v-btn>
                <v-btn class="mb-2" color="secondary" variant="text" href="https://github.com/MillenniumMachines/ArborCTL" target="_blank" rel="noopener">
                    <v-icon start size="small" icon="mdi-github" />
                    Documentation
                </v-btn>
            </div>
            <p class="text-caption text-medium-emphasis mt-1 mb-0">{{ probeModbusCaption }}</p>
            <v-alert v-if="saveError" type="error" density="compact" variant="outlined" class="mt-2">{{ saveError }}</v-alert>
        </v-card-text>
    </v-card>
</template>

<script lang="ts">
import { defineComponent } from "vue";

import store from "./compat/dwcStore";
import {
    ARBORCTL_USER_VARS_PATH,
    ARBOR_UART_CHANNELS,
    FALLBACK_ARBOR_MODELS,
    MANUAL_MODBUS_INDEX,
    arborInternalName,
    arborTypeName,
    buildArborCtlConfigCode,
    buildArborCtlUserVarsFile,
    clampArborUartChannel,
    isArborUartChannel
} from "./arborctlApply";

function getGlobal(key: string): any {
    const model = store.state?.machine?.model as any;
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

/** Index of "TH Servo (preliminary)" — see arborctlApply MANUAL_MODBUS_INDEX */
const TH_SERVO_INDEX = 4;

/** Index of "H100" */
const H100_INDEX = 5;

const DEFAULT_MANUAL_SPEC = [5000, 5001, 5002, 1, 2, 0, 1, 1, 1, 100, 5000];

export default defineComponent({
    name: "ArborCTL",
    beforeCreate() {
        Object.defineProperty(this, "$store", { get: () => store, configurable: true });
    },
    data() {
        return {
            saving: false,
            configuring: false,
            testProbing: false,
            preparingUpdate: false,
            resumingUpdate: false,
            saveError: "" as string,
            form: {
                channel: 2,
                baud: 9600,
                address: 1,
                typeIndex: 1,
                spindleId: 0,
                motorW: 1.5,
                motorPoles: 2,
                motorV: 220,
                motorF: 400,
                motorI: 4.0,
                motorR: 24000,
                accelSec: 2.5,
                decelSec: 2.5,
                manualSpec: DEFAULT_MANUAL_SPEC.slice() as number[]
            }
        };
    },
    computed: {
        uiFrozen(): boolean {
            return store.state.machine.model.state.status === "processing";
        },
        loaded(): boolean {
            return Boolean(getGlobal("arborctlLdd"));
        },
        daemonEnabled(): boolean {
            const v = getOmGlobal("arborctlDaemonEnabled");
            return v !== false;
        },
        daemonPaused(): boolean {
            return this.loaded && !this.daemonEnabled;
        },
        pluginUpdateIdleHint(): string {
            return "Before installing or upgrading the ArborCTL ZIP in DWC Settings → Plugins, pause the daemon so the installer can replace open numbered metas (M2604.g). After this release, later updates usually only need a pause once when migrating from an older ZIP.";
        },
        pluginUpdatePausedHint(): string {
            return "Daemon paused — install or update the ArborCTL plugin ZIP now, then Resume (or reboot). Resume applies pending *.install numbered metas.";
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
            const st = getOmGlobal("arborVFDStatus");
            const pw = getOmGlobal("arborVFDPower");
            const comm = getOmGlobal("arborVFDCommReady");
            const rows: TelemetryRow[] = [];
            for (let i = 0; i < cfg.length; i++) {
                if (cfg[i] == null) {
                    continue;
                }
                const typeIdx = cfg[i][0];
                const driveName = arborTypeName(typeof typeIdx === "number" ? typeIdx : 0);
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
            return ARBOR_UART_CHANNELS;
        },
        baudItems(): number[] {
            return BAUD_LIST;
        },
        poleItems(): number[] {
            return [2, 4];
        },
        modelItems(): Array<{ text: string; value: number }> {
            return FALLBACK_ARBOR_MODELS.map((text, i) => ({ text, value: i }));
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
        spindleRpmLimits(): { t: number; e: number } {
            const model = store.state.machine.model as any;
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
            const model = store.state.machine.model as any;
            const spindles = model?.spindles;
            const maxS = model?.limits?.spindles ?? 8;
            const items: Array<{ text: string; value: number }> = [];
            for (let i = 0; i < maxS; i++) {
                const s = spindles && spindles[i];
                if (s && s.state !== "unconfigured") {
                    items.push({ text: `Spindle ${i}`, value: i });
                }
            }
            return items;
        },
        hasConfiguredSpindle(): boolean {
            return this.spindleSelectItems.length > 0;
        },
        hzLimits(): { t: number; e: number } {
            const model = store.state.machine.model as any;
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
        impliedMaxRpm(): number {
            const poles = Number(this.form.motorPoles);
            const mf = Number(this.form.motorF);
            if (!poles || !mf || !Number.isFinite(poles) || !Number.isFinite(mf)) {
                return 0;
            }
            return Math.round((120 * mf) / poles);
        },
        nameplateRpmTol(): number {
            const implied = this.impliedMaxRpm;
            if (implied <= 0) {
                return 50;
            }
            return Math.max(50, implied * 0.01);
        },
        nameplateRpmMismatch(): boolean {
            const rated = Number(this.form.motorR);
            const implied = this.impliedMaxRpm;
            if (!Number.isFinite(rated) || implied <= 0) {
                return false;
            }
            return Math.abs(rated - implied) > this.nameplateRpmTol;
        },
        rrfMaxExceedsNameplate(): boolean {
            const model = store.state.machine.model as any;
            const spindles = model?.spindles;
            const sid = this.form.spindleId;
            const s = spindles && spindles[sid];
            const implied = this.impliedMaxRpm;
            if (!s || implied <= 0) {
                return false;
            }
            const maxRpm = s.max != null ? Number(s.max) : 0;
            if (!Number.isFinite(maxRpm) || maxRpm <= 0) {
                return false;
            }
            return maxRpm > implied + this.nameplateRpmTol;
        },
        previewCmdRpm(): number {
            const model = store.state.machine.model as any;
            const spindles = model?.spindles;
            const sid = this.form.spindleId;
            const s = spindles && spindles[sid];
            if (s && s.max != null) {
                const maxRpm = Number(s.max);
                if (Number.isFinite(maxRpm) && maxRpm > 0) {
                    return Math.round(maxRpm);
                }
            }
            const rated = Number(this.form.motorR);
            return Number.isFinite(rated) && rated > 0 ? Math.round(rated) : 0;
        },
        previewHz(): number {
            const poles = Number(this.form.motorPoles);
            const rpm = this.previewCmdRpm;
            if (!poles || !rpm || !Number.isFinite(poles) || !Number.isFinite(rpm)) {
                return 0;
            }
            return Math.round((rpm / 120) * poles);
        },
        modelTypeName(): string {
            return arborTypeName(this.form.typeIndex);
        },
        internalName(): string {
            return arborInternalName(this.form.typeIndex);
        },
        canSave(): boolean {
            if (!this.hasConfiguredSpindle) {
                return false;
            }
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
                this.form.accelSec > 0 &&
                this.form.decelSec > 0 &&
                Number.isFinite(hz.t) &&
                Number.isFinite(hz.e) &&
                hz.e >= hz.t;
            if (!base) {
                return false;
            }
            if (this.isManualModbus && !this.manualSpecValid) {
                return false;
            }
            if (!isArborUartChannel(this.form.channel)) {
                return false;
            }
            if (this.nameplateRpmMismatch || this.rrfMaxExceedsNameplate) {
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
            if (int === "h100") {
                return 0x0005;
            }
            return 5000;
        },
        canProbeModbus(): boolean {
            if (this.form.address < 1 || this.form.address > 247) {
                return false;
            }
            if (!isArborUartChannel(this.form.channel)) {
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
                        this.form.channel = clampArborUartChannel(c[1]);
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
            const ramp = getGlobal("arborWizardRamp");
            if (Array.isArray(ramp) && ramp[sid] != null && Array.isArray(ramp[sid]) && ramp[sid].length >= 2) {
                const r = ramp[sid] as number[];
                if (typeof r[0] === "number" && Number.isFinite(r[0]) && r[0] > 0) {
                    this.form.accelSec = r[0];
                }
                if (typeof r[1] === "number" && Number.isFinite(r[1]) && r[1] > 0) {
                    this.form.decelSec = r[1];
                }
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
            return buildArborCtlUserVarsFile(this.form, this.hzLimits, this.modelTypeName);
        },
        async saveUserVars(options?: { quiet?: boolean }): Promise<void> {
            this.saveError = "";
            this.saving = true;
            try {
                const content = this.buildUserVarsFile();
                await store.dispatch("machine/upload", {
                    filename: ARBORCTL_USER_VARS_PATH,
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
                await store.dispatch("machine/sendCode", `M98 P"${ARBORCTL_USER_VARS_PATH}"`);
                await store.dispatch("machine/sendCode", buildArborCtlConfigCode(f, hz, internal));
            } catch (e) {
                this.saveError = e instanceof Error ? e.message : String(e);
                console.error("[ArborCTL] VFD config failed", e);
            } finally {
                this.configuring = false;
            }
        },
        async preparePluginUpdate(): Promise<void> {
            this.saveError = "";
            this.preparingUpdate = true;
            try {
                await store.dispatch("machine/sendCode", 'M98 P"arborctl/prepare-plugin-update.g"');
            } catch (e) {
                this.saveError = e instanceof Error ? e.message : String(e);
                console.error("[ArborCTL] Prepare plugin update failed", e);
            } finally {
                this.preparingUpdate = false;
            }
        },
        async resumePluginUpdate(): Promise<void> {
            this.saveError = "";
            this.resumingUpdate = true;
            try {
                await store.dispatch("machine/sendCode", 'M98 P"arborctl/prepare-plugin-update.g" S1');
            } catch (e) {
                this.saveError = e instanceof Error ? e.message : String(e);
                console.error("[ArborCTL] Resume plugin update failed", e);
            } finally {
                this.resumingUpdate = false;
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
                    await store.dispatch(
                        "machine/sendCode",
                        `M98 P"arborctl/huanyang-quick-probe.g" B${f.baud} C${f.channel} A${f.address}`
                    );
                    return;
                }
                const r = this.probeRegisterForQuickTest;
                if (typeof r !== "number" || !Number.isFinite(r) || r < 0) {
                    this.saveError =
                        "Set a valid FC3 register (Manual: probe reg ≥ 0, or use freq-write reg when probe is skipped).";
                    return;
                }
                await store.dispatch(
                    "machine/sendCode",
                    `M98 P"arborctl/modbus-fc3-probe.g" B${f.baud} C${f.channel} A${f.address} R${r}`
                );
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
