<script lang="ts">
    import { tick } from "svelte";
    import mermaid from "mermaid";
    import { Button } from "$lib/components/ui/button/index.js";

    let {
        open = $bindable(false),
        zipUrl = "",
    }: {
        open: boolean;
        zipUrl: string | undefined;
    } = $props();

    const diagramText = `
erDiagram
    Prioritization_Area_Polygon_GeoJSON {
        Polygon geometry "Convex hull enclosing all prioritized segments"
    }

    Ways_GeoJSON {
        string way_osm_id PK "OSM Way Identifier"
        LineString geometry "Spatial geometry of the road segment"
    }

    Way_Data_JSON {
        string way_osm_id PK "OSM Way Identifier (key of root dictionary object)"
        string name "Street name"
        float length_m "Length of way in meters"
        boolean is_bus_lane "True if segment has a bus lane"
        int n_lanes "Total number of lanes"
        int n_lanes_direction "Number of lanes in the digitizing direction"
        int n_lanes_circulation "Number of circulation lanes"
        int n_lanes_circulation_direction "Circulation lanes in direction"
        int n_lanes_parking "Number of parking lanes"
        int n_directions "Number of directions (1 or 2)"
        string_array routes FK "List of route_ids traversing this way"
        string_array shapes FK "List of shape_ids traversing this way"
        object hour_frequency "Key-value map of hour (0-23) -> transit frequency"
    }

    Shape_Data_JSON {
        string shape_id PK "GTFS shape_id (key of root dictionary object)"
        string route_id FK "GTFS route_id"
        string route_short_name "Public transit route short name (e.g. '12')"
        string route_long_name "Public transit route long name"
        int direction_id "GTFS direction_id (0 or 1)"
        string route_color "Hex color code for styling"
        string route_text_color "Hex text color code for contrast"
        object stats "Prioritization statistics (averages, speed metrics, etc.)"
        object schedule "Key-value map of hour (0-23) -> total shape frequency"
    }

    Route_Data_JSON {
        string route_id PK "GTFS route_id (key of root dictionary object)"
        string route_short_name "Public transit route short name"
        string route_long_name "Public transit route long name"
        string route_color "Hex color code for styling"
        string route_text_color "Hex text color code for contrast"
    }

    Metadata_JSON {
        string region "Name of the region analyzed"
        object gtfs "Source metadata (date, url)"
        array osm_query "OSM query to fetch transit data"
        object prioritization "Global missing shapes/routes metrics"
        object prioritization_hour "Hourly lists of missing shapes and routes"
        object data_census "Aggregated census metrics (frequency, speed, lanes)"
        object rt "Real-time transit metadata (if applicable)"
        object execution "Execution timestamp and Git commit hash"
        object environment "R environment, OS version, and package versions"
    }

    Prioritization_Area_Polygon_GeoJSON ||--o{ Ways_GeoJSON : "spatially encloses"
    Ways_GeoJSON ||--|| Way_Data_JSON : "linked 1:1 on way_osm_id"
    Way_Data_JSON }o--o{ Route_Data_JSON : "references via routes array"
    Way_Data_JSON }o--o{ Shape_Data_JSON : "references via shapes array"
    Shape_Data_JSON }o--|| Route_Data_JSON : "belongs to route_id"
`;

    // Run mermaid rendering when modal is opened
    $effect(() => {
        if (open) {
            tick().then(() => {
                const isDark =
                    document.documentElement.classList.contains("dark");
                mermaid.initialize({
                    startOnLoad: false,
                    theme: "base",
                    securityLevel: "loose",
                    themeVariables: {
                        primaryColor: "#3bc1a8",
                        primaryTextColor: "#ffffff",
                        primaryBorderColor: "#3bc1a8",
                        lineColor: "#3bc1a8",
                        entityBorder: "#3bc1a8",
                        entityBkg: isDark ? "#0f172a" : "#ffffff",
                        attributeBackgroundColor: isDark
                            ? "#0f172a"
                            : "#ffffff",
                        attributeTextColor: isDark ? "#cbd5e1" : "#334155",
                        secondaryColor: isDark ? "#1e293b" : "#f8fafc",
                        secondaryTextColor: isDark ? "#cbd5e1" : "#475569",
                        secondaryBorderColor: "#3bc1a8",
                        tertiaryColor: isDark ? "#1e293b" : "#f8fafc",
                        tertiaryTextColor: isDark ? "#cbd5e1" : "#475569",
                        tertiaryBorderColor: "#3bc1a8",
                    },
                    themeCSS: `
                        .er.entityBox,
                        .er.relationshipLine,
                        .row-rect-odd path,
                        .row-rect-even path,
                        .divider path,
                        marker path,
                        .relationshipLine path {
                            stroke: #3bc1a8 !important;
                        }
                        .er.entityBox {
                            stroke-width: 1.5px !important;
                        }
                        .er.relationshipLine {
                            stroke-width: 1.5px !important;
                        }
                        .row-rect-odd path {
                            fill: ${isDark ? "#0f172a" : "#ffffff"} !important;
                        }
                        .row-rect-even path {
                            fill: ${isDark ? "#1e293b" : "#f1f5f9"} !important;
                        }
                        /* Style relationship markers/endpoints (crows foot symbols) */
                        marker {
                            fill: #3bc1a8 !important;
                            stroke: #3bc1a8 !important;
                        }
                        /* Reset key label text styles */
                        .er.entityLabel {
                            font-weight: bold !important;
                        }
                        /* Ensure all text labels inside table cells have high contrast text color */
                        .nodeLabel, .nodeLabel p, .nodeLabel span {
                            color: ${isDark ? "#f8fafc" : "#1e293b"} !important;
                            fill: ${isDark ? "#f8fafc" : "#1e293b"} !important;
                        }
                        /* Table Title Header text must remain white */
                        .label.name p, .label.name span, .label.name .nodeLabel {
                            color: #ffffff !important;
                            fill: #ffffff !important;
                        }
                        /* Style relationship labels (text on lines) */
                        text.relationshipLabel, .relationshipLabel text {
                            fill: ${isDark ? "#cbd5e1" : "#475569"} !important;
                            color: ${isDark ? "#cbd5e1" : "#475569"} !important;
                        }
                    `,
                });
                const target = document.getElementById(
                    "mermaid-diagram-target",
                );
                if (target) {
                    target.innerHTML = diagramText;
                    target.removeAttribute("data-processed");
                    mermaid
                        .run({
                            nodes: [target],
                        })
                        .catch((err) => {
                            console.error("Mermaid error:", err);
                        });
                }
            });
        }
    });
