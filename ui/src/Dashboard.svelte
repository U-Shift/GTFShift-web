<script lang="ts">
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

    import {
        DB_REGIONS,
        COLOR_YELLOW,
        COLOR_TEAL,
        COLOR_RED,
        COLOR_GRADIENT,
        COLOR_GRADIENT_RED,
    } from "./data";

    // Map
    let { map, light_mode = $bindable() }: { map: L.Map, light_mode: boolean } = $props();
    let geoData: GeoPrioritization | null = $state(null);

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

    let region: DataRegion | undefined = $state(undefined);

    let display_tab: DisplayOptions | undefined = $state(undefined);
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

    // Action handlers 
    const handleLayerCreate = (layer: L.Layer) => {};

    const handleRegionChange = async (event: Event) => {
        const regionId = (event.target as HTMLSelectElement).value;

        if (!regionId) return;

        region = DB_REGIONS.find((r: DataRegion) => r.id === regionId);
        if (!region || !map) return;

        display_tab = undefined;
        geoData = null;
        loading = "data for " + region.name;

        try {
            // Fetch and load GeoJSON
            const response = await fetch(region.geojson);
            geoData = await response.json() as GeoPrioritization;

            display_rt = geoData.features.some(
                (feature:Feature) => feature.properties?.speed_avg,
            );

            // Set criteria base values
            action_modal_data_open = false;
            action_modal_details_open = false;
            criteria_hour = 8;
            criteria_n_lanes_direction = 2;
            criteria_bus_frequency = geoData.metadata.data_census.frequency.median;
            criteria_avg_speed = Math.floor(geoData.metadata.data_census.speed_avg?.median ?? 0);
            criteria_bus_frequency_enabled = true;
            criteria_n_lanes_direction_enabled = true;
            criteria_avg_speed_enabled = display_rt;

            // Update display_tab option to trigger rendering
            display_tab = DisplayOptions.PRIORITIZATION;            

            console.log("Loaded GeoJSON for region:", region.id);
        } catch (error) {
            console.error("Error loading GeoJSON:", error);
        } finally {
            loading = undefined;
        }
    };
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
    <!-- Title -->
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
                    onclick={(e) => {
                        e.preventDefault();
                        action_modal_about_open = !action_modal_about_open;
                    }}
                    data-tooltip="About"
                    data-placement="right"
                    aria-label="About"
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

    <!-- Form 1: Select region -->
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
                onchange={handleRegionChange}
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

    <!-- Form 2: Region display options -->
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
                    style="margin-left: 1rem; margin-right: 0.3rem;"
                    onclick={(e) => {
                        e.preventDefault();
                        action_modal_data_open = !action_modal_data_open;
                    }}
                    data-tooltip="Attribute table"
                    data-placement="bottom"
                    aria-label="Attribute table"
                >
                    <i class="fas fa-table"></i>
                </a>
                <a
                    href="#"
                    class="text-secondary"
                    style="margin-right: 0.3rem;"
                    onclick={(e) => {
                        e.preventDefault();
                        action_modal_details_open = !action_modal_details_open;
                    }}
                    data-tooltip="Details"
                    data-placement="bottom"
                    aria-label="Details"
                >
                    <i class="fas fa-code"></i>
                </a>
                <a 
                    href={region.geojson} 
                    target="_blank"
                    class="text-secondary"
                    data-tooltip="Download raw data"
                    data-placement="bottom"
                    aria-label="Download raw data"
                >
                    <i class="fas fa-download"></i>
                </a>
            </p>

            <p class="small text-primary">Explore the different layers below</p>
            <details
                name={DisplayOptions.PRIORITIZATION.toString()}
                open={display_tab === DisplayOptions.PRIORITIZATION ? true : undefined}
            >
                <summary
                    onclick={(e) => {
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
                        prioritization criteria: <span data-tooltip="Frequency and speed initially set to median values"><i class="fa fa-circle-info"></i></span>
                    </p>
                    <ul>
                        <li>
                            <input
                                type="checkbox"
                                aria-label="Enable frequency criteria"
                                bind:checked={criteria_bus_frequency_enabled}
                                style="margin-right: 0.35rem;"
                            />
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
                                disabled={!criteria_bus_frequency_enabled}
                            />:00 hour with <input
                                type="number"
                                name="number"
                                placeholder="Nr"
                                aria-label="Nr"
                                style="width: 5rem;"
                                bind:value={criteria_bus_frequency}
                                min="1"
                                disabled={!criteria_bus_frequency_enabled}
                            /> or + buses/hour
                        </li>
                        <li>
                            <input
                                type="checkbox"
                                aria-label="Enable lanes criteria"
                                bind:checked={criteria_n_lanes_direction_enabled}
                                style="margin-right: 0.35rem;"
                            />
                            <input
                                type="number"
                                name="number"
                                placeholder="Nr"
                                aria-label="Nr"
                                style="width: 5rem;"
                                bind:value={criteria_n_lanes_direction}
                                min="1"
                                disabled={!criteria_n_lanes_direction_enabled}
                            /> or + lanes/direction
                        </li>
                        {#if display_rt}
                        <li>
                            <input
                                type="checkbox"
                                aria-label="Enable speed criteria"
                                bind:checked={criteria_avg_speed_enabled}
                                style="margin-right: 0.35rem;"
                            />
                            <input 
                                type="number"
                                name="number"
                                placeholder="Nr"
                                aria-label="Nr"
                                style="width: 5rem;"
                                bind:value={criteria_avg_speed}
                                min="0"
                                disabled={!criteria_avg_speed_enabled}
                            /> or - km/h average commercial speed
                        </li>
                        {/if}
                    </ul>
                </div>
            </details>

            <details
                name={DisplayOptions.BUS_LANES.toString()}
                open={display_tab === DisplayOptions.BUS_LANES ? true : undefined}
            >
                <summary
                    onclick={(e) => {
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
                name={DisplayOptions.FREQUENCY.toString()}
                open={display_tab === DisplayOptions.FREQUENCY ? true : undefined}
            >
                <summary
                    onclick={(e) => {
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
                            >lowest ({geoData.metadata.data_census.frequency_hour[criteria_hour].min})</span
                        >
                        to the
                        <span
                            style="color: {COLOR_GRADIENT[
                                COLOR_GRADIENT.length - 1
                            ]}; font-weight: bold;"
                            >highest ({geoData.metadata.data_census.frequency_hour[criteria_hour].max})</span
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

                {#if geoData.metadata.data_census.frequency_hour[criteria_hour]}
                    <DataCensusTable census={geoData.metadata.data_census.frequency_hour[criteria_hour]} />
                {/if}
            </details>

            <details
                name={DisplayOptions.N_LANES.toString()}
                open={display_tab === DisplayOptions.N_LANES ? true : undefined}
            >
                <summary
                    onclick={(e) => {
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
                        >lowest ({geoData.metadata.data_census.lanes.min})</span
                    >
                    to the
                    <span
                        style="color: {COLOR_GRADIENT[
                            COLOR_GRADIENT.length - 1
                        ]}; font-weight: bold;"
                        >highest ({geoData.metadata.data_census.lanes.max})</span
                    > number of lanes per direction.
                </div>

                {#if geoData.metadata.data_census.lanes}
                    <DataCensusTable census={geoData.metadata.data_census.lanes} />
                {/if}
            </details>

            {#if display_rt}
            <details
                name={DisplayOptions.RT_SPEED.toString()}
                open={display_tab === DisplayOptions.RT_SPEED ? true: undefined}
            >
                <summary
                    onclick={(e) => {
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
                        style="color: {COLOR_GRADIENT_RED.slice().reverse()[0]}; font-weight: bold;"
                        >lowest ({geoData.metadata.data_census.speed_avg?.min?.toFixed(2)})</span
                    >
                    to the
                    <span
                        style="padding: 0 4px; background-color: #00000080; color: {COLOR_GRADIENT_RED.slice().reverse()[
                            COLOR_GRADIENT_RED.length - 1
                        ]}; font-weight: bold;border-radius: 4px;"
                        >highest ({geoData.metadata.data_census.speed_avg?.max?.toFixed(2)})</span
                    > values (km/h).
                </div>

                {#if geoData.metadata.data_census.speed_avg}
                    <DataCensusTable census={geoData.metadata.data_census.speed_avg} />
                {/if}
            </details>
            {/if}
        </div>
    {/if}

    <!-- Control buttons -->
    <div class="container-fluid" role="group">
        {#if region && region.geojson && geoData && geoData.metadata}
            <button
                class="secondary outline"
                id="clear-region"
                onclick={() => {
                    region = undefined;
                    display_tab = undefined;
                }}
            >
                <i class="fa-solid fa-arrow-left"></i> Change source
            </button>
            <button
                class="secondary outline"
                id="toggle-form"
                onclick={() => (action_hide_form = !action_hide_form)}
            >
                {@html !action_hide_form
                    ? '<i class="fa-solid fa-map"></i> Expand map'
                    : '<i class="fa-solid fa-sliders"></i> Layers'}
            </button>
        {/if}
        <button
            class="secondary outline"
            id="toggle-color"
            onclick={() => {light_mode = !light_mode}}
        >
            {@html light_mode
                ? '<i class="fa-solid fa-circle-half-stroke"></i> Dark mode'
                : '<i class="fa-solid fa-circle-half-stroke"></i> Light mode'}
        </button>
    </div>
</div>

<!-- Map caption -->
<div id="caption" class="overflow-auto">
    {#if display_tab === DisplayOptions.PRIORITIZATION}
        <p>
            <span
                class="caption-square"
                style="background-color: {COLOR_YELLOW}"
            ></span><b>Bus lane</b> with 
                - {criteria_bus_frequency} bus/h 
                OR - {criteria_n_lanes_direction} lane/dir
                {#if display_rt}OR {criteria_avg_speed} or - km/h avg. speed{/if}
        </p>
        <p>
            <span class="caption-square" style="background-color: {COLOR_TEAL}"
            ></span><b>Bus lane</b> with 
                + {criteria_bus_frequency-1} bus/h 
                AND + {criteria_n_lanes_direction-1} lane/dir
                {#if display_rt}AND + {criteria_avg_speed} km/h avg. speed{/if}
        </p>
        <p>
            <span class="caption-square" style="background-color: {COLOR_RED}"
            ></span><b>NO bus lane</b> with + {criteria_bus_frequency-1} bus/h AND
            + {criteria_n_lanes_direction-1} lane/dir
            {#if display_rt} AND {criteria_avg_speed} or - km/h avg. speed{/if}
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
                    >{geoData?.metadata.data_census.frequency_hour[criteria_hour]?.min}</span
                >
                <div
                    style="flex: 1; height: 1.5em; background: linear-gradient(to right, {COLOR_GRADIENT.map(
                        (c) => c,
                    ).join(', ')}); border-radius: 4px; border: 1px solid #ccc;"
                ></div>
                <span
                    style="min-width: 40px; text-align: left; font-size: 0.85rem;"
                    >{geoData?.metadata.data_census.frequency_hour[criteria_hour]?.max}</span
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
                    >{geoData?.metadata.data_census.lanes?.min}</span
                >
                <div
                    style="flex: 1; height: 1.5em; background: linear-gradient(to right, {COLOR_GRADIENT.map(
                        (c) => c,
                    ).join(', ')}); border-radius: 4px; border: 1px solid #ccc;"
                ></div>
                <span
                    style="min-width: 40px; text-align: left; font-size: 0.85rem;"
                    >{geoData?.metadata.data_census.lanes?.max}</span
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
                    >{geoData?.metadata.data_census.speed_avg?.min && Math.floor(geoData.metadata.data_census.speed_avg.min)}</span
                >
                <div
                    style="flex: 1; height: 1.5em; background: linear-gradient(to right, {COLOR_GRADIENT_RED.slice().reverse().map(
                        (c) => c,
                    ).join(', ')}); border-radius: 4px; border: 1px solid #ccc;"
                ></div>
                <span
                    style="min-width: 40px; text-align: left; font-size: 0.85rem;"
                    >{geoData?.metadata.data_census.speed_avg?.max && Math.ceil(geoData.metadata.data_census.speed_avg.max)}</span
                >
            </div>
        </div>
    {/if}
</div>

<!-- Map layers -->
{#if region && geoData && display_tab !== undefined && map}
    {#if display_tab === DisplayOptions.PRIORITIZATION}
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
            onLayerCreate={handleLayerCreate}
        />
    {:else if display_tab === DisplayOptions.BUS_LANES}
        <LayerBusLanes 
            {map} 
            {geoData} 
            criteriaHour={criteria_hour}
            onLayerCreate={handleLayerCreate} 
        />
    {:else if display_tab === DisplayOptions.FREQUENCY}
        <LayerTransitFrequency
            {map}
            {geoData}
            criteriaHour={criteria_hour}
            onLayerCreate={handleLayerCreate}
        />
    {:else if display_tab === DisplayOptions.N_LANES}
        <LayerNumberOfLanes 
            {map} 
            {geoData}
            criteriaHour={criteria_hour}
            onLayerCreate={handleLayerCreate} 
        />
    {:else if display_tab === DisplayOptions.RT_SPEED}
        <LayerRTSpeed 
            {map} 
            {geoData} 
            criteriaHour={criteria_hour}
            onLayerCreate={handleLayerCreate} 
        />
    {/if}
{/if}

<!-- Modals -->
<ModalAbout bind:open={action_modal_about_open} />

{#if geoData && geoData.metadata!==undefined}
<ModalData 
    open={action_modal_data_open} 
    geoData={geoData} 
    hour={criteria_hour}    
    rt_data={display_rt}
/>
<ModalDetails 
    open={action_modal_details_open} 
    geoData={geoData} 
/>
{/if}


<style>
    @import "./dashboard.css";
</style>