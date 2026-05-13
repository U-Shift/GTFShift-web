<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import type { Feature } from "geojson";
    import type { GeoPrioritization } from "./types/GeoPrioritization";
    import type { DataRegion, RegionLayer } from "./types/DataRegion";

    import ModalAbout from "./modals/ModalAbout.svelte";
    import LayerBusLanePrioritization from "./layers/LayerBusLanePrioritization.svelte";
    import LayerBusLanes from "./layers/LayerBusLanes.svelte";
    import LayerTransitFrequency from "./layers/LayerTransitFrequency.svelte";
    import LayerNumberOfLanes from "./layers/LayerNumberOfLanes.svelte";
    import LayerRTSpeed from "./layers/LayerRTSpeed.svelte";
    import LayerBoundaries from "./layers/LayerBoundaries.svelte";
    import DataCensusTable from "./components/DataCensusTable.svelte";
    import ModalData from "./modals/ModalData.svelte";
    import ModalDetails from "./modals/ModalDetails.svelte";
    import PanelRouteDetails from "./panels/PanelRouteDetails.svelte";
    import PanelWayDetails from "./panels/PanelWayDetails.svelte";

    import { Button } from "$lib/components/ui/button/index.js";
    import { Switch } from "$lib/components/ui/switch/index.js";
    import { Input } from "$lib/components/ui/input/index.js";
    import * as Accordion from "$lib/components/ui/accordion/index.js";
    import * as Select from "$lib/components/ui/select/index.js";
    import * as Popover from "$lib/components/ui/popover/index.js";
    import * as Command from "$lib/components/ui/command/index.js";
    import * as Tooltip from "$lib/components/ui/tooltip/index.js";
    import Check from "@lucide/svelte/icons/check";
    import ChevronsUpDown from "@lucide/svelte/icons/chevrons-up-down";

    import {
        DB_REGIONS,
        COLOR_YELLOW,
        COLOR_TEAL,
        COLOR_RED,
        COLOR_GRADIENT,
        COLOR_GRADIENT_RED,
    } from "./data";
    import Spinner from "$lib/components/ui/spinner/spinner.svelte";

    // Map
    let { map, light_mode = $bindable() }: { map: L.Map; light_mode: boolean } =
        $props();
    let geoData: GeoPrioritization | null = $state(null);

    // User feedback
    let loading: string | undefined = $state(undefined);

    // Dashboard state
    enum DisplayOptions {
        PRIORITIZATION,
        BUS_LANES,
        FREQUENCY,
        N_LANES,
        RT_SPEED,
    }

    let region: DataRegion | undefined = $state(undefined);
    let selected_layer: RegionLayer | undefined = $state(undefined);
    let selected_layer_id: string = $state("");
    let boundaryGeoJSON: any = $state(null);
    let show_boundaries: boolean = $state(true);
    let regionSearchQuery: string = $state("");

    const filteredRegions = $derived.by(() => {
        const query = regionSearchQuery.trim().toLowerCase();
        if (!query) return DB_REGIONS;
        return DB_REGIONS.filter(
            (r: DataRegion) =>
                r.name.toLowerCase().includes(query) ||
                r.region.toLowerCase().includes(query),
        );
    });

    let active_layer: DisplayOptions | undefined = $state(undefined);
    let open_accordion: string | undefined = $state(undefined);
    let selected_shape_id: string = $state("all");
    let route_select_open: boolean = $state(false);
    let display_rt: boolean = $state(false); // true if region has rt-data (optional)

    let criteria_hour: number = $state(8);
    let criteria_bus_frequency: number = $state(0);
    let criteria_n_lanes_direction: number = $state(2);
    let criteria_avg_speed: number | undefined = $state(undefined);
    let criteria_bus_frequency_enabled: boolean = $state(true);
    let criteria_n_lanes_direction_enabled: boolean = $state(true);
    let criteria_avg_speed_enabled: boolean = $state(true);

    let action_hide_form: boolean = $state(false);
    let action_modal_about_open: boolean = $state(false);
    let action_modal_data_open: boolean = $state(false);
    let action_modal_details_open: boolean = $state(false);
    let any_modal_open: boolean = $derived(
        action_modal_about_open ||
            action_modal_data_open ||
            action_modal_details_open,
    );

    let selectedWayId: string | undefined = $state(undefined);

    // Clear way selection when a modal is opened
    $effect(() => {
        if (
            action_modal_about_open ||
            action_modal_data_open ||
            action_modal_details_open
        ) {
            untrack(() => {
                selectedWayId = undefined;
            });
        }
    });

    // Clear way selection when clicking on empty map area
    $effect(() => {
        if (!map) return;
        const onClick = () => {
            selectedWayId = undefined;
        };
        map.on("click", onClick);
        return () => {
            map.off("click", onClick);
        };
    });

    // Action handlers
    const handleLayerCreate = (layer: L.Layer) => {};

    const handleLayerChange = async (layerId: string) => {
        if (!region || !layerId) return;

        const targetLayer = region.layers.find((l) => l.id === layerId);
        if (!targetLayer) return;

        selected_layer = targetLayer;
        selected_layer_id = targetLayer.id;

        active_layer = undefined;
        open_accordion = undefined;
        selected_shape_id = "all";
        geoData = null;
        loading = "data for " + region.name + " (" + selected_layer.name + ")";

        try {
            // Fetch and load new data model components
            const fetchPromises: Promise<Response>[] = [
                fetch(selected_layer.files.ways),
                fetch(selected_layer.files.way_data),
                fetch(selected_layer.files.metadata),
                fetch(selected_layer.files.route_data),
                fetch(selected_layer.files.shape_data),
            ];

            if (selected_layer.files.boundaries) {
                fetchPromises.push(fetch(selected_layer.files.boundaries));
            }

            const results = await Promise.all(fetchPromises);

            const ways = await results[0].json();
            const wayData = await results[1].json();
            const metadata = await results[2].json();
            const routeData = await results[3].json();
            const shapeData = await results[4].json();

            if (selected_layer.files.boundaries && results[5]) {
                boundaryGeoJSON = await results[5].json();
            } else {
                boundaryGeoJSON = null;
            }

            geoData = {
                features: ways.features,
                wayData: wayData,
                metadata: metadata,
                routes: routeData,
                shapes: shapeData,
            } as GeoPrioritization;
            console.log("geoData", geoData);

            display_rt = Object.values(geoData.wayData).some(
                (data: any) =>
                    data.speed_avg !== undefined && data.speed_avg !== null,
            );

            // Set criteria base values
            criteria_hour = 8;
            criteria_n_lanes_direction = 2;
            criteria_bus_frequency =
                geoData.metadata.data_census.frequency.median;
            criteria_avg_speed = Math.floor(
                geoData.metadata.data_census.speed_avg_length?.median ?? 0,
            );
            criteria_bus_frequency_enabled = true;
            criteria_n_lanes_direction_enabled = true;
            criteria_avg_speed_enabled = display_rt;
            active_layer = DisplayOptions.PRIORITIZATION;
            open_accordion = DisplayOptions.PRIORITIZATION.toString();

            console.log("Loaded GeoJSON for layer:", selected_layer.id);
        } catch (error) {
            console.error("Error loading GeoJSON:", error);
        } finally {
            loading = undefined;
        }
    };

    const handleRegionChange = async (regionId: string) => {
        if (!regionId) return;

        action_modal_about_open = false;
        action_modal_data_open = false;
        action_modal_details_open = false;

        region = DB_REGIONS.find((r: DataRegion) => r.id === regionId);
        if (!region || !map) return;

        selected_layer = undefined;
        selected_layer_id = "";

        if (region.layers && region.layers.length === 1) {
            await handleLayerChange(region.layers[0].id);
        }
    };

    // Effect to zoom to selected route
    $effect(() => {
        if (
            !selected_shape_id ||
            selected_shape_id === "all" ||
            !map ||
            !geoData
        )
            return;

        console.log("Filtering by shape:", selected_shape_id);

        // Deselect prioritization filters when a specific route is selected
        if (selected_shape_id && selected_shape_id !== "all") {
            untrack(() => {
                criteria_bus_frequency_enabled = false;
                criteria_n_lanes_direction_enabled = false;
                if (display_rt) criteria_avg_speed_enabled = false;
            });
        } else if (selected_shape_id == "all") {
            untrack(() => {
                criteria_bus_frequency_enabled = true;
                criteria_n_lanes_direction_enabled = true;
                if (display_rt) criteria_avg_speed_enabled = true;
            });
        }
    });

    const routeOptions = $derived.by(() => {
        const data = geoData;
        if (!data || !data.shapes) return [];
        return Object.keys(data.shapes)
            .map((s: string) => ({
                id: s,
                label: `${data.shapes[s].route_short_name}: ${data.shapes[s].route_long_name} (${data.shapes[s].direction_id ? "DESC" : "ASC"})`,
                short_name: data.shapes[s].route_short_name,
                color: data.shapes[s].route_color,
            }))
            .sort((a, b) =>
                a.label.localeCompare(b.label, undefined, {
                    numeric: true,
                }),
            );
    });
