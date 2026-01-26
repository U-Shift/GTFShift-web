<script lang="ts">
    import { untrack } from "svelte";

    import * as L from "leaflet";

    import { basemapTheme } from "./lib/theme";

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
        PRIORIZATION,
        BUS_LANES,
        FREQUENCY,
        N_LANES,
    }

    let region: DATA_REGION | undefined = $state(undefined);
    let display_tab: DisplayOptions | undefined = $state(undefined);
    let criteria_hour: number = $state(8);
    let criteria_bus_frequency: number = $state(5);
    let criteria_n_lanes_direction: number = $state(2);

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
        loading = "data for " + region.name;

        try {
            // Fetch and load GeoJSON
            const response = await fetch(region.geojson);
            geoData = await response.json();
            // Update display_tab option to trigger rendering
            display_tab = DisplayOptions.PRIORIZATION;

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
            (display_tab as DisplayOptions) === DisplayOptions.PRIORIZATION
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

        // Create and add new layer to map (untrack to prevent triggering effect)
        const newLayer = L.geoJSON(filteredFeatures, {
            style: (feature) => {
                let properties = feature.properties;
                let freq = properties.frequency || 0;
                let colorIndex = Math.min(
                    COLOR_GRADIENT.length - 1,
                    Math.floor(freq / 5),
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

        // Create and add new layer to map (untrack to prevent triggering effect)
        const newLayer = L.geoJSON(uniqueFeatures, {
            style: (feature) => {
                let properties = feature.properties;
                let n_lanes_direction = properties.n_lanes_direction || 0;
                let colorIndex = Math.min(
                    COLOR_GRADIENT.length - 1,
                    Math.floor(n_lanes_direction / 2),
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

<main id="controls-panel" class="overflow-auto">
    <div class="container-fluid" style="text-align: left;">
        <h3
            style="margin: 0; margin-bottom: 0.5rem; color: #363636; text-align: left;"
        >
            GTFShift
        </h3>
        <p>Bus lane prioritization tool</p>
        {#if loading}
            <p class="small text-secondary" aria-busy="true">
                Loading {loading}...
            </p>
        {/if}
    </div>

    {#if region === undefined}
        <div class="container-fluid text-left">
            <h5 style="margin-bottom: 0.5rem;">Data source</h5>
            <p class="small text-secondary">
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

    {#if region !== undefined && geoData}
        <div class="container-fluid text-left">
            <h5 style="margin-bottom: 0.5rem;">{region.name}</h5>
            <p class="small text-secondary mb-0">
                Data for {region.date}
            </p>
            <p class="small text-secondary">
                Explore the different layers below
            </p>
            <details
                name={DisplayOptions.PRIORIZATION}
                open={display_tab === DisplayOptions.PRIORIZATION
                    ? "true"
                    : undefined}
            >
                <summary
                    on:click={(e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        display_tab =
                            display_tab === DisplayOptions.PRIORIZATION
                                ? undefined
                                : DisplayOptions.PRIORIZATION;
                    }}>Bus lane prioritization</summary
                >
                <div class="small text-secondary">
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
                            >lowest</span
                        >
                        to the
                        <span
                            style="color: {COLOR_GRADIENT[
                                COLOR_GRADIENT.length - 1
                            ]}; font-weight: bold;">highest</span
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
                        >lowest</span
                    >
                    to the
                    <span
                        style="color: {COLOR_GRADIENT[
                            COLOR_GRADIENT.length - 1
                        ]}; font-weight: bold;">highest</span
                    > number of lanes per direction.
                </div>
            </details>
        </div>
    {/if}

    <hr />

    <div class="container-fluid" role="group">
        {#if region && region.geojson && geoData}
            <button
                class="secondary outline small"
                id="clear-region"
                on:click={() => (region = undefined)}
            >
                <i class="fa-solid fa-arrow-left"></i> Go back
            </button>
            <button
                class="secondary outline small"
                id="download-data"
                on:click={() => window.open(region.geojson, "_blank")}
            >
                <i class="fa-solid fa-download"></i> Raw data
            </button>
        {/if}
        <button
            class="secondary outline small"
            id="toggle-color"
            on:click={toggleTheme}
        >
            {@html $basemapTheme === "light"
                ? '<i class="fa-solid fa-circle-half-stroke"></i> Dark mode'
                : '<i class="fa-solid fa-circle-half-stroke"></i> Light mode'}
        </button>
    </div>
</main>

<style>
    @import "./dashboard.css";
</style>
