<script lang="ts">
    import type { GeoPrioritization } from "../types/GeoPrioritization";

    import hljs from 'highlight.js/lib/core';
    import r from 'highlight.js/lib/languages/r';
    // import 'highlight.js/styles/base16/atelier-cave-light.css';
    // import 'highlight.js/styles/github.css';
    import 'highlight.js/styles/a11y-light.css';

    // Then register the languages you need
    hljs.registerLanguage('r', r);

    let {
        open,
        geoData,
        rt_data,
    }: {
        open: boolean;
        geoData: GeoPrioritization | null;
        rt_data: boolean;
    } = $props();
</script>

<style>
    code {
        width: 100%; 
        padding: 0 1rem;
    }

    kbd {
        background-color: #f3f4f6;
        color: #646b79;
    }
</style>


<main>
    <dialog {open} id="modal-about" class={open ? "" : "hidden"}>
        <article>
            <header>
                <h4>
                    <strong
                        ><i class="fas fa-code"></i> Details</strong
                    >
                </h4>
            </header>

            <h6>Technical sheet</h6>
            {#if geoData}
            <table>
                <tbody>
                    <tr>
                        <th>City</th>
                        <td><kbd>{geoData.metadata.region}</kbd></td>
                    </tr>
                    <tr>
                        <th>GTFS file</th>
                        <td><kbd><a href={geoData.metadata.gtfs_source} target="_blank">{geoData.metadata.gtfs_source.split("/").pop()}</a></kbd></td>
                    </tr>
                    <tr>
                        <th>Transit services for day¹</th>
                        <td><kbd>{geoData.metadata.gtfs_date}</kbd></td>
                    </tr>
                    <tr>
                        <th>Routes considered²</th>
                        <td><kbd>{geoData.metadata.routes_covered} of {geoData.metadata.routes_total} ({((geoData.metadata.routes_covered / geoData.metadata.routes_total) * 100).toFixed(2)}%)</kbd></td>
                    </tr>
                    <tr>
                        <th>Routes missing²</th>
                        <td>{@html geoData.metadata.routes_missing.split(";").map((r) => `<kbd style="background-color: #f3f4f6; color: #646b79;">${r}</kbd>`).join(" ")}</td>
                    </tr>
                    <tr>
                        <th>OSM query</th>
                        <td>{@html geoData.metadata.osm_query.map(q => `<kbd style="background-color: #f3f4f6; color: #646b79;">${q.key}=${q.value}</kbd>`).join(" ")}</td>
                    </tr>
                    <tr>
                        <th>Real-time data</th>
                        <td><kbd><a href={geoData.metadata.rt_data_url} target="_blank">{geoData.metadata.rt_data_url.split("/").pop()}</a></kbd></td>
                    </tr>
                    <tr>
                        <th>Real-time data interval</th>
                        <td><kbd>{geoData.metadata.rt_interval}</kbd></td>
                    </tr>
                    <tr>
                        <th>Real-time stop buffer³</th>
                        <td><kbd>{geoData.metadata.stop_buffer_size_meters} meters</kbd></td>
                    </tr>
                    <tr>
                        <th>Running environment</th>
                        <td><kbd>GTFShift {geoData.metadata.gtfshift_version}</kbd> <kbd>{geoData.metadata.r_version}</kbd></td>
                    </tr>
                </tbody>
            </table>
            {/if}

            <div id="table-notes" style="line-height: 1;">
                <small>
                    ¹ Transit frequency computed for representative day
                </small>
                <br/><br/>
                <small>
                    ² <kbd><a href="https://u-shift.github.io/GTFShift/reference/prioritize_lanes.html" target="_blank">GTFShift::prioritize_lanes()</a></kbd>
                    uses <kbd><a href="https://u-shift.github.io/GTFShift/reference/get_way_frequency_hourly.html" target="_blank">GTFShift::get_way_frequency_hourly()</a></kbd> to match routes with OSM ways, which requires that the OSM relation mapping is well defined for the transit routes. Routes that do not have an OSM match are ignored.
                </small>
                <br/><br/>
                <small>
                    ³ Real-time data points within this distance from a bus stop are ignored for commercial speed calculations.
                </small>    
            </div>

            <h6 style="margin-bottom: 0;">Code</h6>
            <small style="margin-bottom: 1rem; display: block;">Adapted from <a href="https://u-shift.github.io/GTFShift/articles/prioritize.html" target="_blank">GTFShift/Prioritize bus lane implementation</a></small>

            {#if geoData}
            <pre><code>
                {@html (hljs.highlight(`
library(GTFShift)
library(tidytransit)
library(osmdata)
library(sf)

# Prioritize based on planned operation and infrastructure characteristics
gtfs = GTFShift::load_feed(${geoData.metadata.gtfs_source}, create_transfers=FALSE)
osm_q = opq(bbox=sf::st_bbox(tidytransit::shapes_as_sf(gtfs$shapes)))  |>
  ${geoData.metadata.osm_query.map(q => `add_osm_feature(key = "${q.key}", value = "${q.value}", key_exact = ${q.key_exact ? "TRUE" : "FALSE"})`).join(" |> \n  ")} |> 

lane_prioritization = prioritize_lanes(gtfs, osm_q)

# Extend with real-time data (filtered to avoid points at bus stops)
rt_collection <- read.csv(${geoData.metadata.rt_data_url}) |> sf::st_as_sf(coords = c("longitude", "latitude"), crs = 4326)

gtfs_stops = tidytransit::stops_as_sf(gtfs$stops, crs=4326)
gtfs_stops_buffered = sf::st_buffer(sf::st_transform(gtfs_stops, 3857), ${geoData.metadata.stop_buffer_size_meters}) |> sf::st_transform(4326)
rt_collection_filtered = rt_collection[!sf::st_intersects(rt_collection, gtfs_stops_buffered, sparse = FALSE), ]

lane_prioritization <- GTFShift::rt_extend_prioritization(
  lane_prioritization = lane_prioritization,
  rt_collection = rt_collection_filtered
)
`,
                    { language: 'r' }
                    ).value)
                }
            </code></pre>
            {/if}

            <footer>
                <div role="group">
                    <button
                        class="secondary outline modal-close"
                        on:click={() => (open = false)}>Go back</button
                    >
                </div>
            </footer>
        </article>
    </dialog>
</main>