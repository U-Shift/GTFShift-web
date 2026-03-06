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

    import { Button } from "$lib/components/ui/button/index.js";
    import { Switch } from "$lib/components/ui/switch/index.js";
    import { Input } from "$lib/components/ui/input/index.js";
    import * as Accordion from "$lib/components/ui/accordion/index.js";

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

    /**
     * Interpolates a color from a gradient based on a value and a range.
     */
    function getColorFromGradient(
        value: number,
        min: number,
        max: number,
        gradient: string[],
    ) {
        if (min === max) return gradient[0];
        const percent = Math.min(Math.max((value - min) / (max - min), 0), 1);
        const index = percent * (gradient.length - 1);
        const lowIndex = Math.floor(index);
        const highIndex = Math.ceil(index);
        const fraction = index - lowIndex;

        const hexToRgb = (hex: string) => {
            const r = parseInt(hex.substring(1, 3), 16);
            const g = parseInt(hex.substring(3, 5), 16);
            const b = parseInt(hex.substring(5, 7), 16);
            return [r, g, b];
        };

        const rgbToHex = (r: number, g: number, b: number) => {
            return `#${((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)}`;
        };

        const color1 = hexToRgb(gradient[lowIndex]);
        const color2 = hexToRgb(gradient[highIndex]);

        const r = Math.round(color1[0] + (color2[0] - color1[0]) * fraction);
        const g = Math.round(color1[1] + (color2[1] - color1[1]) * fraction);
        const b = Math.round(color1[2] + (color2[2] - color1[2]) * fraction);

        return rgbToHex(r, g, b);
    }
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
    style="background-image: url('./static/logo/background_blur_transparent.png'); background-size: auto 7vw; background-position: top right; background-repeat: no-repeat;"
>
    <!-- Title -->
    <div class="w-full text-left mb-4">
        <div class="flex items-center gap-2 mb-1">
            <h3 class="text-xl font-bold text-primary m-0">GTFShift</h3>
            <button
                class="text-muted-foreground hover:text-foreground"
                onclick={(e) => {
                    e.preventDefault();
                    action_modal_data_open = false;
                    action_modal_details_open = false;
                    action_modal_about_open = !action_modal_about_open;
                }}
                aria-label="About"
            >
                <i class="fas fa-info-circle"></i>
            </button>
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
                <button
                    class="hover:text-foreground"
                    onclick={(e) => {
                        e.preventDefault();
                        action_modal_about_open = false;
                        action_modal_details_open = false;
                        action_modal_data_open = !action_modal_data_open;
                    }}
                    aria-label="Attribute table"
                >
                    <i class="fas fa-table"></i>
                </button>
                <button
                    class="hover:text-foreground"
                    onclick={(e) => {
                        e.preventDefault();
                        action_modal_about_open = false;
                        action_modal_data_open = false;
                        action_modal_details_open = !action_modal_details_open;
                    }}
                    aria-label="Details"
                >
                    <i class="fas fa-code"></i>
                </button>
                <a
                    href={region.files.zip}
                    target="_blank"
                    rel="noreferrer"
                    class="hover:text-foreground"
                    aria-label="Download raw data"
                >
                    <i class="fas fa-download"></i>
                </a>
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
                                <i
                                    class="fa fa-circle-info ml-1"
                                    title="Frequency and speed initially set to median values"
                                ></i>
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
                    class="p-3 bg-zinc-100/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 flex flex-col justify-between shadow-sm overflow-hidden relative"
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
                    class="p-3 bg-zinc-100/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 flex flex-col justify-between shadow-sm overflow-hidden relative"
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

                <!-- Total Lanes Card -->
                <div
                    class="p-3 bg-zinc-100/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 flex flex-col justify-between shadow-sm"
                >
                    <p
                        class="text-[10px] font-bold uppercase text-muted-foreground mb-1"
                    >
                        Total Lanes
                    </p>
                    <p class="text-sm font-semibold text-muted-foreground">
                        <span class="text-foreground font-bold"
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
                    class="p-3 bg-zinc-100/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 flex flex-col justify-between shadow-sm"
                >
                    <p
                        class="text-[10px] font-bold uppercase text-muted-foreground mb-1"
                    >
                        Nr Directions
                    </p>
                    <p class="text-sm font-bold">{way.n_directions ?? "N/A"}</p>
                </div>

                <!-- Lanes/Direction Card -->
                <div
                    class="p-3 bg-zinc-100/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 flex flex-col justify-between shadow-sm overflow-hidden relative"
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
                        class="p-3 bg-zinc-100/80 dark:bg-zinc-900/40 rounded-xl border border-border/50 flex flex-col justify-between shadow-sm overflow-hidden relative"
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
                            <span
                                class="px-2 py-1 text-[10px] font-bold rounded border"
                                style={routeColor
                                    ? `background-color: ${routeColor}22; border-color: ${routeColor}44; color: ${routeColor};`
                                    : ""}
                            >
                                {route?.route_short_name || shape_id}
                            </span>
                        {/each}
                    </div>
                </section>
            {/if}

            <section
                class="space-y-3 p-4 bg-zinc-100/80 dark:bg-zinc-900/40 rounded-xl border border-border/50"
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
                                ...Object.values(
                                    way.hour_frequency || { 0: 1 },
                                ),
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
                                {i}:00: {freq}
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
            onWaySelect={(id) => (selectedWayId = id)}
            onLayerCreate={handleLayerCreate}
        />
    {:else if active_layer === DisplayOptions.BUS_LANES}
        <LayerBusLanes
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            {selectedWayId}
            onWaySelect={(id) => (selectedWayId = id)}
            onLayerCreate={handleLayerCreate}
        />
    {:else if active_layer === DisplayOptions.FREQUENCY}
        <LayerTransitFrequency
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            {selectedWayId}
            onWaySelect={(id) => (selectedWayId = id)}
            onLayerCreate={handleLayerCreate}
        />
    {:else if active_layer === DisplayOptions.N_LANES}
        <LayerNumberOfLanes
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            {selectedWayId}
            onWaySelect={(id) => (selectedWayId = id)}
            onLayerCreate={handleLayerCreate}
        />
    {:else if active_layer === DisplayOptions.RT_SPEED}
        <LayerRTSpeed
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            {selectedWayId}
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
