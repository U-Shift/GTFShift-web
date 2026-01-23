<script>
    import { basemapTheme } from "./lib/theme";

    import { DB_REGIONS } from "./data";

    export let map;

    let currentLayer = null;

    const toggleTheme = () => {
        basemapTheme.update((t) => (t === "light" ? "dark" : "light"));
    };

    const handleRegionChange = async (event) => {
        const regionName = event.target.value;

        if (!regionName) return;

        const region = DB_REGIONS.find((r) => r.name === regionName);
        if (!region || !map) return;

        // Remove previous layer
        if (currentLayer) {
            map.removeLayer(currentLayer);
            currentLayer = null;
        }

        try {
            // Fetch and load GeoJSON
            const response = await fetch(region.geojson);
            const geoData = await response.json();

            // Filter for hour==8
            geoData.features = geoData.features.filter(
                (feature) => feature.properties.hour === 8,
            );

            console.log("Loaded GeoJSON for region:", regionName, geoData);

            // Create and add new layer to map
            currentLayer = L.geoJSON(geoData, {
                style: (feature) => {
                    let properties = feature.properties;

                    if (
                        properties.is_bus_lane &&
                        (properties.frequency < 5 ||
                            properties.n_lanes === undefined ||
                            properties.n_lanes_direction <= 1)
                    ) {
                        return {
                            color: "#DAD887",
                            weight: 2.5,
                        };
                    } else if (
                        properties.is_bus_lane &&
                        properties.frequency >= 5 &&
                        properties.n_lanes !== undefined &&
                        properties.n_lanes_direction > 1
                    ) {
                        return {
                            color: "#3BC1A8",
                            weight: 2.5,
                        };
                    } else if (
                        !properties.is_bus_lane &&
                        properties.frequency >= 5 &&
                        properties.n_lanes !== undefined &&
                        properties.n_lanes_direction > 1
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
            // Zoom to layer
            map.fitBounds(currentLayer.getBounds());
        } catch (error) {
            console.error("Error loading GeoJSON:", error);
        }
    };
</script>

<svelte:head>
    <link
        rel="stylesheet"
        href="https://cdn.jsdelivr.net/npm/@picocss/pico/css/pico.min.css"
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
    </div>

    <div class="container-fluid">
        <select
            name="region"
            aria-label="Select region"
            required
            on:change={handleRegionChange}
        >
            <option selected disabled value=""> Select region </option>
            {#each DB_REGIONS as region}
                <option>{region.name}</option>
            {/each}
        </select>
    </div>

    <div class="container-fluid" role="group">
        <button
            class="secondary outline small"
            id="toggle-color"
            on:click={toggleTheme}
        >
            {@html $basemapTheme === "light"
                ? '<i class="fa-solid fa-circle-half-stroke"></i> Dark mode'
                : '<i class="fa-solid fa-circle-half-stroke"></i> Light mode'}
        </button>
        <button class="secondary outline small" id="toggle-detail"></button>
    </div>
</main>

<style>
    @import "./dashboard.css";
</style>
