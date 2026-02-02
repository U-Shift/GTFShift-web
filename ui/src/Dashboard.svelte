<script lang="ts">
    import { untrack } from "svelte";

    import * as L from "leaflet";
    import type { FeatureCollection, Feature } from "geojson";

    import { basemapTheme } from "./lib/theme";;

    import ModalAbout from "./modals/ModalAbout.svelte";
    import LayerBusLanePrioritization from "./layers/LayerBusLanePrioritization.svelte";
    import LayerBusLanes from "./layers/LayerBusLanes.svelte";
    import LayerTransitFrequency from "./layers/LayerTransitFrequency.svelte";
    import LayerNumberOfLanes from "./layers/LayerNumberOfLanes.svelte";

    import {
        DB_REGIONS,
        COLOR_YELLOW,
        COLOR_TEAL,
        COLOR_RED,
        COLOR_GRAY,
        COLOR_GRADIENT,
        COLOR_GRADIENT_RED,
    } from "./data";
    import type { DATA_REGION } from "./data";
    import LayerRTSpeed from "./layers/LayerRTSpeed.svelte";
    import DataCensusTable from "./components/DataCensusTable.svelte";
    import { dataCensus, type DataCensus } from "./lib/layerUtils";
    import ModalData from "./modals/ModalData.svelte";
    import ModalDetails from "./modals/ModalDetails.svelte";

    // Map
    let { map }: { map: L.Map } = $props();
    let geoData: FeatureCollection | null = $state(null);

    // User feedback
    let loading: string | undefined = $state(undefined);

    // Dashboard state
    enum DisplayOptions {
        PRIORITIZATION,
        BUS_LANES,
        FREQUENCY,
        N_LANES,
        RT_SPEED
    }
   

    let region: DATA_REGION | undefined = $state(undefined);

    let display_tab: DisplayOptions | undefined = $state(undefined);
    let display_rt: boolean = $state(false); // true if region has rt-data (optional)
    
    let tab_census: DataCensus | undefined = $state(undefined);

    let criteria_hour: number = $state(8);
    let criteria_bus_frequency: number = $state(0);
    let criteria_n_lanes_direction: number = $state(2);
    let criteria_avg_speed: number | undefined = $state(undefined);
    
    let action_hide_form: boolean = $state(false); 
    let action_modal_about_open: boolean = $state(false);
    let action_modal_data_open: boolean = $state(false);
    let action_modal_details_open: boolean = $state(false);

    // Layer callback handler
    const handleLayerCreate = (layer: L.Layer, census: DataCensus | undefined) => {
        tab_census = census;
    };

    // Actions
    // > Map
    const toggleTheme = () => {
        basemapTheme.update((t) => (t === "light" ? "dark" : "light"));
    };

    // > Data source
    const handleRegionChange = async (event: Event) => {
        const regionId = (event.target as HTMLSelectElement).value;

        if (!regionId) return;

        region = DB_REGIONS.find((r: DATA_REGION) => r.id === regionId);
        if (!region || !map) return;

        display_tab = undefined;
        geoData = null;
        loading = "data for " + region.name;

        try {
            // Fetch and load GeoJSON
            const response = await fetch(region.geojson);
            geoData = await response.json() as FeatureCollection;

            display_rt = geoData.features.some(
                (feature:Feature) => feature.properties?.speed_avg,
            );

            // Set criteria base values
            action_modal_data_open = false;
            action_modal_details_open = false;
            criteria_hour = 8;
            criteria_n_lanes_direction = 2;
            // frequency and avg_speed will be set to P75 values
            let query = geoData.features.filter(
                    (feature) =>
                        feature.properties?.hour === criteria_hour &&
                        feature.properties?.frequency,
                );
            criteria_bus_frequency = Math.floor((dataCensus(
                query,
                "frequency"
            ) as DataCensus).median as number);
            criteria_avg_speed = display_rt ? Math.floor((dataCensus(
                query,
                "speed_avg"
            ) as DataCensus).median as number) : undefined;


            // Update display_tab option to trigger rendering
            display_tab = DisplayOptions.PRIORITIZATION;
            

            console.log("Loaded GeoJSON for region:", region.id);
        } catch (error) {
            console.error("Error loading GeoJSON:", error);
        } finally {
            loading = undefined;
        }
    };

    // Display - Layer components now handle rendering via effects
    // No longer need the centralized $effect and render_* functions
