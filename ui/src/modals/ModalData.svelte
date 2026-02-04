<script lang="ts">
    import './ModalData.css';
    
    import { untrack } from "svelte";
    import type { Feature, GeoJsonProperties } from "geojson";
    import { TableHandler, Datatable, ThSort } from "@vincjo/datatables";
    import type { GeoPrioritization } from '../types/GeoPrioritization';


    let {
        open,
        geoData,
        hour,
        rt_data,
    }: {
        open: boolean;
        geoData: GeoPrioritization;
        hour: number;
        rt_data: boolean;
    } = $props();

    let data_filtered = $state<Feature[]>([]);
    let table = $state<TableHandler<any> | null>(null);

    $effect(() => {
        if (geoData) {
            // Extract properties from features
            data_filtered = (geoData as GeoPrioritization).features
                .filter((feature) => {
                    const featureHour = feature.properties?.hour;
                    return featureHour === hour;
                })
                .map((f) => f);
        } 

        untrack(() => {
            if (data_filtered) {
                if (!table) {
                    table = new TableHandler([] as Feature[],{
                        rowsPerPage: 10,
                        i18n: {
                            // Characters
                            previous: "<",
                            next: ">",
                            rowCount: "{start} to {end}, of {total} entries",
                        },
                    });
                }
                table.setRows([...data_filtered]);
            }
        });
    });
</script>

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
                                    <ThSort {table} field={(r) => r.properties.way_osm_id}
                                        >OSM ID</ThSort
                                    >
                                    <ThSort {table} field={(r) => r.properties.frequency}
                                        >Frequency</ThSort
                                    >
                                    <ThSort {table} field={(r) => r.properties.is_bus_lane}
                                        >Bus Lane</ThSort
                                    >
                                    <ThSort {table} field={(r) => r.properties.n_lanes}
                                        >Nr lanes</ThSort
                                    >
                                    <ThSort {table} field={(r) => r.properties.n_directions}
                                        >Nr directions</ThSort
                                    >
                                    <ThSort {table} field={(r) => r.properties.n_lanes_direction}
                                        >Nr lanes/dir</ThSort
                                    >
                                    {#if rt_data}
                                        <ThSort {table} field={(r) => r.properties.speed_avg}
                                            >Avg speed</ThSort
                                        >
                                        <ThSort {table} field={(r) => r.properties.speed_p25}
                                            >Speed P25</ThSort
                                        >
                                        <ThSort {table} field={(r) => r.properties.speed_median}
                                            >Speed Median</ThSort
                                        >
                                        <ThSort {table} field={(r) => r.properties.speed_p75}
                                            >Speed P75</ThSort
                                        >
                                        <ThSort {table} field={(r) => r.properties.speed_count}
                                            >Speed Count</ThSort
                                        >
                                    {/if}
                                    <ThSort {table} field={(r) => r.properties.route_names}
                                        >Routes</ThSort
                                    >
                                </tr>
                            </thead>
                            <tbody>
                                {#each table.rows as row}
                                    <tr>
                                        <td>
                                            <a
                                                href="https://www.openstreetmap.org/way/{row.properties.way_osm_id}"
                                                target="_blank"
                                                >{row.properties.way_osm_id}</a
                                            >
                                        </td>
                                        <td>{row.properties.frequency}</td>
                                        <td>{row.properties.is_bus_lane}</td>
                                        <td>{row.properties.n_lanes}</td>
                                        <td>{row.properties.n_directions}</td>
                                        <td>{row.properties.n_lanes_direction}</td>
                                        {#if rt_data}
                                            <td
                                                >{row.properties.speed_avg &&
                                                !isNaN(row.properties.speed_avg)
                                                    ? row.properties.speed_avg?.toFixed(2)
                                                    : "-"}</td
                                            >
                                            <td
                                                >{row.properties.speed_p25 &&
                                                !isNaN(row.properties.speed_p25)
                                                    ? row.properties.speed_p25?.toFixed(2)
                                                    : "-"}</td
                                            >
                                            <td
                                                >{row.properties.speed_median &&
                                                !isNaN(row.properties.speed_median)
                                                    ? row.properties.speed_median?.toFixed(
                                                          2,
                                                      )
                                                    : "-"}</td
                                            >
                                            <td
                                                >{row.properties.speed_p75 &&
                                                !isNaN(row.properties.speed_p75)
                                                    ? row.properties.speed_p75?.toFixed(2)
                                                    : "-"}</td
                                            >
                                            <td
                                                >{row.properties.speed_count &&
                                                !isNaN(row.properties.speed_count)
                                                    ? row.properties.speed_count
                                                    : "-"}</td
                                            >
                                        {/if}
                                        <td>{row.properties.route_names}</td>
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
                        onclick={() => (open = false)}>Go back</button
                    >
                </div>
            </footer>
        </article>
    </dialog>
</main>

<style>
    .svelte-simple-datatable button {
        white-space: nowrap !important;
    }

    @media (min-width: 768px) {
        dialog > article {
            max-width: 95vw !important;
        }
    }
</style>
