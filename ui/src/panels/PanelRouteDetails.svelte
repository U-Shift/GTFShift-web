<script lang="ts">
    import { Button } from "$lib/components/ui/button/index.js";
    import { untrack } from "svelte";
    import type { GeoPrioritization } from "../types/GeoPrioritization";

    let {
        selected_shape_id = $bindable(),
        geoData,
        selectedWayId,
    }: {
        selected_shape_id: string;
        geoData: GeoPrioritization | null;
        selectedWayId: string | undefined;
    } = $props();
</script>

{#if selected_shape_id && selected_shape_id !== "all" && geoData && !selectedWayId}
    {@const shape = geoData.shapes[selected_shape_id]}
    {@const shapeColor = shape?.route_color ?? "var(--primary)"}
    {@const shapeWayIds = Object.entries(geoData.wayData)
        .filter(([, wd]: [string, any]) =>
            wd?.shapes?.includes(selected_shape_id),
        )
        .map(([id]) => id)}
    {@const shapeWays = shapeWayIds
        .map((id) => geoData!.wayData[id])
        .filter(Boolean)}
    {@const scheduleEntries = shape?.schedule
        ? Object.entries(shape.schedule).map(([h, v]) => ({
              hour: parseInt(h),
              count: v as number,
          }))
        : []}
    {@const maxSchedule =
        scheduleEntries.length > 0
            ? Math.max(...scheduleEntries.map((e) => e.count))
            : 1}
    <div
        id="route-details-panel"
        class="absolute top-4 left-4 right-4 sm:left-auto sm:right-4 z-[1010] flex flex-col w-[calc(100vw-2rem)] sm:w-[380px] h-fit max-h-[calc(100vh-2rem)] rounded-xl bg-background/95 backdrop-blur shadow-lg border p-5 overflow-y-auto gap-4"
    >
        <!-- Header -->
        <div class="flex items-start justify-between gap-2">
            <div>
                <div class="flex items-center gap-2 mb-0.5">
                    <div
                        class="w-3 h-3 rounded-full shrink-0"
                        style="background-color: {shapeColor}"
                    ></div>
                    <span
                        class="text-xs font-bold uppercase tracking-wider text-muted-foreground"
                        >Route {shape?.route_short_name}</span
                    >
                </div>
                <h3 class="text-base font-bold text-foreground leading-snug">
                    {shape?.route_long_name}
                </h3>
                <p class="text-[10px] text-muted-foreground font-mono mt-1">
                    route_id: {shape?.route_id || "N/A"} • shape_id: {selected_shape_id}
                </p>
                <p class="text-xs text-muted-foreground mt-0.5">
                    {shape?.direction_id ? "↙ Descending" : "↗ Ascending"} · {shapeWayIds.length}
                    road segments
                </p>
            </div>
            <Button
                variant="ghost"
                size="icon"
                onclick={() => (selected_shape_id = "all")}
                class="rounded-full shrink-0"
            >
                <i class="fas fa-times"></i>
            </Button>
        </div>

        <!-- 24h Frequency Chart -->
        {#if scheduleEntries.length > 0}
            <section
                class="space-y-2 p-3 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50"
            >
                <h5
                    class="text-xs font-bold flex items-center gap-1.5 uppercase tracking-wider text-muted-foreground"
                >
                    <i class="fas fa-chart-bar" style="color: {shapeColor}"></i>
                    Scheduled Departures / Hour
                </h5>
                <div
                    class="flex items-end gap-[2px] h-20 border-l border-b border-muted-foreground/30 px-1 pt-2"
                >
                    {#each Array(24) as _, i}
                        {@const entry = scheduleEntries.find(
                            (e) => e.hour === i,
                        )}
                        {@const count = entry?.count ?? 0}
                        {@const height =
                            count > 0
                                ? Math.max((count / maxSchedule) * 100, 8)
                                : 0}
                        <div
                            class="flex-1 rounded-t-[1px] relative group transition-colors"
                            style="height: {height}%; background-color: {count >
                            0
                                ? shapeColor + 'bb'
                                : 'transparent'};"
                            title="{i}:00 – {count} dep."
                        >
                            {#if count > 0}
                                <div
                                    class="absolute bottom-full left-1/2 -translate-x-1/2 mb-1 px-1.5 py-0.5 bg-foreground text-background text-[10px] rounded opacity-0 group-hover:opacity-100 pointer-events-none whitespace-nowrap z-20"
                                >
                                    {i}:00: {count}
                                </div>
                            {/if}
                        </div>
                    {/each}
                </div>
                <div
                    class="flex justify-between text-[9px] text-muted-foreground font-mono uppercase tracking-tighter"
                >
                    <span>0h</span><span>6h</span><span>12h</span><span
                        >18h</span
                    ><span>23h</span>
                </div>
            </section>
        {/if}

        <!-- Aggregated Indicators Grid -->
        {#if shapeWays.length > 0}
            <section class="space-y-2">
                <h5
                    class="text-xs font-bold uppercase tracking-wider text-muted-foreground"
                >
                    Road Segment Indicators
                </h5>
                <div class="grid grid-cols-3 gap-2">
                    <!-- Speed indicators -->
                    {#if shape.stats?.speed_min && shape.stats?.speed_max && shape.stats?.speed_avg}
                        <div
                            class="p-2.5 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 text-center"
                        >
                            <p
                                class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                            >
                                Min Speed
                            </p>
                            <p class="text-sm font-bold">
                                {shape.stats.speed_min}<span
                                    class="text-[9px] font-normal"
                                >
                                    km/h</span
                                >
                            </p>
                        </div>
                        <div
                            class="p-2.5 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 text-center"
                        >
                            <p
                                class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                            >
                                Avg Speed
                            </p>
                            <p class="text-sm font-bold">
                                {shape.stats.speed_avg}<span
                                    class="text-[9px] font-normal"
                                >
                                    km/h</span
                                >
                            </p>
                        </div>
                        <div
                            class="p-2.5 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 text-center"
                        >
                            <p
                                class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                            >
                                Max Speed
                            </p>
                            <p class="text-sm font-bold">
                                {shape.stats.speed_max}<span
                                    class="text-[9px] font-normal"
                                >
                                    km/h</span
                                >
                            </p>
                        </div>
                    {/if}

                    <!-- Lanes indicators -->
                    <div
                        class="p-2.5 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 text-center"
                    >
                        <p
                            class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                        >
                            Min Lanes/Dir
                        </p>
                        <p class="text-sm font-bold">
                            {shape.stats.n_lanes_min}
                        </p>
                    </div>
                    <div
                        class="p-2.5 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 text-center"
                    >
                        <p
                            class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                        >
                            Avg Lanes/Dir
                        </p>
                        <p class="text-sm font-bold">
                            {shape.stats.n_lanes_avg}
                        </p>
                    </div>
                    <div
                        class="p-2.5 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 text-center"
                    >
                        <p
                            class="text-[9px] font-bold uppercase text-muted-foreground mb-1"
                        >
                            Max Lanes/Dir
                        </p>
                        <p class="text-sm font-bold">
                            {shape.stats.n_lanes_max}
                        </p>
                    </div>
                </div>

                <!-- Extension bars -->
                <div class="space-y-2 mt-1">
                    <div
                        class="p-3 bg-zinc-50/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 space-y-2"
                    >
                        <p
                            class="text-[9px] font-bold uppercase text-muted-foreground"
                        >
                            Route Extension
                        </p>
                        <div class="space-y-1.5">
                            <div>
                                <div
                                    class="flex justify-between text-[10px] mb-0.5"
                                >
                                    <span class="text-muted-foreground"
                                        >With bus lane</span
                                    >
                                    <span class="font-semibold"
                                        >{(
                                            shape.stats.extension_bus_lane /
                                            1000
                                        ).toFixed(2)} km ({shape.stats
                                            .extension > 0
                                            ? (
                                                  (shape.stats
                                                      .extension_bus_lane /
                                                      shape.stats.extension) *
                                                  100
                                              ).toFixed(0)
                                            : 0}%)</span
                                    >
                                </div>
                                <div
                                    class="h-2 rounded-full bg-muted overflow-hidden"
                                >
                                    <div
                                        class="h-full rounded-full bg-teal-500"
                                        style="width: {shape.stats.extension > 0
                                            ? (shape.stats.extension_bus_lane /
                                                  shape.stats.extension) *
                                              100
                                            : 0}%"
                                    ></div>
                                </div>
                            </div>
                            <div>
                                <div
                                    class="flex justify-between text-[10px] mb-0.5"
                                >
                                    <span class="text-muted-foreground"
                                        >Without bus lane</span
                                    >
                                    <span class="font-semibold"
                                        >{(
                                            (shape.stats.extension -
                                                shape.stats
                                                    .extension_bus_lane) /
                                            1000
                                        ).toFixed(2)} km ({shape.stats
                                            .extension > 0
                                            ? (
                                                  ((shape.stats.extension -
                                                      shape.stats
                                                          .extension_bus_lane) /
                                                      shape.stats.extension) *
                                                  100
                                              ).toFixed(0)
                                            : 0}%)</span
                                    >
                                </div>
                                <div
                                    class="h-2 rounded-full bg-muted overflow-hidden"
                                >
                                    <div
                                        class="h-full rounded-full bg-orange-400"
                                        style="width: {shape.stats.extension > 0
                                            ? ((shape.stats.extension -
                                                  shape.stats
                                                      .extension_bus_lane) /
                                                  shape.stats.extension) *
                                              100
                                            : 0}%"
                                    ></div>
                                </div>
                            </div>
                            <div
                                class="flex justify-between text-[10px] pt-1 border-t border-border/50"
                            >
                                <span
                                    class="text-muted-foreground font-semibold"
                                    >Total</span
                                >
                                <span class="font-bold"
                                    >{(shape.stats.extension / 1000).toFixed(2)}
                                    km</span
                                >
                            </div>
                        </div>
                    </div>
                </div>
            </section>
        {/if}
    </div>
{/if}