</script>

<svelte:head>
    <link
        rel="stylesheet"
        href="https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css"
    />
    <script
        src="https://kit.fontawesome.com/17e93d90c5.js"
        crossorigin="anonymous"
    ></script>
</svelte:head>

<div id="controls-panel" class="overflow-auto">
    <div class="container-fluid" style="text-align: left;">
        <div style="display: flex; flex-direction: row; flex-wrap: nowrap;">
            <h3
                style="margin: 0; margin-bottom: 0.1rem; color: #363636; text-align: left;"
                class="text-primary"
            >
                GTFShift
            </h3>
            <small style="vertical-align: bottom; margin-left: 0.5rem;">
                <a
                    href="#"
                    class="text-secondary"
                    on:click={(e) => {
                        e.preventDefault();
                        action_modal_about_open = !action_modal_about_open;
                    }}
                    data-tooltip="About"
                    data-placement="right"
                >
                    <i class="fas fa-info-circle"></i>
                </a>
            </small>
        </div>
        <p class="text-primary">Bus lane prioritization tool</p>
        {#if loading}
            <p class="small text-secondary" aria-busy="true">
                Loading {loading}...
            </p>
        {/if}
    </div>

    {#if region === undefined}
        <div class="container-fluid text-left">
            <h5 style="margin-bottom: 0.1rem;" class="text-primary">
                Data source
            </h5>
            <p class="small text-primary">
                Select the region you want to analyse
            </p>
            <select
                name="region"
                aria-label="Select region"
                required
                on:change={handleRegionChange}
                disabled={loading !== undefined}
            >
                <option selected disabled value=""> Select region </option>
                {#each DB_REGIONS as region}
                    <option value={region.id}
                        >{region.name} ({region.date})</option
                    >
                {/each}
            </select>
        </div>
    {/if}

    {#if region !== undefined && geoData && !action_hide_form}
        <div class="container-fluid text-left" id="form">
            <h5 style="margin-bottom: 0.1rem;" class="text-primary">
                {region.name}
            </h5>
            <p class="small text-tertiary mb-0">
                Data for {region.date}
                <a
                    href="#"
                    class="text-secondary"
                    on:click={(e) => {
                        e.preventDefault();
                        action_modal_data_open = !action_modal_data_open;
                    }}
                    data-tooltip="Attribute table"
                    data-placement="bottom"
                >
                    <i class="fas fa-table"></i>
                </a>
                <a
                    href="#"
                    class="text-secondary"
                    on:click={(e) => {
                        e.preventDefault();
                        action_modal_details_open = !action_modal_details_open;
                    }}
                    data-tooltip="Details"
                    data-placement="bottom"
                >
                    <i class="fas fa-code"></i>
                </a>
            </p>

            <p class="small text-primary">Explore the different layers below</p>
            <details
                name={DisplayOptions.PRIORITIZATION.toString()}
                open={display_tab === DisplayOptions.PRIORITIZATION
                    ? "true"
                    : undefined}
            >
                <summary
                    on:click={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        display_tab =
                            display_tab === DisplayOptions.PRIORITIZATION
                                ? undefined
                                : DisplayOptions.PRIORITIZATION;
                    }}>Bus lane prioritization</summary
                >
                <div class="small text-primary">
                    <p>
                        Display road segments coloured by bus lane
                        prioritization criteria:
                    </p>
                    <ul>
                        <li>
                            Bus frequencies for
                            <input
                                type="number"
                                name="number"
                                placeholder="Nr"
                                aria-label="Nr"
                                style="width: 5rem;"
                                bind:value={criteria_hour}
                                min="0"
                                max="23"
                            />:00 hour with <input
                                type="number"
                                name="number"
                                placeholder="Nr"
                                aria-label="Nr"
                                style="width: 5rem;"
                                bind:value={criteria_bus_frequency}
                                min="1"
                            /> or + buses/hour
                        </li>
                        <li>
                            <input
                                type="number"
                                name="number"
                                placeholder="Nr"
                                aria-label="Nr"
                                style="width: 5rem;"
                                bind:value={criteria_n_lanes_direction}
                                min="1"
                            /> or + lanes/direction
                        </li>
                        {#if display_rt}
                        <li>
                            <input 
                                type="number"
                                name="number"
                                placeholder="Nr"
                                aria-label="Nr"
                                style="width: 5rem;"
                                bind:value={criteria_avg_speed}
                                min="0"
                            /> or - km/h average commercial speed
                        </li>
                        {/if}
                    </ul>
                </div>
            </details>

            <details
                name={DisplayOptions.BUS_LANES}
                open={display_tab === DisplayOptions.BUS_LANES
                    ? "true"
                    : undefined}
            >
                <summary
                    on:click={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        display_tab =
                            display_tab === DisplayOptions.BUS_LANES
                                ? undefined
                                : DisplayOptions.BUS_LANES;
                    }}>Bus lanes</summary
                >
                <div class="small">
                    <p>
                        Road segments with bus lanes are shown in <span
                            style="color: {COLOR_TEAL}; font-weight: bold;"
                            >green</span
                        >
                    </p>
                </div>
            </details>

            <details
                name={DisplayOptions.FREQUENCY}
                open={display_tab === DisplayOptions.FREQUENCY
                    ? "true"
                    : undefined}
            >
                <summary
                    on:click={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        display_tab =
                            display_tab === DisplayOptions.FREQUENCY
                                ? undefined
                                : DisplayOptions.FREQUENCY;
                    }}>Transit frequency</summary
                >
                <div class="small text-secondary">
                    <p>
                        Road segments with bus service are colored by frequency,
                        from the <span
                            style="padding: 0 4px; background-color: #00000080; color: {COLOR_GRADIENT[0]}; font-weight: bold; border-radius: 4px;"
                            >lowest ({tab_census?.min})</span
                        >
                        to the
                        <span
                            style="color: {COLOR_GRADIENT[
                                COLOR_GRADIENT.length - 1
                            ]}; font-weight: bold;"
                            >highest ({tab_census?.max})</span
                        >
                        number of buses per hour, considering:
                    </p>
                    <ul>
                        <li>
                            Bus frequencies for
                            <input
                                type="number"
                                name="number"
                                placeholder="Nr"
                                aria-label="Nr"
                                style="width: 5rem;"
                                bind:value={criteria_hour}
                                min="0"
                                max="23"
                            />:00 hour
                        </li>
                    </ul>
                </div>

                {#if tab_census}
                    <DataCensusTable census={tab_census} />
                {/if}
            </details>

            <details
                name={DisplayOptions.N_LANES}
                open={display_tab === DisplayOptions.N_LANES
                    ? "true"
                    : undefined}
            >
                <summary
                    on:click={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        display_tab =
                            display_tab === DisplayOptions.N_LANES
                                ? undefined
                                : DisplayOptions.N_LANES;
                    }}>Number of lanes</summary
                >
                <div class="small text-secondary">
                    Road segments with bus service are colored by number of
                    lanes, from the <span
                        style="padding: 0 4px; background-color: #00000080; color: {COLOR_GRADIENT[0]}; font-weight: bold; border-radius: 4px;"
                        >lowest ({tab_census?.min})</span
                    >
                    to the
                    <span
                        style="color: {COLOR_GRADIENT[
                            COLOR_GRADIENT.length - 1
                        ]}; font-weight: bold;"
                        >highest ({tab_census?.max})</span
                    > number of lanes per direction.
                </div>

                {#if tab_census}
                    <DataCensusTable census={tab_census} />
                {/if}
            </details>

            {#if display_rt}
            <details
                name={DisplayOptions.RT_SPEED}
                open={display_tab === DisplayOptions.RT_SPEED
                    ? "true"
                    : undefined}
            >
                <summary
                    on:click={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        display_tab =
                            display_tab === DisplayOptions.RT_SPEED
                                ? undefined
                                : DisplayOptions.RT_SPEED;
                    }}>Commercial speed</summary
                >
                <div class="small text-secondary">
                    Road segments with bus service are colored by the average commercial speed measured 
                    , from the <span
                        style="color: {COLOR_GRADIENT_RED.toReversed()[0]}; font-weight: bold;"
                        >lowest ({tab_census?.min?.toFixed(2)})</span
                    >
                    to the
                    <span
                        style="padding: 0 4px; background-color: #00000080; color: {COLOR_GRADIENT_RED.toReversed()[
                            COLOR_GRADIENT_RED.length - 1
                        ]}; font-weight: bold;border-radius: 4px;"
                        >highest ({tab_census?.max?.toFixed(2)})</span
                    > values (km/h).
                </div>

                {#if tab_census}
                    <DataCensusTable census={tab_census} />
                {/if}
            </details>
            {/if}
        </div>
    {/if}

    <div class="container-fluid" role="group">
        {#if region && region.geojson && geoData}
            <button
                class="secondary outline"
                id="clear-region"
                on:click={() => {
                    region = undefined;
                }}
            >
                <i class="fa-solid fa-arrow-left"></i> Change source
            </button>
            <button
                class="secondary outline"
                id="toggle-form"
                on:click={() => (action_hide_form = !action_hide_form)}
            >
                {@html !action_hide_form
                    ? '<i class="fa-solid fa-map"></i> Expand map'
                    : '<i class="fa-solid fa-sliders"></i> Layers'}
            </button>
            <button
                class="secondary outline"
                id="download-data"
                on:click={() => window.open(region.geojson, "_blank")}
            >
                <i class="fa-solid fa-download"></i> Raw data
            </button>
        {/if}
        <button
            class="secondary outline"
            id="toggle-color"
            on:click={toggleTheme}
        >
            {@html $basemapTheme === "light"
                ? '<i class="fa-solid fa-circle-half-stroke"></i> Dark mode'
                : '<i class="fa-solid fa-circle-half-stroke"></i> Light mode'}
        </button>
    </div>
</div>

<div id="caption" class="overflow-auto">
    {#if display_tab === DisplayOptions.PRIORITIZATION}
        <p>
            <span
                class="caption-square"
                style="background-color: {COLOR_YELLOW}"
            ></span><b>Bus lane</b> with 
                - {criteria_bus_frequency} bus/h 
                OR - {criteria_n_lanes_direction} lane/dir
                {#if display_rt}OR - {criteria_avg_speed} km/h avg. speed{/if}
        </p>
        <p>
            <span class="caption-square" style="background-color: {COLOR_TEAL}"
            ></span><b>Bus lane</b> with 
                + {criteria_bus_frequency} bus/h 
                AND + {criteria_n_lanes_direction} lane/dir
                {#if display_rt}AND + {criteria_avg_speed} km/h avg. speed{/if}
        </p>
        <p>
            <span class="caption-square" style="background-color: {COLOR_RED}"
            ></span><b>NO bus lane</b> with + {criteria_bus_frequency} bus/h AND
            + {criteria_n_lanes_direction} lane/dir
            {#if display_rt} AND - {criteria_avg_speed} km/h avg. speed{/if}
        </p>
    {:else if display_tab === DisplayOptions.BUS_LANES}
        <p>
            <span class="caption-square" style="background-color: {COLOR_TEAL}"
            ></span><b>Bus lane</b> with existing bus service
        </p>
    {:else if display_tab === DisplayOptions.FREQUENCY}
        <div style="margin-bottom: 1rem;">
            <p style="margin-bottom: 0.5rem;">
                <b>Transit frequency</b> (buses/hour, at {criteria_hour}:00)
            </p>
            <div style="display: flex; gap: 0.5rem; align-items: center;">
                <span
                    style="min-width: 40px; text-align: right; font-size: 0.85rem;"
                    >{tab_census?.min}</span
                >
                <div
                    style="flex: 1; height: 1.5em; background: linear-gradient(to right, {COLOR_GRADIENT.map(
                        (c) => c,
                    ).join(', ')}); border-radius: 4px; border: 1px solid #ccc;"
                ></div>
                <span
                    style="min-width: 40px; text-align: left; font-size: 0.85rem;"
                    >{tab_census?.max}</span
                >
            </div>
        </div>
    {:else if display_tab === DisplayOptions.N_LANES}
        <div style="margin-bottom: 1rem;">
            <p style="margin-bottom: 0.5rem;">
                <b>Number of lanes per direction</b>
            </p>
            <div style="display: flex; gap: 0.5rem; align-items: center;">
                <span
                    style="min-width: 40px; text-align: right; font-size: 0.85rem;"
                    >{tab_census?.min}</span
                >
                <div
                    style="flex: 1; height: 1.5em; background: linear-gradient(to right, {COLOR_GRADIENT.map(
                        (c) => c,
                    ).join(', ')}); border-radius: 4px; border: 1px solid #ccc;"
                ></div>
                <span
                    style="min-width: 40px; text-align: left; font-size: 0.85rem;"
                    >{tab_census?.max}</span
                >
            </div>
        </div>
    {:else if display_tab === DisplayOptions.RT_SPEED}
        <div style="margin-bottom: 1rem;">
            <p style="margin-bottom: 0.5rem;">
                <b>Commercial speed</b> (km/h)
            </p>
            <div style="display: flex; gap: 0.5rem; align-items: center;">
                <span
                    style="min-width: 40px; text-align: right; font-size: 0.85rem;"
                    >{tab_census?.min && Math.round(tab_census.min)}</span
                >
                <div
                    style="flex: 1; height: 1.5em; background: linear-gradient(to right, {COLOR_GRADIENT_RED.toReversed().map(
                        (c) => c,
                    ).join(', ')}); border-radius: 4px; border: 1px solid #ccc;"
                ></div>
                <span
                    style="min-width: 40px; text-align: left; font-size: 0.85rem;"
                    >{tab_census?.max && Math.round(tab_census.max)}</span
                >
            </div>
        </div>
    {/if}
