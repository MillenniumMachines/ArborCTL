<template>
	<v-container fluid>
		<v-row>
			<v-col cols="12">
				<v-card>
					<v-card-title class="headline">ArborCTL Spindle Dashboard</v-card-title>
					<v-card-text>
						<p>Real-time metrics from the RepRapFirmware Object Model.</p>
					</v-card-text>
				</v-card>
			</v-col>
		</v-row>
		<v-row v-if="arborStatus && arborStatus.length > 0 && arborStatus[0]">
			<v-col cols="12" md="6">
				<v-card outlined>
					<v-card-title>
						<v-icon left>mdi-engine</v-icon> Operation Status
					</v-card-title>
					<v-card-text>
						<v-list dense>
							<v-list-item>
								<v-list-item-content>Running</v-list-item-content>
								<v-list-item-action>
									<v-chip :color="arborStatus[0][0] ? 'green' : 'grey'" text-color="white" small>
										{{ arborStatus[0][0] ? 'Yes' : 'No' }}
									</v-chip>
								</v-list-item-action>
							</v-list-item>
							<v-list-item>
								<v-list-item-content>Direction</v-list-item-content>
								<v-list-item-action>
									<strong>{{ arborStatus[0][1] === 1 ? 'Forward' : (arborStatus[0][1] === -1 ? 'Reverse' : 'Stopped') }}</strong>
								</v-list-item-action>
							</v-list-item>
							<v-list-item>
								<v-list-item-content>Target Speed</v-list-item-content>
								<v-list-item-action>
									<strong>{{ arborStatus[0][2] }} RPM</strong>
								</v-list-item-action>
							</v-list-item>
							<v-list-item>
								<v-list-item-content>Actual Speed</v-list-item-content>
								<v-list-item-action>
									<strong>{{ arborStatus[0][3] }} RPM</strong>
								</v-list-item-action>
							</v-list-item>
							<v-list-item>
								<v-list-item-content>Stable</v-list-item-content>
								<v-list-item-action>
									<v-chip :color="arborStatus[0][4] ? 'green' : 'orange'" text-color="white" small>
										{{ arborStatus[0][4] ? 'Stable' : 'Unstable' }}
									</v-chip>
								</v-list-item-action>
							</v-list-item>
						</v-list>
					</v-card-text>
				</v-card>
			</v-col>
			<v-col cols="12" md="6" v-if="arborPower && arborPower.length > 0 && arborPower[0]">
				<v-card outlined>
					<v-card-title>
						<v-icon left>mdi-flash</v-icon> Load & Power
					</v-card-title>
					<v-card-text>
						<v-list dense>
							<v-list-item>
								<v-list-item-content>Instantaneous Power</v-list-item-content>
								<v-list-item-action>
									<strong>{{ Number(arborPower[0][0]).toFixed(2) }} W</strong>
								</v-list-item-action>
							</v-list-item>
							<v-list-item>
								<v-list-item-content>Load Percentage</v-list-item-content>
								<v-list-item-action>
									<strong>{{ Number(arborPower[0][1]).toFixed(1) }} %</strong>
								</v-list-item-action>
							</v-list-item>
						</v-list>
						<div class="mt-4">
							<v-progress-linear 
								:value="arborPower[0][1]" 
								height="25" 
								:color="arborPower[0][1] > 80 ? 'red' : (arborPower[0][1] > 60 ? 'orange' : 'green')">
								<template v-slot:default="{ value }">
									<strong>{{ Math.ceil(value) }}% Load</strong>
								</template>
							</v-progress-linear>
						</div>
					</v-card-text>
				</v-card>
			</v-col>
		</v-row>
		<v-row v-else>
			<v-col cols="12">
				<v-alert type="warning" outlined>
					Waiting for ArborCTL variables to populate in the Object Model. Is the daemon running?
				</v-alert>
			</v-col>
		</v-row>
	</v-container>
</template>

<script>
export default {
	name: 'ArborCtlDashboard',
	computed: {
		arborStatus() {
			if (this.$store && this.$store.state && this.$store.state.machine && this.$store.state.machine.variables) {
				return this.$store.state.machine.variables.arborVFDStatus;
			}
			return null;
		},
		arborPower() {
			if (this.$store && this.$store.state && this.$store.state.machine && this.$store.state.machine.variables) {
				return this.$store.state.machine.variables.arborVFDPower;
			}
			return null;
		}
	}
}
</script>
