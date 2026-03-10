<script lang="ts">
    import { untrack } from "svelte";
    import type { Feature } from "geojson";
    import { TableHandler, Datatable, ThSort } from "@vincjo/datatables";
    import * as Tooltip from "$lib/components/ui/tooltip/index.js";
    import type { GeoPrioritization } from "../types/GeoPrioritization";
    import { Button } from "$lib/components/ui/button/index.js";

    let {
        open = $bindable(false),
        geoData,
        hour,
        rt_data,
        onWaySelect = (wayId) => {},
    }: {
        open: boolean;
        geoData: GeoPrioritization;
        hour: number;
        rt_data: boolean;
        onWaySelect?: (wayId: string) => void;
    } = $props();

    let data_filtered = $state<Feature[]>([]);
    let table = $state<TableHandler<any> | null>(null);

    $effect(() => {
        if (geoData) {
            data_filtered = Object.entries(geoData.wayData)
                .filter(([_, wayData]: [string, any]) => {
                    return (
                        wayData.hour_frequency &&
                        wayData.hour_frequency[hour] !== undefined
                    );
                })
                .map(([wayId, wayData]: [string, any]) => {
                    return {
                        properties: {
                            way_osm_id: wayId,
                            ...wayData,
                            frequency: wayData.hour_frequency[hour],
                            route_names: wayData.routes?.join(", ") || "",
                        },
                    } as unknown as Feature;
                });
        }

        untrack(() => {
            if (data_filtered) {
                if (!table) {
                    table = new TableHandler([] as Feature[], {
                        rowsPerPage: 20,
                    });
                }
                table.setRows([...data_filtered]);
            }
        });
    });
</script>