</script>

{#if open}
    <!-- Backdrop -->
    <div
        class="fixed inset-0 z-[2000] bg-black/20 backdrop-blur-[1px]"
        onclick={() => (open = false)}
        role="presentation"
    ></div>

    <!-- Panel -->
    <div
        class="fixed z-[2010] flex flex-col bg-background/95 backdrop-blur border rounded-xl shadow-xl overflow-hidden h-fit max-h-[calc(100vh-2rem)]
               top-4 left-4 right-4 sm:left-[calc(1rem+350px+0.5rem)] sm:right-4"
    >
        <!-- Header -->
        <div
            class="flex items-center justify-between px-5 py-4 border-b shrink-0"
        >
            <div>
                <h2 class="text-lg font-bold flex items-center gap-2">
                    <i class="fas fa-download text-primary"></i>
                    Download Raw Data
                </h2>
                <p class="text-sm text-muted-foreground mt-0.5">
                    Access spatial and relational datasets generated by the
                    prioritization pipeline.
                </p>
            </div>
            <Button
                variant="ghost"
                size="sm"
                onclick={() => (open = false)}
                class="h-8 w-8 p-0 shrink-0"
            >
                <i class="fas fa-times"></i>
            </Button>
        </div>

        <!-- Content -->
        <div
            class="flex-1 overflow-y-auto px-5 py-4 space-y-6 text-sm leading-relaxed"
        >
            <!-- Section 3: Download Button -->
            <section class="flex flex-col items-start pt-4 border-t">
                <h5
                    class="text-sm font-bold uppercase text-muted-foreground mb-3 flex items-center gap-2 self-start w-full"
                >
                    <i class="fas fa-file-archive text-primary/80"></i>
                    Download ZIP file
                </h5>
                <p class="text-xs text-muted-foreground mb-4 text-left w-full">
                    Below you can download a folder with the processed data for
                    this region. Refer to the documentation below for more
                    details on its structure.
                </p>
                <Button
                    href={zipUrl}
                    variant="outline"
                    target="_blank"
                    rel="noreferrer"
                    class="w-full gap-2 px-6 py-5 text-base font-semibold shadow-sm hover:bg-accent transition-all"
                >
                    <i class="fas fa-download"></i>
                    Download ZIP Archive
                </Button>
            </section>

            <!-- Section 1: Dataset Structure -->
            <section>
                <h5
                    class="text-sm font-bold uppercase text-muted-foreground mb-3 flex items-center gap-2"
                >
                    <i class="fas fa-folder-open text-primary/80"></i>
                    Dataset Structure
                </h5>
                <p class="text-muted-foreground text-xs mb-3">
                    The downloaded ZIP archive contains the processed spatial
                    and relational datasets for this region, consisting of:
                </p>
                <div class="border rounded-lg overflow-hidden border-border/50">
                    <table class="w-full text-xs">
                        <tbody class="divide-y divide-border/30">
                            <tr class="bg-muted/30">
                                <th
                                    class="px-4 py-2 text-left font-semibold text-muted-foreground w-1/3"
                                    >File Pattern</th
                                >
                                <th
                                    class="px-4 py-2 text-left font-semibold text-muted-foreground"
                                    >Description</th
                                >
                            </tr>
                            <tr>
                                <td class="px-4 py-2 font-mono text-foreground"
                                    >prioritization_area_polygon_...geojson</td
                                >
                                <td class="px-4 py-2 text-muted-foreground"
                                    >Spatial boundary (convex hull) of the
                                    prioritization analysis.</td
                                >
                            </tr>
                            <tr class="bg-muted/10">
                                <td class="px-4 py-2 font-mono text-foreground"
                                    >ways_...geojson</td
                                >
                                <td class="px-4 py-2 text-muted-foreground"
                                    >OSM road network geometry carrying public
                                    transit.</td
                                >
                            </tr>
                            <tr>
                                <td class="px-4 py-2 font-mono text-foreground"
                                    >way_data_...json</td
                                >
                                <td class="px-4 py-2 text-muted-foreground"
                                    >Speed, lanes, and hourly frequencies mapped
                                    to OSM ways.</td
                                >
                            </tr>
                            <tr class="bg-muted/10">
                                <td class="px-4 py-2 font-mono text-foreground"
                                    >shape_data_...json</td
                                >
                                <td class="px-4 py-2 text-muted-foreground"
                                    >Transit shape metrics, schedule frequency
                                    maps, and speed statistics.</td
                                >
                            </tr>
                            <tr>
                                <td class="px-4 py-2 font-mono text-foreground"
                                    >route_data_...json</td
                                >
                                <td class="px-4 py-2 text-muted-foreground"
                                    >Public transit route metadata.</td
                                >
                            </tr>
                            <tr class="bg-muted/10">
                                <td class="px-4 py-2 font-mono text-foreground"
                                    >metadata_...json</td
                                >
                                <td class="px-4 py-2 text-muted-foreground"
                                    >Global pipeline execution metrics,
                                    configurations, and census statistics.</td
                                >
                            </tr>
                        </tbody>
                    </table>
                </div>
            </section>

            <!-- Section 2: Data Relational Model -->
            <section>
                <h5
                    class="text-sm font-bold uppercase text-muted-foreground mb-3 flex items-center gap-2"
                >
                    <i class="fas fa-project-diagram text-primary/80"></i>
                    Data Relational Model
                </h5>
                <p class="text-muted-foreground text-xs mb-3">
                    The diagram below shows the schemas and relationships
                    between the generated JSON and GeoJSON files:
                </p>
                <div
                    class="border rounded-lg p-4 bg-muted/20 overflow-x-auto flex justify-center items-center"
                >
                    <div
                        id="mermaid-diagram-target"
                        class="mermaid w-full text-center"
                    >
                        {diagramText}
                    </div>
                </div>
            </section>
        </div>

        <!-- Footer -->
        <div class="shrink-0 px-5 py-3 border-t flex justify-end">
            <Button variant="secondary" onclick={() => (open = false)}
                >Close</Button
            >
        </div>
    </div>
{/if}
