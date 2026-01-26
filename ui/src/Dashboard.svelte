<script lang="ts">
    import { untrack } from "svelte";

    import * as L from "leaflet";

    import { basemapTheme } from "./lib/theme";

    import { DB_REGIONS } from "./data";
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
                        color: "#DAD887",
                        weight: 2.5,
                    };
                } else if (
                    properties.is_bus_lane &&
                    properties.frequency >= criteria_bus_frequency &&
                    properties.n_lanes !== undefined &&
                    properties.n_lanes_direction >= criteria_n_lanes_direction
                ) {
                    return {
                        color: "#3BC1A8",
                        weight: 2.5,
                    };
                } else if (
                    !properties.is_bus_lane &&
                    properties.frequency >= criteria_bus_frequency &&
                    properties.n_lanes !== undefined &&
                    properties.n_lanes_direction >= criteria_n_lanes_direction
                ) {
                    return {
                        color: "#F63049",
                        weight: 2.5,
                    };
                }

                return {
                    color: "#e6e6e6",
                    weight: 1.5,
                };
            },
            onEachFeature: function (feature, layer) {
                let properties = feature.properties;
                // console.log(date, hour, operator, properties);
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
            },
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
            <details name="example" open>
                <summary>Bus lane prioritization</summary>
                <div class="small">
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

            <details name="example">
                <summary>Bus lanes</summary>
                Bus lanes are shown in
                <span style="color: #3BC1A8; font-weight: bold;">teal</span>.
            </details>

            <details name="example">
                <summary>Transit frequency</summary>
                Lanes with transit frequency are display_tabed, colored by frequency:
                <ul>
                    <li>
                        <span style="color: #DAD887; font-weight: bold;"
                            >Low frequency</span
                        >: less than 5 bus services per hour
                    </li>
                    <li>
                        <span style="color: #F63049; font-weight: bold;"
                            >High frequency</span
                        >: 5 or more bus services per hour
                    </li>
                </ul>
            </details>

            <details name="example">
                <summary>Number of lanes</summary>
                Lanes are styled differently based on the number of lanes in the
                direction of travel:
                <ul>
                    <li>
                        <span style="font-weight: bold;">Single lane</span>:
                        only one lane in the direction of travel
                    </li>
                    <li>
                        <span style="font-weight: bold;">Multiple lanes</span>:
                        more than one lane in the direction of travel
                    </li>
                </ul>
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