</div>

{#if region && geoData && display_tab !== undefined && map}
    {#if display_tab === DisplayOptions.PRIORITIZATION}
        <LayerBusLanePrioritization
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            criteriaBusFrequency={criteria_bus_frequency}
            criteriaNLanesDirection={criteria_n_lanes_direction}
            criteriaAvgSpeed={criteria_avg_speed}
            onLayerCreate={handleLayerCreate}
        />
    {:else if display_tab === DisplayOptions.BUS_LANES}
        <LayerBusLanes {map} {geoData} onLayerCreate={handleLayerCreate} />
    {:else if display_tab === DisplayOptions.FREQUENCY}
        <LayerTransitFrequency
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            onLayerCreate={handleLayerCreate}
        />
    {:else if display_tab === DisplayOptions.N_LANES}
        <LayerNumberOfLanes {map} {geoData} onLayerCreate={handleLayerCreate} />
    {:else if display_tab === DisplayOptions.RT_SPEED}
        <LayerRTSpeed {map} {geoData} onLayerCreate={handleLayerCreate} />
    {/if}
{/if}

<ModalAbout bind:open={action_modal_about_open} />

{#if geoData}
<ModalData 
    open={action_modal_data_open} 
    geoData={geoData} 
    hour={criteria_hour}    
    rt_data={display_rt}
/>
<ModalDetails 
    open={action_modal_details_open} 
    geoData={geoData} 
    rt_data={display_rt}
/>
{/if}


<style>
    @import "./dashboard.css";
</style>