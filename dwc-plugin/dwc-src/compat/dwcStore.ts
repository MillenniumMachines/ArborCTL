/**
 * dwcStore.ts — Vuex-compatible shim for DWC 3.7 (Pinia + Composition API).
 *
 * Adapted from NeXT ui/src/compat/dwcStore.ts. ArborCTL Options API code still
 * uses store.state.machine.model / store.dispatch("machine/...") shapes.
 *
 * Important: machine/sendCode expects a **string** (not `{ code: "..." }`).
 */
import type { ComponentCustomProperties } from "vue";
import { useMachineStore } from "@/stores/machine";
import { useSettingsStore } from "@/stores/settings";
import { useUiStore, LogLevel } from "@/stores/ui";

export { LogLevel };

function machineStore() {
	return useMachineStore();
}

function settingsStore() {
	return useSettingsStore();
}

function uiStore() {
	return useUiStore();
}

function buildMachineSettingsShim() {
	return {
		get spindleRPM(): Array<number> {
			return settingsStore().spindleRPM;
		},
		get moveSteps(): Record<string, Array<number>> {
			return settingsStore().moveSteps;
		},
		get displayedAxes(): Array<number> {
			const axes = machineStore().model.move.axes;
			const visible: Array<number> = [];
			for (let i = 0; i < axes.length; i++) {
				if (axes[i]?.visible) {
					visible.push(i);
				}
			}
			return visible;
		}
	};
}

function buildMachineStateShim() {
	return {
		get model() {
			return machineStore().model;
		},
		get settings() {
			return buildMachineSettingsShim();
		},
		get variables() {
			return (machineStore() as any).variables;
		}
	};
}

function buildSettingsStateShim() {
	return {
		get plugins(): Record<string, any> {
			return settingsStore().plugins;
		}
	};
}

function toLogLevel(type: unknown): LogLevel {
	if (typeof type === "string" && (Object.values(LogLevel) as Array<string>).includes(type)) {
		return type as LogLevel;
	}
	return LogLevel.info;
}

export interface DwcCompatStore {
	getters: { readonly isConnected: boolean };
	state: {
		machine: ReturnType<typeof buildMachineStateShim>;
		settings: ReturnType<typeof buildSettingsStateShim>;
	};
	dispatch(action: string, payload?: any): Promise<any>;
	subscribe(callback: (mutation: { type: string; payload?: any }) => void): () => void;
}

const store: DwcCompatStore = {
	get getters() {
		return {
			get isConnected(): boolean {
				return machineStore().isConnected;
			}
		};
	},

	get state() {
		return {
			get machine() {
				return buildMachineStateShim();
			},
			get settings() {
				return buildSettingsStateShim();
			}
		} as unknown as DwcCompatStore["state"];
	},

	async dispatch(action: string, payload?: any): Promise<any> {
		switch (action) {
			case "machine/sendCode": {
				const code =
					typeof payload === "string"
						? payload
						: payload?.code != null
							? String(payload.code)
							: "";
				return await machineStore().sendCode(code);
			}

			case "machine/showMessage": {
				const { type, message, title } = payload ?? {};
				return uiStore().makeNotification(toLogLevel(type), title || "ArborCTL", message ?? null);
			}

			case "machine/upload": {
				const { filename, content, showProgress, showSuccess, showError } = payload ?? {};
				return await machineStore().upload({ filename, content }, showProgress, showSuccess, showError);
			}

			case "machine/delete": {
				const filename = typeof payload === "string" ? payload : payload?.filename;
				return await machineStore().delete(filename);
			}

			case "machine/download": {
				const { filename, type, showProgress, showSuccess, showError } =
					typeof payload === "string"
						? {
								filename: payload,
								type: undefined,
								showProgress: undefined,
								showSuccess: undefined,
								showError: undefined
							}
						: (payload ?? {});
				return await machineStore().download({ filename, type }, showProgress, showSuccess, showError);
			}

			case "machine/getFileList":
				return await machineStore().getFileList(payload as string);

			default:
				console.warn(`[ArborCTL] dwcStore.dispatch: unsupported action "${action}"`);
				return undefined;
		}
	},

	subscribe(_callback: (mutation: { type: string; payload?: any }) => void): () => void {
		return () => {};
	}
};

export default store;

export const PluginDataType = {
	globalSetting: "globalSetting"
} as const;

export function registerPluginData(plugin: string, _type: string, key: string, defaultValue: any): void {
	settingsStore().registerPluginData(plugin, key, defaultValue);
}

export function setPluginData(plugin: string, _type: string, key: string, value: any): void {
	settingsStore().setPluginData(plugin, key, value);
}

declare module "vue" {
	interface ComponentCustomProperties {
		$store: DwcCompatStore;
	}
}
export type { ComponentCustomProperties };