</script>

<svelte:head>
    <script
        src="https://kit.fontawesome.com/17e93d90c5.js"
        crossorigin="anonymous"
    ></script>
</svelte:head>

<div
    id="controls-panel"
    class="absolute top-4 left-4 z-[1010] flex flex-col items-start w-[calc(100vw-2rem)] sm:w-[350px] max-h-[70vh] sm:max-h-[calc(100vh-2rem)] rounded-xl bg-background/95 backdrop-blur shadow-lg border p-4 overflow-y-auto h-fit"
    style={"background-image: url('./static/logo/background_blur_transparent.png'); background-size: auto 7vw; background-position: top right; background-repeat: no-repeat;"}
>
    <!-- Title -->
    <div class="w-full text-left mb-4">
        <div class="flex items-center gap-2 mb-1">
            <h3 class="text-xl font-bold text-primary m-0">GTFShift</h3>
            <Tooltip.Provider delayDuration={0}>
                <Tooltip.Root>
                    <Tooltip.Trigger>
                        {#snippet child({ props })}
                            <button
                                {...props}
                                class="text-muted-foreground hover:text-foreground cursor-pointer"
                                onclick={(e) => {
                                    e.preventDefault();
                                    action_modal_data_open = false;
                                    action_modal_details_open = false;
                                    action_modal_about_open =
                                        !action_modal_about_open;
                                }}
                                aria-label="About"
                            >
                                <i class="fas fa-info-circle"></i>
                            </button>
                        {/snippet}
                    </Tooltip.Trigger>
                    <Tooltip.Content class="z-[1100]">About</Tooltip.Content>
                </Tooltip.Root>
            </Tooltip.Provider>
        </div>
        <p class="text-sm text-muted-foreground">
            Bus lane prioritization tool
        </p>
        {#if loading}
            <p
                class="flex items-center gap-2 text-xs text-muted-foreground animate-pulse mt-2"
            >
                <Spinner /> Loading {loading}...
            </p>
        {/if}
    </div>

    <!-- Form 1: Select region -->
    {#if region === undefined}
        <div class="w-full text-left mb-4">
            <h5 class="text-sm font-semibold text-primary mb-1">Data source</h5>
            <p class="text-xs text-muted-foreground mb-2">
                Select the region you want to analyse
            </p>

            <!-- Search bar -->
            <div class="relative w-full mb-3 mt-2">
                <i
                    class="fas fa-search absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground text-xs pointer-events-none"
                ></i>
                <Input
                    type="text"
                    placeholder="Search region by name or location..."
                    class="pl-9 pr-8 py-1 h-9 text-xs bg-background/50 focus-visible:ring-1 focus-visible:ring-primary/50"
                    bind:value={regionSearchQuery}
                />
                {#if regionSearchQuery}
                    <button
                        type="button"
                        class="absolute right-2.5 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground p-0.5 rounded-full hover:bg-muted/50 transition-colors cursor-pointer"
                        onclick={() => (regionSearchQuery = "")}
                        aria-label="Clear search"
                    >
                        <i class="fas fa-times text-[10px]"></i>
                    </button>
                {/if}
            </div>

            <div class="flex flex-col gap-2 mt-3">
                {#each filteredRegions as r}
                    <button
                        class="group relative w-full text-left rounded-xl border border-border bg-background transition-all duration-200 p-3 overflow-hidden disabled:opacity-50 disabled:cursor-not-allowed shadow-sm hover:shadow-md"
                        onclick={() => handleRegionChange(r.id)}
                        disabled={loading !== undefined}
                        style="cursor: pointer;"
                        onmouseenter={(e) => {
                            const el = e.currentTarget as HTMLElement;
                            el.style.borderColor = r.color ?? "";
                            el.style.backgroundColor = (r.color ?? "") + "0d";
                            el.querySelector<HTMLElement>(
                                ".region-icon",
                            )!.style.backgroundColor = (r.color ?? "") + "33";
                            el.querySelector<HTMLElement>(
                                ".region-chevron",
                            )!.style.color = r.color ?? "";
                            el.querySelector<HTMLElement>(
                                ".region-accent",
                            )!.style.transform = "scaleX(1)";
                        }}
                        onmouseleave={(e) => {
                            const el = e.currentTarget as HTMLElement;
                            el.style.borderColor = "";
                            el.style.backgroundColor = "";
                            el.querySelector<HTMLElement>(
                                ".region-icon",
                            )!.style.backgroundColor = "";
                            el.querySelector<HTMLElement>(
                                ".region-chevron",
                            )!.style.color = "";
                            el.querySelector<HTMLElement>(
                                ".region-accent",
                            )!.style.transform = "scaleX(0)";
                        }}
                    >
                        <div class="flex items-start gap-3">
                            <div
                                class="region-icon mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg transition-colors overflow-hidden"
                                style="background-color: {r.color}1a; color: {r.color};"
                            >
                                {#if r.logo}
                                    <img
                                        src={r.logo}
                                        alt={r.name}
                                        class="h-5 w-5 object-contain grayscale brightness-0 dark:invert"
                                    />
                                {:else}
                                    <i class="fas fa-map-location-dot text-sm"
                                    ></i>
                                {/if}
                            </div>
                            <div class="flex-1 min-w-0">
                                <p
                                    class="text-sm font-semibold text-foreground leading-tight truncate"
                                >
                                    {r.name}
                                </p>
                                <p class="text-xs text-muted-foreground mt-0.5">
                                    <i class="fas fa-map-marker-alt mr-1"></i>
                                    {r.region}
                                </p>
                                <p class="text-xs text-muted-foreground mt-0.5">
                                    <i class="fas fa-calendar-alt mr-1"
                                    ></i>{r.date}
                                </p>
                                {#if r.rt_data}
                                    <p
                                        class="text-xs text-muted-foreground mt-0.5"
                                    >
                                        <i class="fas fa-traffic-light mr-1"
                                        ></i> With traffic conditions
                                    </p>
                                {:else}
                                    <p
                                        class="text-xs text-muted-foreground mt-0.5"
                                    >
                                        <i class="fas fa-road mr-1"></i> Static analysis
                                    </p>
                                {/if}
                            </div>
                            <i
                                class="region-chevron fas fa-chevron-right text-xs text-muted-foreground transition-colors mt-1"
                            ></i>
                        </div>
                        <!-- Accent line at bottom on hover -->
                        <div
                            class="region-accent absolute bottom-0 left-0 right-0 h-[2px] transition-transform duration-200 origin-left rounded-b-xl"
                            style="background-color: {r.color}; transform: scaleX(0);"
                        ></div>
                    </button>
                {/each}

                {#if filteredRegions.length === 0}
                    <div
                        class="text-center py-6 border border-dashed rounded-xl bg-muted/20"
                    >
                        <i
                            class="fas fa-map-marked-alt text-muted-foreground text-xl mb-2 block opacity-50"
                        ></i>
                        <p class="text-xs font-semibold text-foreground">
                            No regions found
                        </p>
                        <p class="text-[10px] text-muted-foreground mt-0.5">
                            Try searching for a different name or location
                        </p>
                        <Button
                            variant="outline"
                            size="sm"
                            class="h-7 text-[10px] px-2.5 mt-3 gap-1 cursor-pointer"
                            onclick={() => (regionSearchQuery = "")}
                        >
                            <i class="fas fa-undo text-[9px]"></i> Reset Search
                        </Button>
                    </div>
                {/if}
            </div>
        </div>
    {/if}

    <!-- Form 1.5: Select Layer -->
    {#if region !== undefined && selected_layer === undefined && region.layers && region.layers.length > 1}
        <div class="w-full text-left mb-4">
            <div class="flex items-center gap-2 mb-3">
                {#if region.logo}
                    <img
                        src={region.logo}
                        alt={region.name}
                        class="h-6 w-6 object-contain"
                    />
                {/if}
                <h5 class="text-lg font-semibold text-primary mb-1">
                    {region.name}
                </h5>
            </div>
            <p class="text-xs text-muted-foreground mb-4">
                Select a dataset/layer to begin analysis:
            </p>

            <div class="flex flex-col gap-2 mt-3">
                {#each region.layers as layer}
                    <button
                        class="group relative w-full text-left rounded-xl border border-border bg-background transition-all duration-200 p-3 overflow-hidden shadow-sm hover:shadow-md cursor-pointer"
                        onclick={() => handleLayerChange(layer.id)}
                        disabled={loading !== undefined}
                        onmouseenter={(e) => {
                            const el = e.currentTarget as HTMLElement;
                            el.style.borderColor = region.color ?? "";
                            el.style.backgroundColor =
                                (region.color ?? "") + "0d";
                            el.querySelector<HTMLElement>(
                                ".layer-accent",
                            )!.style.transform = "scaleX(1)";
                        }}
                        onmouseleave={(e) => {
                            const el = e.currentTarget as HTMLElement;
                            el.style.borderColor = "";
                            el.style.backgroundColor = "";
                            el.querySelector<HTMLElement>(
                                ".layer-accent",
                            )!.style.transform = "scaleX(0)";
                        }}
                    >
                        <div class="flex items-start justify-between gap-3">
                            <div class="flex-1 min-w-0">
                                <p
                                    class="text-sm font-semibold text-foreground leading-tight truncate"
                                >
                                    {layer.name}
                                </p>
                                <p class="text-xs text-muted-foreground mt-1">
                                    <i class="fas fa-calendar-alt mr-1"></i>
                                    {layer.date}
                                </p>
                                {#if layer.rt_data}
                                    <p
                                        class="text-xs text-muted-foreground mt-0.5"
                                    >
                                        <i class="fas fa-traffic-light mr-1"
                                        ></i> With traffic conditions
                                    </p>
                                {:else}
                                    <p
                                        class="text-xs text-muted-foreground mt-0.5"
                                    >
                                        <i class="fas fa-road mr-1"></i> Static analysis
                                    </p>
                                {/if}
                            </div>
                            <i
                                class="fas fa-chevron-right text-xs text-muted-foreground mt-1 group-hover:text-primary transition-colors"
                            ></i>
                        </div>
                        <div
                            class="layer-accent absolute bottom-0 left-0 right-0 h-[2px] transition-transform duration-200 origin-left rounded-b-xl"
                            style="background-color: {region.color}; transform: scaleX(0);"
                        ></div>
                    </button>
                {/each}
            </div>

            <!-- Back button to regions -->
            <Button
                variant="outline"
                size="sm"
                onclick={() => {
                    region = undefined;
                    selected_layer = undefined;
                    selected_layer_id = "";
                }}
                disabled={loading !== undefined}
                class="w-full mt-4"
            >
                <i class="fa-solid fa-arrow-left mr-2"></i> Back to Regions
            </Button>
        </div>
    {/if}

    <!-- Form 2: Region display options -->
    {#if region !== undefined && geoData && !action_hide_form}
        <div class="w-full text-left flex-1" id="form">
            <div class="flex items-center gap-2">
                <img
                    src={region.logo}
                    alt={region.name}
                    class="h-5 w-5 object-contain"
                />
                <h5 class="text-lg font-semibold text-primary mb-1">
                    {region.name}
                </h5>
            </div>
            <div
                class="flex items-center gap-3 text-sm text-muted-foreground mb-4"
            >
                <p class="mr-auto">
                    <i class="fas fa-map-marker-alt mr-1"></i>
                    {region.region}<br />
                    <i class="fas fa-calendar-alt mr-1"></i>
                    {selected_layer?.date ?? region.date}
                </p>
                <Tooltip.Provider delayDuration={0}>
                    <Tooltip.Root>
                        <Tooltip.Trigger>
                            {#snippet child({ props })}
                                <button
                                    {...props}
                                    class="hover:text-foreground cursor-pointer"
                                    onclick={(e) => {
                                        e.preventDefault();
                                        action_modal_about_open = false;
                                        action_modal_details_open = false;
                                        action_modal_data_open =
                                            !action_modal_data_open;
                                    }}
                                    aria-label="Attribute table"
                                >
                                    <i class="fas fa-table"></i>
                                </button>
                            {/snippet}
                        </Tooltip.Trigger>
                        <Tooltip.Content class="z-[1100]"
                            >Attribute table</Tooltip.Content
                        >
                    </Tooltip.Root>
                </Tooltip.Provider>
                <Tooltip.Provider delayDuration={0}>
                    <Tooltip.Root>
                        <Tooltip.Trigger>
                            {#snippet child({ props })}
                                <button
                                    {...props}
                                    class="hover:text-foreground cursor-pointer"
                                    onclick={(e) => {
                                        e.preventDefault();
                                        action_modal_about_open = false;
                                        action_modal_data_open = false;
                                        action_modal_details_open =
                                            !action_modal_details_open;
                                    }}
                                    aria-label="Details"
                                >
                                    <i class="fas fa-code"></i>
                                </button>
                            {/snippet}
                        </Tooltip.Trigger>
                        <Tooltip.Content class="z-[1100]"
                            >Details</Tooltip.Content
                        >
                    </Tooltip.Root>
                </Tooltip.Provider>
                <Tooltip.Provider delayDuration={0}>
                    <Tooltip.Root>
                        <Tooltip.Trigger>
                            {#snippet child({ props })}
                                <a
                                    {...props}
                                    href={selected_layer?.files.zip}
                                    target="_blank"
                                    rel="noreferrer"
                                    class="hover:text-foreground cursor-pointer"
                                    aria-label="Download raw data"
                                >
                                    <i class="fas fa-download"></i>
                                </a>
                            {/snippet}
                        </Tooltip.Trigger>
                        <Tooltip.Content class="z-[1100]"
                            >Download raw data</Tooltip.Content
                        >
                    </Tooltip.Root>
                </Tooltip.Provider>
            </div>

            {#if region.layers && region.layers.length > 1}
                <div class="w-full mb-6">
                    <h5
                        class="text-xs font-semibold text-muted-foreground mb-2 uppercase tracking-wider"
                    >
                        Active Layer / Dataset
                    </h5>
                    <Select.Root
                        type="single"
                        bind:value={selected_layer_id}
                        onValueChange={(val) => {
                            if (val) handleLayerChange(val);
                        }}
                    >
                        <Select.Trigger
                            class="w-full justify-between bg-background/50 hover:bg-accent transition-colors border text-left"
                        >
                            <span class="truncate">
                                {region.layers.find((l) => l.id === selected_layer_id)?.name ?? "Select active layer"}
                            </span>
                        </Select.Trigger>
                        <Select.Content class="z-[1100]">
                            {#each region.layers as layer}
                                <Select.Item
                                    value={layer.id}
                                    label={layer.name}
                                >
                                    {layer.name}
                                </Select.Item>
                            {/each}
                        </Select.Content>
                    </Select.Root>
                </div>
            {/if}

            <div class="w-full mb-6">
                <h5
                    class="text-xs font-semibold text-muted-foreground mb-2 uppercase tracking-wider"
                >
                    Filter by Route
                </h5>
                <Popover.Root bind:open={route_select_open}>
                    <Popover.Trigger class="w-full">
                        <div
                            class="flex items-center justify-between w-full border rounded-md px-3 py-2 text-sm bg-background/50 hover:bg-accent transition-colors"
                        >
                            <div class="flex items-center gap-2">
                                {#if selected_shape_id === "all"}
                                    <div
                                        class="w-2 h-2 rounded-full bg-muted-foreground shrink-0"
                                    ></div>
                                    <span>All Network</span>
                                {:else}
                                    {@const opt = routeOptions.find(
                                        (o) => o.id === selected_shape_id,
                                    )}
                                    {#if opt}
                                        <div
                                            class="w-2 h-2 rounded-full shrink-0"
                                            style="background-color: {opt.color}"
                                        ></div>
                                        <span class="font-medium text-left"
                                            >{opt.label}</span
                                        >
                                    {:else}
                                        <span>Select Route</span>
                                    {/if}
                                {/if}
                            </div>
                            <ChevronsUpDown
                                class="size-4 opacity-50 shrink-0 ml-2"
                            />
                        </div>
                    </Popover.Trigger>
                    <Popover.Content class="w-[316px] p-0 z-[1100]">
                        <Command.Root>
                            <Command.Input placeholder="Search route..." />
                            <Command.List
                                class="max-h-[300px] overflow-y-auto overflow-x-hidden"
                            >
                                <Command.Empty>No route found.</Command.Empty>
                                <Command.Group>
                                    <Command.Item
                                        value="all"
                                        onSelect={() => {
                                            selected_shape_id = "all";
                                            route_select_open = false;
                                        }}
                                        class="flex items-center justify-between py-2 px-3 cursor-pointer hover:bg-accent rounded-sm"
                                    >
                                        <div class="flex items-center gap-3">
                                            <div
                                                class="w-2.5 h-2.5 rounded-full bg-muted-foreground shrink-0"
                                            ></div>
                                            <span class="font-medium"
                                                >All Network</span
                                            >
                                        </div>
                                        {#if selected_shape_id === "all"}
                                            <Check
                                                class="size-4 text-primary shrink-0"
                                            />
                                        {/if}
                                    </Command.Item>
                                </Command.Group>
                                <Command.Separator />
                                <Command.Group heading="Routes">
                                    {#each routeOptions as opt}
                                        <Command.Item
                                            value={opt.label}
                                            onSelect={() => {
                                                selected_shape_id = opt.id;
                                                route_select_open = false;
                                            }}
                                            class="flex items-center justify-between py-2 px-3 cursor-pointer hover:bg-accent rounded-sm"
                                        >
                                            <div
                                                class="flex items-center gap-3"
                                            >
                                                <div
                                                    class="w-2.5 h-2.5 rounded-full shrink-0"
                                                    style="background-color: {opt.color}"
                                                ></div>
                                                <span class="font-medium"
                                                    >{opt.label}</span
                                                >
                                            </div>
                                            {#if selected_shape_id === opt.id}
                                                <Check
                                                    class="size-4 text-primary shrink-0 ml-2"
                                                />
                                            {/if}
                                        </Command.Item>
                                    {/each}
                                </Command.Group>
                            </Command.List>
                        </Command.Root>
                    </Popover.Content>
                </Popover.Root>
            </div>

            <p class="text-xs font-medium text-muted-foreground mb-2">
                Explore the different layers below
            </p>

            <Accordion.Root
                type="single"
                value={open_accordion}
                onValueChange={(v: string | undefined) => {
                    open_accordion = v;
                    if (v) active_layer = parseInt(v);
                }}
                class="w-full"
            >
                <Accordion.Item
                    value={DisplayOptions.PRIORITIZATION.toString()}
                >
                    <Accordion.Trigger
                        class="text-sm font-medium hover:no-underline"
                        >Bus lane prioritization</Accordion.Trigger
                    >
                    <Accordion.Content>
                        <div
                            class="text-xs text-muted-foreground space-y-4 pt-2"
                        >
                            <p>
                                Display road segments coloured by bus lane
                                prioritization criteria:
                                <Tooltip.Provider delayDuration={0}>
                                    <Tooltip.Root>
                                        <Tooltip.Trigger>
                                            {#snippet child({ props })}
                                                <i
                                                    {...props}
                                                    class="fa fa-circle-info ml-1 text-muted-foreground hover:text-foreground"
                                                ></i>
                                            {/snippet}
                                        </Tooltip.Trigger>
                                        <Tooltip.Content class="z-[1100]"
                                            >Frequency and speed initially set
                                            to median values</Tooltip.Content
                                        >
                                    </Tooltip.Root>
                                </Tooltip.Provider>
                            </p>
                            <ul class="space-y-3 mb-3">
                                <li class="flex items-center gap-2">
                                    <Switch
                                        checked={criteria_bus_frequency_enabled}
                                        onCheckedChange={(v: boolean) =>
                                            (criteria_bus_frequency_enabled =
                                                v)}
                                        class="data-[state=checked]:bg-[rgb(59,193,168)]"
                                    />
                                    <span
                                        >Bus frequencies for <Input
                                            type="number"
                                            class="w-16 h-7 inline-block mx-1 px-2 text-center"
                                            bind:value={criteria_hour}
                                            min="0"
                                            max="23"
                                            disabled={!criteria_bus_frequency_enabled}
                                        />:00 hour with <Input
                                            type="number"
                                            class="w-16 h-7 inline-block mx-1 px-2 text-center"
                                            bind:value={criteria_bus_frequency}
                                            min="1"
                                            disabled={!criteria_bus_frequency_enabled}
                                        /> or + buses/hour</span
                                    >
                                </li>
                                <li class="flex items-center gap-2">
                                    <Switch
                                        checked={criteria_n_lanes_direction_enabled}
                                        onCheckedChange={(v: boolean) =>
                                            (criteria_n_lanes_direction_enabled =
                                                v)}
                                        class="data-[state=checked]:bg-[rgb(59,193,168)]"
                                    />
                                    <span
                                        ><Input
                                            type="number"
                                            class="w-16 h-7 inline-block mx-1 px-2 text-center"
                                            bind:value={
                                                criteria_n_lanes_direction
                                            }
                                            min="1"
                                            disabled={!criteria_n_lanes_direction_enabled}
                                        /> or + lanes/direction</span
                                    >
                                </li>
                                {#if display_rt}
                                    <li class="flex items-center gap-2">
                                        <Switch
                                            checked={criteria_avg_speed_enabled}
                                            onCheckedChange={(v: boolean) =>
                                                (criteria_avg_speed_enabled =
                                                    v)}
                                            class="data-[state=checked]:bg-[rgb(59,193,168)]"
                                        />
                                        <span
                                            ><Input
                                                type="number"
                                                class="w-16 h-7 inline-block mx-1 px-2 text-center"
                                                bind:value={criteria_avg_speed}
                                                min="0"
                                                disabled={!criteria_avg_speed_enabled}
                                            /> or - km/h average speed</span
                                        >
                                    </li>
                                {/if}
                            </ul>
                            <div class="flex gap-2">
                                <Button
                                    variant="outline"
                                    size="sm"
                                    class="h-6 text-[10px] px-2"
                                    onclick={() => {
                                        criteria_bus_frequency_enabled = true;
                                        criteria_n_lanes_direction_enabled = true;
                                        if (display_rt)
                                            criteria_avg_speed_enabled = true;
                                    }}>Select All</Button
                                >
                                <Button
                                    variant="outline"
                                    size="sm"
                                    class="h-6 text-[10px] px-2"
                                    onclick={() => {
                                        criteria_bus_frequency_enabled = false;
                                        criteria_n_lanes_direction_enabled = false;
                                        if (display_rt)
                                            criteria_avg_speed_enabled = false;
                                    }}>Deselect All</Button
                                >
                            </div>
                        </div>
                    </Accordion.Content>
                </Accordion.Item>

                <Accordion.Item value={DisplayOptions.BUS_LANES.toString()}>
                    <Accordion.Trigger
                        class="text-sm font-medium hover:no-underline"
                        >Bus lanes</Accordion.Trigger
                    >
                    <Accordion.Content>
                        <p class="text-xs text-muted-foreground pt-2">
                            Road segments with bus lanes are shown in <span
                                style="color: {COLOR_TEAL}"
                                class="font-bold">green</span
                            >
                        </p>
                        {#if geoData.metadata.data_census.prioritization_stats_length}
                            <p class="text-xs text-muted-foreground pt-2">
                                There are {(
                                    geoData.metadata.data_census
                                        .prioritization_stats_length
                                        .extension_bus_lane / 1000
                                ).toFixed(2)} km of bus lanes, accounting for
                                {(
                                    (geoData.metadata.data_census
                                        .prioritization_stats_length
                                        .extension_bus_lane /
                                        geoData.metadata.data_census
                                            .prioritization_stats_length
                                            .extension) *
                                    100
                                ).toFixed(2)}% of the {(
                                    geoData.metadata.data_census
                                        .prioritization_stats_length.extension /
                                    1000
                                ).toFixed(2)} km bus network
                            </p>
                        {/if}
                    </Accordion.Content>
                </Accordion.Item>

                <Accordion.Item value={DisplayOptions.FREQUENCY.toString()}>
                    <Accordion.Trigger
                        class="text-sm font-medium hover:no-underline"
                        >Transit frequency</Accordion.Trigger
                    >
                    <Accordion.Content>
                        <div
                            class="text-xs text-muted-foreground space-y-3 pt-2"
                        >
                            <p>
                                Road segments with bus service are colored by
                                frequency, from the <span
                                    style="color: {COLOR_GRADIENT[0]}"
                                    class="bg-black/50 font-bold px-1 rounded"
                                    >P5 ({geoData.metadata.data_census
                                        .frequency_hour[criteria_hour]
                                        ?.p5})</span
                                >
                                to the
                                <span
                                    style="color: {COLOR_GRADIENT[
                                        COLOR_GRADIENT.length - 1
                                    ]}"
                                    class="font-bold"
                                    >P95 ({geoData.metadata.data_census
                                        .frequency_hour[criteria_hour]
                                        ?.p95})</span
                                > number of buses per hour, considering:
                            </p>
                            <div class="flex items-center gap-2">
                                <span
                                    >Bus frequencies for <Input
                                        type="number"
                                        class="w-16 h-7 inline-block mx-1 px-2 text-center"
                                        bind:value={criteria_hour}
                                        min="0"
                                        max="23"
                                    />:00 hour</span
                                >
                            </div>
                            {#if geoData.metadata.data_census.frequency_hour[criteria_hour]}
                                <DataCensusTable
                                    census_1={geoData.metadata.data_census
                                        .frequency_hour[criteria_hour]}
                                    census_1_label="Length"
                                />
                            {/if}
                        </div>
                    </Accordion.Content>
                </Accordion.Item>

                <Accordion.Item value={DisplayOptions.N_LANES.toString()}>
                    <Accordion.Trigger
                        class="text-sm font-medium hover:no-underline"
                        >Number of lanes</Accordion.Trigger
                    >
                    <Accordion.Content>
                        <div
                            class="text-xs text-muted-foreground space-y-3 pt-2"
                        >
                            <p>
                                Road segments with bus service are colored by
                                number of lanes, from the <span
                                    style="color: {COLOR_GRADIENT[0]}"
                                    class="bg-black/50 font-bold px-1 rounded"
                                    >P5 ({geoData.metadata.data_census
                                        .lanes_length?.p5})</span
                                >
                                to the
                                <span
                                    style="color: {COLOR_GRADIENT[
                                        COLOR_GRADIENT.length - 1
                                    ]}"
                                    class="font-bold"
                                    >P95 ({geoData.metadata.data_census
                                        .lanes_length?.p95})</span
                                > number of lanes per direction.
                            </p>
                            {#if geoData.metadata.data_census.lanes_length}
                                <DataCensusTable
                                    census_1={geoData.metadata.data_census
                                        .lanes_length}
                                    census_2={geoData.metadata.data_census
                                        .lanes_frequency}
                                    census_1_label="Length"
                                    census_2_label="Frequency"
                                />
                            {/if}
                        </div>
                    </Accordion.Content>
                </Accordion.Item>

                {#if display_rt}
                    <Accordion.Item value={DisplayOptions.RT_SPEED.toString()}>
                        <Accordion.Trigger
                            class="text-sm font-medium hover:no-underline"
                            >Average speed</Accordion.Trigger
                        >
                        <Accordion.Content>
                            <div
                                class="text-xs text-muted-foreground space-y-3 pt-2"
                            >
                                <p>
                                    Road segments with bus service are colored
                                    by the average speed measured, from the <span
                                        style="color: {COLOR_GRADIENT_RED.slice().reverse()[0]}"
                                        class="font-bold"
                                        >P5 ({geoData.metadata.data_census.speed_avg_length?.p5?.toFixed(
                                            2,
                                        )})</span
                                    >
                                    to the
                                    <span
                                        style="color: {COLOR_GRADIENT_RED.slice().reverse()[
                                            COLOR_GRADIENT_RED.length - 1
                                        ]}"
                                        class="bg-black/50 font-bold px-1 rounded"
                                        >P95 ({geoData.metadata.data_census.speed_avg_length?.p95?.toFixed(
                                            2,
                                        )})</span
                                    > values (km/h).
                                </p>
                                {#if geoData.metadata.data_census.speed_avg_length}
                                    <DataCensusTable
                                        census_1={geoData.metadata.data_census
                                            .speed_avg_length}
                                        census_2={geoData.metadata.data_census
                                            .speed_avg_frequency}
                                        census_1_label="Length"
                                        census_2_label="Frequency"
                                    />
                                {/if}
                            </div>
                        </Accordion.Content>
                    </Accordion.Item>
                {/if}
            </Accordion.Root>
        </div>
    {/if}

    <!-- Control buttons -->
    <div class="w-full flex gap-2 mt-4 pt-4 border-t">
        {#if region && selected_layer && geoData && geoData.metadata}
            <Button
                variant="outline"
                size="sm"
                onclick={() => {
                    if (region && region.layers && region.layers.length === 1) {
                        region = undefined;
                    }
                    selected_layer = undefined;
                    selected_layer_id = "";
                    geoData = null;
                    active_layer = undefined;
                    open_accordion = undefined;
                    selected_shape_id = "all";
                    selectedWayId = undefined;
                    action_modal_about_open = false;
                    action_modal_data_open = false;
                    action_modal_details_open = false;
                }}
                class="flex-1"
            >
                <i class="fa-solid fa-arrow-left mr-2"></i> Source
            </Button>
            <Button
                variant="outline"
                size="sm"
                onclick={() => (action_hide_form = !action_hide_form)}
                class="flex-1"
            >
                {@html !action_hide_form
                    ? '<i class="fa-solid fa-map mr-2"></i> Hide'
                    : '<i class="fa-solid fa-sliders mr-2"></i> Layers'}
            </Button>
        {/if}
        <Button
            variant="outline"
            size="sm"
            onclick={() => {
                light_mode = !light_mode;
            }}
            class="flex-1"
        >
            <i class="fa-solid fa-circle-half-stroke mr-2"></i> Theme
        </Button>
    </div>
</div>

<!-- Right Details Panel -->
<PanelWayDetails
    bind:selectedWayId
    bind:selected_shape_id
    {geoData}
    {criteria_hour}
/>

<!-- Route Details Panel (shown when a shape is selected and no way is selected) -->
<PanelRouteDetails bind:selected_shape_id {geoData} {selectedWayId} />

<!-- Map caption -->
{#if active_layer !== undefined && !any_modal_open && !selectedWayId}
    <div
        id="caption"
        class="absolute bottom-4 left-4 right-4 sm:bottom-6 sm:left-auto sm:right-6 z-[1000] flex flex-col gap-3 p-4 bg-background/95 backdrop-blur shadow-lg border rounded-xl text-sm w-[calc(100vw-2rem)] sm:w-[350px] max-h-[30vh] sm:max-h-[40vh] overflow-y-auto"
    >
        {#if active_layer === DisplayOptions.PRIORITIZATION}
            <p class="flex items-start text-muted-foreground leading-tight">
                <span
                    class="inline-block w-3 h-3 rounded-sm mr-2 mt-0.5 align-middle shadow-sm shrink-0"
                    style="background-color: {COLOR_YELLOW}"
                ></span>
                <span
                    ><b class="text-foreground">Bus lane</b> with - {criteria_bus_frequency}
                    bus/h OR - {criteria_n_lanes_direction} lane/dir {#if display_rt}OR
                        {criteria_avg_speed} or - km/h avg. speed{/if}</span
                >
            </p>
            <p class="flex items-start text-muted-foreground leading-tight">
                <span
                    class="inline-block w-3 h-3 rounded-sm mr-2 mt-0.5 align-middle shadow-sm shrink-0"
                    style="background-color: {COLOR_TEAL}"
                ></span>
                <span
                    ><b class="text-foreground">Bus lane</b> with + {criteria_bus_frequency -
                        1} bus/h AND + {criteria_n_lanes_direction - 1} lane/dir
                    {#if display_rt}AND + {criteria_avg_speed} km/h avg. speed{/if}</span
                >
            </p>
            <p class="flex items-start text-muted-foreground leading-tight">
                <span
                    class="inline-block w-3 h-3 rounded-sm mr-2 mt-0.5 align-middle shadow-sm shrink-0"
                    style="background-color: {COLOR_RED}"
                ></span>
                <span
                    ><b class="text-foreground">NO bus lane</b> with + {criteria_bus_frequency -
                        1} bus/h AND + {criteria_n_lanes_direction - 1} lane/dir
                    {#if display_rt}AND
                        {criteria_avg_speed} or - km/h avg. speed{/if}</span
                >
            </p>
        {:else if active_layer === DisplayOptions.BUS_LANES}
            <p class="flex items-start text-muted-foreground leading-tight">
                <span
                    class="inline-block w-3 h-3 rounded-sm mr-2 mt-0.5 align-middle shadow-sm shrink-0"
                    style="background-color: {COLOR_TEAL}"
                ></span>
                <span
                    ><b class="text-foreground">Bus lane</b> with existing bus service</span
                >
            </p>
        {:else if active_layer === DisplayOptions.FREQUENCY}
            <div class="mb-2">
                <p class="mb-2 text-foreground font-semibold">
                    Transit frequency <span
                        class="text-muted-foreground font-normal"
                        >(buses/hour, at {criteria_hour}:00)</span
                    >
                </p>
                <div class="flex gap-2 items-center">
                    <span
                        class="min-w-[40px] text-right text-xs text-muted-foreground"
                        >{geoData?.metadata.data_census.frequency_hour[
                            criteria_hour
                        ]?.p5}</span
                    >
                    <div
                        class="flex-1 h-3 rounded border"
                        style="background: linear-gradient(to right, {COLOR_GRADIENT.map(
                            (c) => c,
                        ).join(', ')});"
                    ></div>
                    <span
                        class="min-w-[40px] text-left text-xs text-muted-foreground"
                        >{geoData?.metadata.data_census.frequency_hour[
                            criteria_hour
                        ]?.p95}</span
                    >
                </div>
            </div>
        {:else if active_layer === DisplayOptions.N_LANES}
            <div class="mb-2">
                <p class="mb-2 text-foreground font-semibold">
                    Number of lanes per direction
                </p>
                <div class="flex gap-2 items-center">
                    <span
                        class="min-w-[40px] text-right text-xs text-muted-foreground"
                        >{geoData?.metadata.data_census.lanes_length?.p5}</span
                    >
                    <div
                        class="flex-1 h-3 rounded border"
                        style="background: linear-gradient(to right, {COLOR_GRADIENT.map(
                            (c) => c,
                        ).join(', ')});"
                    ></div>
                    <span
                        class="min-w-[40px] text-left text-xs text-muted-foreground"
                        >{geoData?.metadata.data_census.lanes_length?.p95}</span
                    >
                </div>
            </div>
        {:else if active_layer === DisplayOptions.RT_SPEED}
            <div class="mb-2">
                <p class="mb-2 text-foreground font-semibold">
                    Average speed <span
                        class="text-muted-foreground font-normal">(km/h)</span
                    >
                </p>
                <div class="flex gap-2 items-center">
                    <span
                        class="min-w-[40px] text-right text-xs text-muted-foreground"
                        >{geoData?.metadata.data_census.speed_avg_length?.p5 &&
                            Math.floor(
                                geoData.metadata.data_census.speed_avg_length
                                    .p5,
                            )}</span
                    >
                    <div
                        class="flex-1 h-3 rounded border"
                        style="background: linear-gradient(to right, {COLOR_GRADIENT_RED.slice()
                            .reverse()
                            .map((c) => c)
                            .join(', ')});"
                    ></div>
                    <span
                        class="min-w-[40px] text-left text-xs text-muted-foreground"
                        >{geoData?.metadata.data_census.speed_avg_length?.p95 &&
                            Math.ceil(
                                geoData.metadata.data_census.speed_avg_length
                                    .p95,
                            )}</span
                    >
                </div>
            </div>
        {/if}

        {#if boundaryGeoJSON}
            <div class="border-t pt-2 mt-1 flex items-center justify-between">
                <span
                    class="text-xs text-muted-foreground flex items-center gap-2"
                >
                    <i
                        class="fa-solid fa-draw-polygon text-[11px]"
                        style="color: {region.color}"
                    ></i>
                    Operations Area
                </span>
                <button
                    class="relative inline-flex h-5 w-9 shrink-0 cursor-pointer items-center rounded-full transition-colors duration-200 outline-none {show_boundaries
                        ? 'bg-primary'
                        : 'bg-muted'}"
                    style="background-color: {show_boundaries
                        ? region.color
                        : ''};"
                    onclick={() => (show_boundaries = !show_boundaries)}
                    aria-label="Toggle analysis boundary"
                >
                    <span
                        class="pointer-events-none inline-block h-3.5 w-3.5 transform rounded-full bg-background shadow-lg ring-0 transition duration-200 ease-in-out {show_boundaries
                            ? 'translate-x-4'
                            : 'translate-x-0.5'}"
                    ></span>
                </button>
            </div>
        {/if}
    </div>
{/if}

{#if region && geoData && active_layer !== undefined && map}
    {#if boundaryGeoJSON && show_boundaries}
        <LayerBoundaries {map} {boundaryGeoJSON} color={region.color} />
    {/if}

    {#if active_layer === DisplayOptions.PRIORITIZATION}
        <LayerBusLanePrioritization
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            criteriaBusFrequency={criteria_bus_frequency}
            criteriaBusFrequencyEnabled={criteria_bus_frequency_enabled}
            criteriaNLanesDirection={criteria_n_lanes_direction}
            criteriaNLanesDirectionEnabled={criteria_n_lanes_direction_enabled}
            criteriaAvgSpeed={criteria_avg_speed}
            criteriaAvgSpeedEnabled={criteria_avg_speed_enabled}
            {selectedWayId}
            selectedShapeId={selected_shape_id}
            onWaySelect={(id) => (selectedWayId = id)}
            onLayerCreate={handleLayerCreate}
        />
    {:else if active_layer === DisplayOptions.BUS_LANES}
        <LayerBusLanes
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            {selectedWayId}
            selectedShapeId={selected_shape_id}
            onWaySelect={(id) => (selectedWayId = id)}
            onLayerCreate={handleLayerCreate}
        />
    {:else if active_layer === DisplayOptions.FREQUENCY}
        <LayerTransitFrequency
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            {selectedWayId}
            selectedShapeId={selected_shape_id}
            onWaySelect={(id) => (selectedWayId = id)}
            onLayerCreate={handleLayerCreate}
        />
    {:else if active_layer === DisplayOptions.N_LANES}
        <LayerNumberOfLanes
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            {selectedWayId}
            selectedShapeId={selected_shape_id}
            onWaySelect={(id) => (selectedWayId = id)}
            onLayerCreate={handleLayerCreate}
        />
    {:else if active_layer === DisplayOptions.RT_SPEED}
        <LayerRTSpeed
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            {selectedWayId}
            selectedShapeId={selected_shape_id}
            onWaySelect={(id) => (selectedWayId = id)}
            onLayerCreate={handleLayerCreate}
        />
    {/if}
{/if}

<!-- Modals -->
<ModalAbout bind:open={action_modal_about_open} />

{#if geoData}
    <ModalData
        bind:open={action_modal_data_open}
        {geoData}
        hour={criteria_hour}
        rt_data={display_rt}
        onRouteSelect={(shapeId) => {
            selected_shape_id = shapeId;
            selectedWayId = undefined;
        }}
        onWaySelect={(wayId) => {
            selectedWayId = wayId;
            if (map && geoData) {
                const feature = geoData.features.find(
                    (f: any) => f.properties?.way_osm_id === wayId,
                );
                if (feature) {
                    const tempLayer = L.geoJSON(feature);
                    map.flyToBounds(tempLayer.getBounds(), {
                        padding: [100, 100],
                        duration: 1,
                    });
                }
            }
        }}
    />
{/if}

<ModalDetails bind:open={action_modal_details_open} {geoData} />
