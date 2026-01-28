<script lang="ts">
    import { untrack } from "svelte";

    import * as L from "leaflet";

    import { basemapTheme } from "./lib/theme";

    import ModalAbout from "./modals/ModalAbout.svelte";

    import {
        DB_REGIONS,
        COLOR_YELLOW,
        COLOR_TEAL,
        COLOR_RED,
        COLOR_GRAY,
        COLOR_GRADIENT,
    } from "./data";
    import type { DATA_REGION } from "./data";

    // Map
    let { map }: { map: L.Map } = $props();
    let currentLayer: L.Layer | null = $state(null);
    let geoData: any = $state(null);

    // User feedback
    let loading: string | undefined = $state(undefined);

    // Dashboard state
    enum DisplayOptions {
        PRIORITIZATION,
        BUS_LANES,
        FREQUENCY,
        N_LANES,
    }

    let region: DATA_REGION | undefined = $state(undefined);

    let display_tab: DisplayOptions | undefined = $state(undefined);
    let display_hide_form: boolean = $state(false);

    let criteria_hour: number = $state(8);
    let criteria_bus_frequency: number = $state(5);
    let criteria_n_lanes_direction: number = $state(2);

    let display_data_min: number | undefined = $state(undefined);
    let display_data_max: number | undefined = $state(undefined);

    let modal_about_open: boolean = $state(false);

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
            geoData = await response.json();
            // Update display_tab option to trigger rendering
            display_tab = DisplayOptions.PRIORITIZATION;

            console.log("Loaded GeoJSON for region:", region.id);
        } catch (error) {
            console.error("Error loading GeoJSON:", error);
        } finally {
            loading = undefined;
        }
    };

    // Display
    $effect(() => {
        console.log("Display criteria changed, updating layer...");

        // Render new one
        if (
            geoData &&
            display_tab !== undefined &&
            criteria_bus_frequency !== undefined &&
            (display_tab as DisplayOptions) === DisplayOptions.PRIORITIZATION
        ) {
            render_bus_lane_prioritization();
        } else if (
            geoData &&
            display_tab !== undefined &&
            (display_tab as DisplayOptions) === DisplayOptions.BUS_LANES
        ) {
            render_bus_lane();
        } else if (
            geoData &&
            display_tab !== undefined &&
            (display_tab as DisplayOptions) === DisplayOptions.FREQUENCY
        ) {
            render_transit_frequency();
        } else if (
            geoData &&
            display_tab !== undefined &&
            (display_tab as DisplayOptions) === DisplayOptions.N_LANES
        ) {
            render_nr_lanes();
        } else {
            console.warn("Display option not implemented yet");
        }

        // Clean up (before next effect run)
        return () => {
            if (currentLayer) {
                map.removeLayer(currentLayer);
                currentLayer = null;
            }
        };
    });

    const feature_popUp = (feature: any, layer: L.Layer) => {
        let properties = feature.properties;
        layer.bindPopup(`
            <h6>Way ${properties.way_osm_id}</h6>
            <dl>
                <dt>Bus services/hour</dt>
                <dd><b>${properties.frequency}</b></dd>
                <dt>Is bus lane?</dt>
                <dd><b>${properties.is_bus_lane ? "Yes" : "No"}</b></dd>
                <dt>Total lanes</dt>
                <dd><b>${properties.n_lanes ?? "N/A"}</b></dd>
                <dt>Nr directions</dt>
                <dd><b>${properties.n_directions ?? "N/A"}</b></dd>
                <dt>Lanes in direction</dt>
                <dd><b>${properties.n_lanes_direction ?? "N/A"}</b></dd>
                <dt>OSM Way <i class="fa-solid fa-arrow-up-right-from-square"></i></dt>
                <dd><a href="https://www.openstreetmap.org/way/${properties.way_osm_id}" target="_blank">${properties.way_osm_id}</a></dd>
            </dl>
        `);
    };

    const render_bus_lane_prioritization = () => {
        if (!map || !geoData) return;

        // Filter for hour==criteria_hour (create a copy, don't mutate original)
        const filteredFeatures = geoData.features.filter(
            (feature) =>
                feature.properties.hour === criteria_hour &&
                (feature.properties.is_bus_lane ||
                    (feature.properties.frequency &&
                        feature.properties.n_lanes_direction &&
                        feature.properties.frequency >=
                            criteria_bus_frequency &&
                        feature.properties.n_lanes_direction >=
                            criteria_n_lanes_direction)),
        );

        // Create and add new layer to map (untrack to prevent triggering effect)
        const newLayer = L.geoJSON(filteredFeatures, {
            style: (feature) => {
                let properties = feature.properties;

                if (
                    properties.is_bus_lane &&
                    (properties.frequency < criteria_bus_frequency ||
                        properties.n_lanes === undefined ||
                        properties.n_lanes_direction <
                            criteria_n_lanes_direction)
                ) {
                    return {
                        color: COLOR_YELLOW,
                        weight: 2.5,
                    };
                } else if (
                    properties.is_bus_lane &&
                    properties.frequency >= criteria_bus_frequency &&
                    properties.n_lanes !== undefined &&
                    properties.n_lanes_direction >= criteria_n_lanes_direction
                ) {
                    return {
                        color: COLOR_TEAL,
                        weight: 2.5,
                    };
                } else if (
                    !properties.is_bus_lane &&
                    properties.frequency >= criteria_bus_frequency &&
                    properties.n_lanes !== undefined &&
                    properties.n_lanes_direction >= criteria_n_lanes_direction
                ) {
                    return {
                        color: COLOR_RED,
                        weight: 2.5,
                    };
                }

                return {
                    color: COLOR_GRAY,
                    weight: 1.5,
                };
            },
            onEachFeature: feature_popUp,
        }).addTo(map);

        // Assign to state without tracking (prevents infinite loop)
        untrack(() => {
            currentLayer = newLayer;
        });

        // Zoom to layer
        map.fitBounds(newLayer.getBounds());
    };

    const render_bus_lane = () => {
        if (!map || !geoData) return;

        // Filter for bus lanes
        const filteredFeatures = geoData.features.filter(
            (feature) => feature.properties.is_bus_lane,
        );
        // Make sure feature.properties.way_osm_id is unique (they repeat each hour)
        const uniqueFeatures = [];
        const seenWayIds = new Set();
        for (const feature of filteredFeatures) {
            if (!seenWayIds.has(feature.properties.way_osm_id)) {
                uniqueFeatures.push(feature);
                seenWayIds.add(feature.properties.way_osm_id);
            }
        }
        // Create and add new layer to map (untrack to prevent triggering effect)
        const newLayer = L.geoJSON(uniqueFeatures, {
            style: {
                color: COLOR_TEAL,
                weight: 2.5,
            },
            onEachFeature: feature_popUp,
        }).addTo(map);

        // Assign to state without tracking (prevents infinite loop)
        untrack(() => {
            currentLayer = newLayer;
        });

        // Zoom to layer
        map.fitBounds(newLayer.getBounds());
    };

    const render_transit_frequency = () => {
        if (!map || !geoData) return;

        // Filter for hour==criteria_hour (create a copy, don't mutate original)
        const filteredFeatures = geoData.features.filter(
            (feature) =>
                feature.properties.hour === criteria_hour &&
                feature.properties.frequency,
        );

        display_data_min = Math.min(
            ...filteredFeatures.map((f) => f.properties.frequency),
        );
        display_data_max = Math.max(
            ...filteredFeatures.map((f) => f.properties.frequency),
        );

        // Create and add new layer to map (untrack to prevent triggering effect)
        const newLayer = L.geoJSON(filteredFeatures, {
            style: (feature) => {
                let properties = feature.properties;
                let freq = properties.frequency || 0;
                let colorIndex = Math.min(
                    Math.ceil(
                        (freq * COLOR_GRADIENT.length) /
                            (display_data_max as number),
                    ),
                    COLOR_GRADIENT.length - 1,
                );
                return {
                    color: COLOR_GRADIENT[colorIndex],
                    weight: 2.5,
                };
            },
            onEachFeature: feature_popUp,
        }).addTo(map);

        // Assign to state without tracking (prevents infinite loop)
        untrack(() => {
            currentLayer = newLayer;
        });

        // Zoom to layer
        map.fitBounds(newLayer.getBounds());
    };

    const render_nr_lanes = () => {
        if (!map || !geoData) return;

        // Make sure feature.properties.way_osm_id is unique (they repeat each hour)
        const uniqueFeatures = [];
        const seenWayIds = new Set();
        for (const feature of geoData.features) {
            if (!seenWayIds.has(feature.properties.way_osm_id)) {
                uniqueFeatures.push(feature);
                seenWayIds.add(feature.properties.way_osm_id);
            }
        }

        display_data_min = Math.max(
            1,
            Math.min(
                ...uniqueFeatures.map(
                    (f) => f.properties.n_lanes_direction || 0,
                ),
            ),
        );
        display_data_max = Math.max(
            ...uniqueFeatures.map((f) => f.properties.n_lanes_direction || 0),
        );

        // Create and add new layer to map (untrack to prevent triggering effect)
        const newLayer = L.geoJSON(uniqueFeatures, {
            style: (feature) => {
                let properties = feature.properties;
                let n_lanes_direction = properties.n_lanes_direction || 0;
                let colorIndex = Math.min(
                    Math.ceil(
                        (n_lanes_direction * COLOR_GRADIENT.length) /
                            (display_data_max as number),
                    ),
                    COLOR_GRADIENT.length - 1,
                );
                return {
                    color: COLOR_GRADIENT[colorIndex],
                    weight: 2.5,
                };
            },
            onEachFeature: feature_popUp,
        }).addTo(map);

        // Assign to state without tracking (prevents infinite loop)
        untrack(() => {
            currentLayer = newLayer;
        });

        // Zoom to layer
        map.fitBounds(newLayer.getBounds());
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
                        modal_about_open = !modal_about_open;
                    }}
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

    {#if region !== undefined && geoData && !display_hide_form}
        <div class="container-fluid text-left" id="form">
            <h5 style="margin-bottom: 0.1rem;" class="text-primary">
                {region.name}
            </h5>
            <p class="small text-tertiary mb-0">
                Data for {region.date}
            </p>

            <p class="small text-primary">Explore the different layers below</p>
            <details
                name={DisplayOptions.PRIORITIZATION}
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
                                style="width: 4rem;"
                                bind:value={criteria_hour}
                                min="0"
                                max="23"
                            />:00 hour
                        </li>
                        <li>
                            <input
                                type="number"
                                name="number"
                                placeholder="Nr"
                                aria-label="Nr"
                                style="width: 4rem;"
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
                                style="width: 4rem;"
                                bind:value={criteria_n_lanes_direction}
                                min="1"
                            /> or + lanes/direction
                        </li>
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
                            style="padding: 0 4px; background-color: #0000001A; color: {COLOR_GRADIENT[0]}; font-weight: bold; border-radius: 4px;"
                            >lowest ({display_data_min})</span
                        >
                        to the
                        <span
                            style="color: {COLOR_GRADIENT[
                                COLOR_GRADIENT.length - 1
                            ]}; font-weight: bold;"
                            >highest ({display_data_max})</span
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
                                style="width: 4rem;"
                                bind:value={criteria_hour}
                                min="0"
                                max="23"
                            />:00 hour
                        </li>
                    </ul>
                </div>
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
                        style="padding: 0 4px; background-color: #0000001A; color: {COLOR_GRADIENT[0]}; font-weight: bold; border-radius: 4px;"
                        >lowest ({display_data_min})</span
                    >
                    to the
                    <span
                        style="color: {COLOR_GRADIENT[
                            COLOR_GRADIENT.length - 1
                        ]}; font-weight: bold;"
                        >highest ({display_data_max})</span
                    > number of lanes per direction.
                </div>
            </details>
        </div>
    {/if}

    <div class="container-fluid" role="group">
        {#if region && region.geojson && geoData}
            <button
                class="secondary outline"
                id="clear-region"
                on:click={() => {
                    region = undefined;
                    if (currentLayer) {
                        map.removeLayer(currentLayer);
                        currentLayer = null;
                    }
                }}
            >
                <i class="fa-solid fa-arrow-left"></i> Change source
            </button>
            <button
                class="secondary outline"
                id="toggle-form"
                on:click={() => (display_hide_form = !display_hide_form)}
            >
                {@html !display_hide_form
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
            ></span><b>Bus lane</b> with - {criteria_bus_frequency} bus/h OR - {criteria_n_lanes_direction}
            lane/dir
        </p>
        <p>
            <span class="caption-square" style="background-color: {COLOR_TEAL}"
            ></span><b>Bus lane</b> with {criteria_bus_frequency} or + bus/h AND {criteria_n_lanes_direction} or +
            lane/dir
        </p>
        <p>
            <span class="caption-square" style="background-color: {COLOR_RED}"
            ></span><b>NO bus lane</b> with {criteria_bus_frequency} or + bus/h AND
            {criteria_n_lanes_direction} or + lane/dir
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
                    >{display_data_min}</span
                >
                <div
                    style="flex: 1; height: 1.5em; background: linear-gradient(to right, {COLOR_GRADIENT.map(
                        (c) => c,
                    ).join(', ')}); border-radius: 4px; border: 1px solid #ccc;"
                ></div>
                <span
                    style="min-width: 40px; text-align: left; font-size: 0.85rem;"
                    >{display_data_max}</span
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
                    >{display_data_min}</span
                >
                <div
                    style="flex: 1; height: 1.5em; background: linear-gradient(to right, {COLOR_GRADIENT.map(
                        (c) => c,
                    ).join(', ')}); border-radius: 4px; border: 1px solid #ccc;"
                ></div>
                <span
                    style="min-width: 40px; text-align: left; font-size: 0.85rem;"
                    >{display_data_max}</span
                >
            </div>
        </div>
    {/if}
</div>

<ModalAbout bind:open={modal_about_open} />

<style>
    @import "./dashboard.css";
</style>
