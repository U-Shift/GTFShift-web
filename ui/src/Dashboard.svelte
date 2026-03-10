<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import type { Feature } from "geojson";
    import type { GeoPrioritization } from "./types/GeoPrioritization";
    import type { DataRegion } from "./types/DataRegion";

    import ModalAbout from "./modals/ModalAbout.svelte";
    import LayerBusLanePrioritization from "./layers/LayerBusLanePrioritization.svelte";
    import LayerBusLanes from "./layers/LayerBusLanes.svelte";
    import LayerTransitFrequency from "./layers/LayerTransitFrequency.svelte";
    import LayerNumberOfLanes from "./layers/LayerNumberOfLanes.svelte";
    import LayerRTSpeed from "./layers/LayerRTSpeed.svelte";
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

    const handleRegionChange = async (regionId: string) => {
        if (!regionId) return;

        region = DB_REGIONS.find((r: DataRegion) => r.id === regionId);
        if (!region || !map) return;

        active_layer = undefined;
        open_accordion = undefined;
        selected_shape_id = "all";
        geoData = null;
        loading = "data for " + region.name;

        try {
            // Fetch and load new data model components
            const [
                waysRes,
                wayDataRes,
                metadataRes,
                routeDataRes,
                shapeDataRes,
            ] = await Promise.all([
                fetch(region.files.ways),
                fetch(region.files.way_data),
                fetch(region.files.metadata),
                fetch(region.files.route_data),
                fetch(region.files.shape_data),
            ]);

            const ways = await waysRes.json();
            const wayData = await wayDataRes.json();
            const metadata = await metadataRes.json();
            const routeData = await routeDataRes.json();
            const shapeData = await shapeDataRes.json();

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
            action_modal_data_open = false;
            action_modal_details_open = false;
            criteria_hour = 8;
            criteria_n_lanes_direction = 2;
            criteria_bus_frequency =
                geoData.metadata.data_census.frequency.median;
            criteria_avg_speed = Math.floor(
                geoData.metadata.data_census.speed_avg?.median ?? 0,
            );
            criteria_bus_frequency_enabled = true;
            criteria_n_lanes_direction_enabled = true;
            active_layer = DisplayOptions.PRIORITIZATION;
            open_accordion = DisplayOptions.PRIORITIZATION.toString();

            console.log("Loaded GeoJSON for region:", region.id);
        } catch (error) {
            console.error("Error loading GeoJSON:", error);
        } finally {
            loading = undefined;
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
    });

    const routeOptions = $derived.by(() => {
        if (!geoData || !geoData.shapes) return [];
        return Object.keys(geoData.shapes)
            .map((s: any) => ({
                id: s,
                label: `${geoData.shapes[s].route_short_name}: ${geoData.shapes[s].route_long_name} (${geoData.shapes[s].direction_id ? "DESC" : "ASC"})`,
                short_name: geoData.shapes[s].route_short_name,
                color: geoData.shapes[s].route_color,
            }))
            .sort((a, b) =>
                a.short_name.localeCompare(b.short_name, undefined, {
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
    class="absolute top-4 left-4 z-[1000] flex flex-col items-start w-[350px] max-h-[calc(100vh-2rem)] rounded-xl bg-background/95 backdrop-blur shadow-lg border p-4 overflow-y-auto h-fit"
    style={geoData
        ? "background-image: url('./static/logo/background_blur_transparent.png'); background-size: auto 7vw; background-position: top right; background-repeat: no-repeat;"
        : ""}
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
            <div class="flex flex-col gap-2 mt-3">
                {#each DB_REGIONS as r}
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
                                class="region-icon mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg transition-colors"
                                style="background-color: {r.color}1a; color: {r.color};"
                            >
                                <i class="fas fa-map-location-dot text-sm"></i>
                            </div>
                            <div class="flex-1 min-w-0">
                                <p
                                    class="text-sm font-semibold text-foreground leading-tight truncate"
                                >
                                    {r.name}
                                </p>
                                <p class="text-xs text-muted-foreground mt-0.5">
                                    <i class="fas fa-calendar-alt mr-1"
                                    ></i>{r.date}
                                </p>
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
            </div>
        </div>
    {/if}

    <!-- Form 2: Region display options -->
    {#if region !== undefined && geoData && !action_hide_form}
        <div class="w-full text-left flex-1" id="form">
            <h5 class="text-lg font-semibold text-primary mb-1">
                {region.name}
            </h5>
            <div
                class="flex items-center gap-3 text-sm text-muted-foreground mb-4"
            >
                <span>Data for {region.date}</span>
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
                                    href={region.files.zip}
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
                            <div
                                class="flex items-center gap-2 overflow-hidden"
                            >
                                {#if selected_shape_id === "all"}
                                    <div
                                        class="w-2 h-2 rounded-full bg-muted-foreground shrink-0"
                                    ></div>
                                    <span class="truncate">All Network</span>
                                {:else}
                                    {@const opt = routeOptions.find(
                                        (o) => o.id === selected_shape_id,
                                    )}
                                    {#if opt}
                                        <div
                                            class="w-2 h-2 rounded-full shrink-0"
                                            style="background-color: {opt.color}"
                                        ></div>
                                        <span class="truncate font-medium"
                                            >{opt.label}</span
                                        >
                                    {:else}
                                        <span class="truncate"
                                            >Select Route</span
                                        >
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
                                                class="flex items-center gap-3 overflow-hidden"
                                            >
                                                <div
                                                    class="w-2.5 h-2.5 rounded-full shrink-0"
                                                    style="background-color: {opt.color}"
                                                ></div>
                                                <span
                                                    class="truncate font-medium"
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
                            <ul class="space-y-3">
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
                                    >lowest ({geoData.metadata.data_census
                                        .frequency_hour[criteria_hour]
                                        ?.min})</span
                                >
                                to the
                                <span
                                    style="color: {COLOR_GRADIENT[
                                        COLOR_GRADIENT.length - 1
                                    ]}"
                                    class="font-bold"
                                    >highest ({geoData.metadata.data_census
                                        .frequency_hour[criteria_hour]
                                        ?.max})</span
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
                                    census={geoData.metadata.data_census
                                        .frequency_hour[criteria_hour]}
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
                                    >lowest ({geoData.metadata.data_census.lanes
                                        ?.min})</span
                                >
                                to the
                                <span
                                    style="color: {COLOR_GRADIENT[
                                        COLOR_GRADIENT.length - 1
                                    ]}"
                                    class="font-bold"
                                    >highest ({geoData.metadata.data_census
                                        .lanes?.max})</span
                                > number of lanes per direction.
                            </p>
                            {#if geoData.metadata.data_census.lanes}
                                <DataCensusTable
                                    census={geoData.metadata.data_census.lanes}
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
                                        >lowest ({geoData.metadata.data_census.speed_avg?.min?.toFixed(
                                            2,
                                        )})</span
                                    >
                                    to the
                                    <span
                                        style="color: {COLOR_GRADIENT_RED.slice().reverse()[
                                            COLOR_GRADIENT_RED.length - 1
                                        ]}"
                                        class="bg-black/50 font-bold px-1 rounded"
                                        >highest ({geoData.metadata.data_census.speed_avg?.max?.toFixed(
                                            2,
                                        )})</span
                                    > values (km/h).
                                </p>
                                {#if geoData.metadata.data_census.speed_avg}
                                    <DataCensusTable
                                        census={geoData.metadata.data_census
                                            .speed_avg}
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
        {#if region && region.files && geoData && geoData.metadata}
            <Button
                variant="outline"
                size="sm"
                onclick={() => {
                    region = undefined;
                    active_layer = undefined;
                    open_accordion = undefined;
                    selected_shape_id = "all";
                    selectedWayId = undefined;
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
<PanelWayDetails bind:selectedWayId bind:selected_shape_id {geoData} {criteria_hour} />

<!-- Route Details Panel (shown when a shape is selected and no way is selected) -->
<PanelRouteDetails bind:selected_shape_id {geoData} {selectedWayId} />

<!-- Map caption -->
{#if active_layer !== undefined && !any_modal_open && !selectedWayId}
    <div
        id="caption"
        class="absolute bottom-6 right-6 z-[1000] flex flex-col gap-3 p-4 bg-background/95 backdrop-blur shadow-lg border rounded-xl text-sm w-[350px] max-h-[40vh] overflow-y-auto"
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
                        ]?.min}</span
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
                        ]?.max}</span
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
                        >{geoData?.metadata.data_census.lanes?.min}</span
                    >
                    <div
                        class="flex-1 h-3 rounded border"
                        style="background: linear-gradient(to right, {COLOR_GRADIENT.map(
                            (c) => c,
                        ).join(', ')});"
                    ></div>
                    <span
                        class="min-w-[40px] text-left text-xs text-muted-foreground"
                        >{geoData?.metadata.data_census.lanes?.max}</span
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
                        >{geoData?.metadata.data_census.speed_avg?.min &&
                            Math.floor(
                                geoData.metadata.data_census.speed_avg.min,
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
                        >{geoData?.metadata.data_census.speed_avg?.max &&
                            Math.ceil(
                                geoData.metadata.data_census.speed_avg.max,
                            )}</span
                    >
                </div>
            </div>
        {/if}
    </div>
{/if}

<!-- Map layers -->
{#if region && geoData && active_layer !== undefined && map}
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

<ModalDetails
    bind:open={action_modal_details_open}
    wayId={selectedWayId}
    {geoData}
/>