{#if open}
    <!-- Backdrop -->
    <div
        class="fixed inset-0 z-[999] bg-black/20 backdrop-blur-[1px]"
        onclick={() => (open = false)}
        role="presentation"
    ></div>

    <!-- Panel: same margins as the left sidebar (1rem all around, starts after 350px sidebar) -->
    <div
        class="fixed z-[1000] flex flex-col bg-background/95 backdrop-blur border rounded-xl shadow-xl overflow-hidden h-fit max-h-[calc(100vh-2rem)]"
        style="top: 1rem; left: calc(1rem + 350px + 0.5rem); right: 1rem;"
    >
        <!-- Header -->
        <div
            class="flex items-center justify-between px-5 py-4 border-b shrink-0"
        >
            <h2 class="text-lg font-bold flex items-center gap-2">
                <i class="fas fa-table text-primary"></i>
                Attribute table
                <span class="text-muted-foreground font-normal text-sm"
                    >at {hour}:00</span
                >
            </h2>
            <Button
                variant="ghost"
                size="sm"
                onclick={() => (open = false)}
                class="h-8 w-8 p-0"
            >
                <i class="fas fa-times"></i>
            </Button>
        </div>

        <!-- Table -->
        <div class="flex-1 overflow-auto px-4 py-3">
            {#if table}
                <div class="border rounded-md">
                    <Datatable basic {table}>
                        <table class="w-full text-sm">
                            <thead class="bg-muted/50 border-b sticky top-0">
                                <tr>
                                    <ThSort
                                        {table}
                                        field={(r) => r.properties.way_osm_id}
                                        class="px-4 py-2 text-left font-bold"
                                        >OSM ID</ThSort
                                    >
                                    <ThSort
                                        {table}
                                        field={(r) => r.properties.frequency}
                                        class="px-4 py-2 text-left font-bold"
                                        >Frequency <small>(Buses/h)</small
                                        ></ThSort
                                    >
                                    <ThSort
                                        {table}
                                        field={(r) => r.properties.is_bus_lane}
                                        class="px-4 py-2 text-left font-bold"
                                        >Bus Lane</ThSort
                                    >
                                    <ThSort
                                        {table}
                                        field={(r) => r.properties.n_lanes}
                                        class="px-4 py-2 text-left font-bold"
                                        >Nr lanes <small
                                            >(circulation + parking)</small
                                        ></ThSort
                                    >
                                    <ThSort
                                        {table}
                                        field={(r) => r.properties.n_directions}
                                        class="px-4 py-2 text-left font-bold"
                                        >Nr directions</ThSort
                                    >
                                    <ThSort
                                        {table}
                                        field={(r) =>
                                            r.properties.n_lanes_direction}
                                        class="px-4 py-2 text-left font-bold"
                                        >Nr lanes/dir</ThSort
                                    >
                                    {#if rt_data}
                                        <ThSort
                                            {table}
                                            field={(r) =>
                                                r.properties.speed_avg}
                                            class="px-4 py-2 text-left font-bold"
                                            >Avg speed <small>(km/h)</small
                                            ></ThSort
                                        >
                                    {/if}
                                    <ThSort
                                        {table}
                                        field={(r) => r.properties.length_m}
                                        class="px-4 py-2 text-left font-bold"
                                        >Length <small>(m)</small></ThSort
                                    >
                                    <ThSort
                                        {table}
                                        field={(r) => r.properties.route_names}
                                        class="px-4 py-2 text-left font-bold"
                                        >Routes</ThSort
                                    >
                                </tr>
                            </thead>
                            <tbody class="divide-y">
                                {#each table.rows as row}
                                    <tr
                                        class="hover:bg-muted/30 transition-colors"
                                    >
                                        <td class="px-4 py-2">
                                            <Tooltip.Provider delayDuration={0}>
                                                <Tooltip.Root>
                                                    <Tooltip.Trigger>
                                                        {#snippet child({
                                                            props,
                                                        })}
                                                            <button
                                                                {...props}
                                                                onclick={() => {
                                                                    open = false;
                                                                    if (
                                                                        onWaySelect
                                                                    )
                                                                        onWaySelect(
                                                                            row
                                                                                .properties
                                                                                .way_osm_id,
                                                                        );
                                                                }}
                                                                class="text-primary hover:underline font-mono cursor-pointer"
                                                            >
                                                                {row.properties
                                                                    .way_osm_id}
                                                            </button>
                                                        {/snippet}
                                                    </Tooltip.Trigger>
                                                    <Tooltip.Content
                                                        class="z-[1100]"
                                                        >Show on map</Tooltip.Content
                                                    >
                                                </Tooltip.Root>
                                            </Tooltip.Provider>
                                        </td>
                                        <td class="px-4 py-2"
                                            >{row.properties.frequency}</td
                                        >
                                        <td class="px-4 py-2"
                                            >{row.properties.is_bus_lane
                                                ? "Yes"
                                                : "No"}</td
                                        >
                                        <td
                                            class="px-4 py-2 text-muted-foreground"
                                        >
                                            {row.properties.n_lanes}
                                            <span class="text-[10px]"
                                                >({row.properties
                                                    .n_lanes_circulation}
                                                + {row.properties
                                                    .n_lanes_parking})</span
                                            >
                                        </td>
                                        <td class="px-4 py-2"
                                            >{row.properties.n_directions}</td
                                        >
                                        <td class="px-4 py-2"
                                            >{row.properties
                                                .n_lanes_direction}</td
                                        >
                                        {#if rt_data}
                                            <td class="px-4 py-2"
                                                >{row.properties.speed_avg?.toFixed(
                                                    1,
                                                ) || "-"}</td
                                            >
                                        {/if}
                                        <td class="px-4 py-2"
                                            >{row.properties.length_m.toFixed(
                                                1,
                                            )}</td
                                        >
                                        <td
                                            class="px-4 py-2 truncate max-w-[200px]"
                                            title={row.properties.route_names}
                                        >
                                            {row.properties.route_names}
                                        </td>
                                    </tr>
                                {/each}
                            </tbody>
                        </table>
                    </Datatable>
                </div>
            {/if}
        </div>
    </div>
{/if}

<style>
    :global(.svelte-simple-datatable button) {
        white-space: nowrap !important;
        font-weight: bold;
    }
</style>
