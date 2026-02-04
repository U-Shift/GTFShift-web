<script lang="ts">
    import './ModalData.css';
    
    import { untrack } from "svelte";
    import type { Feature, FeatureCollection } from "geojson";
    import { TableHandler, Datatable, ThSort } from "@vincjo/datatables";


    let {
        open,
        geoData,
        hour,
        rt_data,
    }: {
        open: boolean;
        geoData: FeatureCollection | null;
        hour: number;
        rt_data: boolean;
    } = $props();

    let data_filtered = $state<Feature<any>[]>([]);
    let table = $state<TableHandler<any>>(
        new TableHandler(data_filtered, {
            rowsPerPage: 10,
            i18n: {
                // Characters
                previous: "<",
                next: ">",
                rowCount: "{start} to {end}, of {total} entries",
            },
        }),
    );

    $effect(() => {
        if (geoData) {
            // Extract properties from features
            data_filtered = (geoData as FeatureCollection).features
                .filter((feature) => {
                    const featureHour = feature.properties?.hour;
                    return featureHour === hour;
                })
                .map((f) => f.properties);
        } else {
            data_filtered = [];
        }

        untrack(() => {
            table.setRows([...data_filtered]);
        });
    });
</script>

<style>
    .svelte-simple-datatable button {
        white-space: nowrap !important;
    }

    @media (min-width: 768px) {
        dialog > article {
            max-width: 95vw!important;
        }
    }
</style>

<main>
    <dialog {open} id="modal-about" class={open ? "" : "hidden"}>
        <article>
            <header>
                <h4>
                    <strong
                        ><i class="fas fa-table"></i> Attribute table (at {hour}:00)</strong
                    >
                </h4>
            </header>
            <main>
            {#if table}
                <Datatable basic {table}>
                    <table>
                        <thead>
                            <tr>
                                <ThSort {table} field="way_osm_id"
                                    >OSM ID</ThSort
                                >
                                <ThSort {table} field="frequency"
                                    >Frequency</ThSort
                                >
                                <ThSort {table} field="is_bus_lane"
                                    >Bus Lane</ThSort
                                >
                                <ThSort {table} field="n_lanes">Nr lanes</ThSort
                                >
                                <ThSort {table} field="n_directions"
                                    >Nr directions</ThSort
                                >
                                <ThSort {table} field="n_lanes_direction"
                                    >Nr lanes/dir</ThSort
                                >
                                {#if rt_data}
                                    <ThSort {table} field="speed_avg"
                                        >Avg speed</ThSort
                                    >
                                    <ThSort {table} field="speed_p25"
                                        >Speed P25</ThSort
                                    >
                                    <ThSort {table} field="speed_median"
                                        >Speed Median</ThSort
                                    >
                                    <ThSort {table} field="speed_p75"
                                        >Speed P75</ThSort
                                    >
                                    <ThSort {table} field="speed_count"
                                        >Speed Count</ThSort
                                    >
                                {/if}
                                <ThSort {table} field="route_names">Routes</ThSort>
                            </tr>
                        </thead>
                        <tbody>
                            {#each table.rows as row}
                                <tr>
                                    <td>
                                        <a
                                            href="https://www.openstreetmap.org/way/{row.way_osm_id}"
                                            target="_blank">{row.way_osm_id}</a
                                        >
                                    </td>
                                    <td>{row.frequency}</td>
                                    <td>{row.is_bus_lane}</td>
                                    <td>{row.n_lanes}</td>
                                    <td>{row.n_directions}</td>
                                    <td>{row.n_lanes_direction}</td>
                                    {#if rt_data}
                                        <td>{row.speed_avg && !isNaN(row.speed_avg) ? row.speed_avg?.toFixed(2) : "-"}</td>
                                        <td>{row.speed_p25 && !isNaN(row.speed_p25) ? row.speed_p25?.toFixed(2) : "-"}</td>
                                        <td>{row.speed_median && !isNaN(row.speed_median) ? row.speed_median?.toFixed(2) : "-"}</td>
                                        <td>{row.speed_p75 && !isNaN(row.speed_p75) ? row.speed_p75?.toFixed(2) : "-"}</td>
                                        <td>{row.speed_count && !isNaN(row.speed_count) ? row.speed_count : "-"}</td>  
                                    {/if}
                                    <td>{row.route_names}</td>
                                </tr>
                            {/each}
                        </tbody>
                    </table>
                </Datatable>
            {/if}
            </main>

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

