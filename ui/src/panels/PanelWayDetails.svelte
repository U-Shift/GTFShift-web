<script lang="ts">
    import { Button } from "$lib/components/ui/button/index.js";
    import * as Tooltip from "$lib/components/ui/tooltip/index.js";
    import { getColorFromGradient } from "$lib/utils.js";
    import { COLOR_GRADIENT, COLOR_GRADIENT_RED, COLOR_TEAL } from "../data.js";
    import type { GeoPrioritization } from "../types/GeoPrioritization";

    let {
        selectedWayId = $bindable(),
        selected_shape_id = $bindable(),
        geoData,
        criteria_hour,
    }: {
        selectedWayId: string | undefined;
        selected_shape_id: string | undefined;
        geoData: GeoPrioritization | null;
        criteria_hour: number;
    } = $props();
</script>

<!-- Right Details Panel -->
{#if selectedWayId && geoData && geoData.wayData[selectedWayId]}
    {@const way = geoData.wayData[selectedWayId]}
    <div
        id="details-panel"
        class="absolute top-4 right-4 z-[1000] flex flex-col w-[400px] h-fit max-h-[calc(100vh-2rem)] rounded-xl bg-background/95 backdrop-blur shadow-lg border p-6 overflow-y-auto"
    >
        <div class="flex items-center justify-between mb-6">
            <h3 class="text-xl font-bold text-primary m-0">Way Details</h3>
            <Button
                variant="ghost"
                size="icon"
                onclick={() => (selectedWayId = undefined)}
                class="rounded-full"
            >
                <i class="fas fa-times"></i>
            </Button>
        </div>

        <div class="space-y-6 flex-1">
            <section>
                <div class="flex items-center gap-2 mb-2">
                    <span
                        class="text-xs font-bold uppercase tracking-wider text-muted-foreground"
                        >OSM ID</span
                    >
                    <a
                        href="https://www.openstreetmap.org/way/{selectedWayId}"
                        target="_blank"
                        class="text-xs font-mono text-blue-500 hover:underline"
                    >
                        {selectedWayId}
                        <i class="fas fa-external-link-alt ml-1"></i>
                    </a>
                </div>
                <h4 class="text-lg font-semibold">
                    {way.name || "Unnamed Way"}
                </h4>
            </section>

            <div class="grid grid-cols-2 gap-3">
                <!-- Bus Frequency Card -->
                <div
                    class="p-3 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 flex flex-col justify-between shadow-sm overflow-hidden relative"
                >
                    {#if true}
                        {@const freq = way.hour_frequency?.[criteria_hour] ?? 0}
                        {@const freqCensus =
                            geoData.metadata.data_census.frequency_hour[
                                criteria_hour
                            ]}
                        {@const freqColor = freqCensus
                            ? getColorFromGradient(
                                  freq,
                                  freqCensus.min,
                                  freqCensus.max,
                                  COLOR_GRADIENT,
                              )
                            : null}
                        <p
                            class="text-[10px] font-bold uppercase text-muted-foreground mb-1"
                        >
                            Buses/h ({criteria_hour}:00)
                        </p>
                        <p class="text-lg font-bold">
                            {freq}
                        </p>
                        {#if freqColor}
                            <div
                                class="absolute bottom-0 left-0 right-0 h-[3px] rounded-b-xl"
                                style="background-color: {freqColor}"
                            ></div>
                        {/if}
                    {/if}
                </div>

                <!-- Bus Lane Card -->
                <div
                    class="p-3 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 flex flex-col justify-between shadow-sm overflow-hidden relative"
                >
                    <p
                        class="text-[10px] font-bold uppercase text-muted-foreground mb-1"
                    >
                        Bus Lane
                    </p>
                    <p class="text-sm font-bold">
                        {way.is_bus_lane ? "Yes" : "No"}
                    </p>
                    {#if way.is_bus_lane}
                        <div
                            class="absolute bottom-0 left-0 right-0 h-[3px] rounded-b-xl"
                            style="background-color: {COLOR_TEAL}"
                        ></div>
                    {/if}
                </div>

                <!-- Lanes/Direction Card -->
                <div
                    class="p-3 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 flex flex-col justify-between shadow-sm overflow-hidden relative"
                >
                    {#if true}
                        {@const lanesDir = way.n_lanes_direction ?? 0}
                        {@const lanesCensus =
                            geoData.metadata.data_census.lanes}
                        {@const lanesColor = lanesCensus
                            ? getColorFromGradient(
                                  lanesDir,
                                  lanesCensus.min,
                                  lanesCensus.max,
                                  COLOR_GRADIENT,
                              )
                            : null}
                        <p
                            class="text-[10px] font-bold uppercase text-muted-foreground mb-1"
                        >
                            Lanes/Dir
                        </p>
                        <p class="text-lg font-bold">
                            {lanesDir || "N/A"}
                        </p>
                        {#if lanesColor}
                            <div
                                class="absolute bottom-0 left-0 right-0 h-[3px] rounded-b-xl"
                                style="background-color: {lanesColor}"
                            ></div>
                        {/if}
                    {/if}
                </div>

                <!-- Average Speed Card -->
                {#if way.speed_avg}
                    <div
                        class="p-3 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 flex flex-col justify-between shadow-sm overflow-hidden relative"
                    >
                        {#if true}
                            {@const speed = way.speed_avg}
                            {@const speedCensus =
                                geoData.metadata.data_census.speed_avg}
                            {@const speedColor = speedCensus
                                ? getColorFromGradient(
                                      speed,
                                      speedCensus.min,
                                      speedCensus.max,
                                      COLOR_GRADIENT_RED.slice().reverse(),
                                  )
                                : null}
                            <p
                                class="text-[10px] font-bold uppercase text-muted-foreground mb-1"
                            >
                                Avg Speed
                            </p>
                            <p class="text-lg font-bold">
                                {speed.toFixed(1)}
                                <span class="text-[10px] font-normal">km/h</span
                                >
                            </p>
                            {#if speedColor}
                                <div
                                    class="absolute bottom-0 left-0 right-0 h-[3px] rounded-b-xl"
                                    style="background-color: {speedColor}"
                                ></div>
                            {/if}
                        {/if}
                    </div>
                {/if}

                <!-- Total Lanes Card -->
                <div
                    class="p-2.5 bg-transparent rounded-lg border border-border/40 flex flex-col justify-between"
                >
                    <p
                        class="text-[9px] uppercase text-muted-foreground/70 mb-1"
                    >
                        Total Lanes
                    </p>
                    <p class="text-xs font-medium text-muted-foreground">
                        <span class="text-foreground"
                            >{way.n_lanes ?? "N/A"}</span
                        >
                        <span class="text-[9px]"
                            >({way.n_lanes_circulation ?? 0} circulation + {way.n_lanes_parking ??
                                0} parking)</span
                        >
                    </p>
                </div>

                <!-- Directions Card -->
                <div
                    class="p-2.5 bg-transparent rounded-lg border border-border/40 flex flex-col justify-between"
                >
                    <p
                        class="text-[9px] uppercase text-muted-foreground/70 mb-1"
                    >
                        Nr Directions
                    </p>
                    <p class="text-xs font-medium text-foreground">{way.n_directions ?? "N/A"}</p>
                </div>

                <!-- Extension Card -->
                <div
                    class="p-2.5 bg-transparent rounded-lg border border-border/40 flex flex-col justify-between"
                >
                    <p
                        class="text-[9px] uppercase text-muted-foreground/70 mb-1"
                    >
                        Extension
                    </p>
                    <p class="text-xs font-medium text-foreground">
                        {way.length_m.toFixed(1)}
                        <span class="text-[9px] text-muted-foreground">meters</span>
                    </p>
                </div>

                <!-- Speed count -->
                <div
                    class="p-2.5 bg-transparent rounded-lg border border-border/40 flex flex-col justify-between"
                >
                    <p
                        class="text-[9px] uppercase text-muted-foreground/70 mb-1"
                    >
                        Speed count
                    </p>
                    <p class="text-xs font-medium text-foreground">
                        {way.speed_count ?? 0}
                        <span class="text-[9px] text-muted-foreground">measurements</span
                        >
                    </p>
                </div>
            </div>

            {#if way.shapes && way.shapes.length > 0}
                <section class="space-y-3">
                    <h5 class="text-sm font-bold border-b pb-1">
                        Associated Routes
                    </h5>
                    <div class="flex flex-wrap gap-2">
                        {#each way.shapes as shape_id}
                            {@const route = geoData.shapes[shape_id]}
                            {@const routeColor = route?.route_color
                                ? `${route.route_color}`
                                : null}
                            <Tooltip.Provider delayDuration={0}>
                                <Tooltip.Root>
                                    <Tooltip.Trigger>
                                        {#snippet child({ props })}
                                            <button
                                                {...props}
                                                onclick={() => {
                                                    selected_shape_id =
                                                        shape_id;
                                                    selectedWayId = undefined;
                                                }}
                                                class="px-2 py-1 text-[10px] font-bold rounded border cursor-pointer hover:brightness-90 transition-all text-left"
                                                style={routeColor
                                                    ? `background-color: ${routeColor}22; border-color: ${routeColor}44; color: ${routeColor};`
                                                    : ""}
                                            >
                                                {route?.route_short_name ||
                                                    shape_id}
                                            </button>
                                        {/snippet}
                                    </Tooltip.Trigger>
                                    <Tooltip.Content class="z-[1100]">
                                        <p>
                                            {route?.route_short_name}: {route?.route_long_name}
                                            ({route?.direction_id
                                                ? "DESC"
                                                : "ASC"})
                                        </p>
                                    </Tooltip.Content>
                                </Tooltip.Root>
                            </Tooltip.Provider>
                        {/each}
                    </div>
                </section>
            {/if}

            <section
                class="space-y-3 p-4 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50"
            >
                <h5 class="text-sm font-bold flex items-center gap-2">
                    <i class="fas fa-chart-bar text-primary/70"></i>
                    24h Transit Frequency
                </h5>
                <div
                    class="flex items-end gap-[2px] h-24 pt-2 border-l border-b border-muted-foreground/30 px-1"
                >
                    {#each Array(24) as _, i}
                        {@const freq = way.hour_frequency?.[i] || 0}
                        {@const maxFreq =
                            Math.max(
                                ...(Object.values(
                                    way.hour_frequency || { 0: 1 },
                                ) as number[]),
                            ) || 1}
                        {@const height = Math.max((freq / maxFreq) * 100, 2)}
                        {@const hourFreqCensus =
                            geoData.metadata.data_census.frequency_hour[i]}
                        {@const barColor = hourFreqCensus
                            ? getColorFromGradient(
                                  freq,
                                  hourFreqCensus.min,
                                  hourFreqCensus.max,
                                  COLOR_GRADIENT,
                              )
                            : "var(--primary)"}
                        <div
                            class="flex-1 transition-colors rounded-t-[1px] relative group"
                            style="height: {height}%; background-color: {barColor}88;"
                            title="{i}:00 - {freq} buses"
                        >
                            <div
                                class="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 px-1.5 py-0.5 bg-foreground text-background text-[10px] rounded opacity-0 group-hover:opacity-100 pointer-events-none whitespace-nowrap z-20"
                            >
                                {i}:00: {freq} buses
                            </div>
                        </div>
                    {/each}
                </div>
                <div
                    class="flex justify-between text-[9px] text-muted-foreground font-mono uppercase tracking-tighter mt-1"
                >
                    <span>0h</span>
                    <span>6h</span>
                    <span>12h</span>
                    <span>18h</span>
                    <span>23h</span>
                </div>
            </section>
        </div>
    </div>
{/if}
