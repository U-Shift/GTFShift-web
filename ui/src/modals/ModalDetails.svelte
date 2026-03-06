<script lang="ts">
    import type { GeoPrioritization } from "../types/GeoPrioritization";
    import { Button } from "$lib/components/ui/button/index.js";
    import hljs from "highlight.js/lib/core";
    import r from "highlight.js/lib/languages/r";

    hljs.registerLanguage("r", r);

    // Dynamically load the right highlight.js theme and keep it in sync with dark mode
    function applyHljsTheme() {
        const isDark = document.documentElement.classList.contains("dark");
        let link = document.getElementById(
            "hljs-theme",
        ) as HTMLLinkElement | null;
        if (!link) {
            link = document.createElement("link");
            link.id = "hljs-theme";
            link.rel = "stylesheet";
            document.head.appendChild(link);
        }
        link.href = isDark
            ? new URL("highlight.js/styles/github-dark.css", import.meta.url)
                  .href
            : new URL("highlight.js/styles/a11y-light.css", import.meta.url)
                  .href;
    }

    $effect(() => {
        applyHljsTheme();
        const observer = new MutationObserver(applyHljsTheme);
        observer.observe(document.documentElement, {
            attributes: true,
            attributeFilter: ["class"],
        });
        return () => observer.disconnect();
    });

    let {
        open = $bindable(false),
        geoData,
    }: {
        open: boolean;
        geoData: GeoPrioritization | null;
    } = $props();
</script>

{#if open}
    <!-- Backdrop -->
    <div
        class="fixed inset-0 z-[999] bg-black/20 backdrop-blur-[1px]"
        onclick={() => (open = false)}
        role="presentation"
    ></div>

    <!-- Panel: same margins as the left sidebar -->
    <div
        class="fixed z-[1000] flex flex-col bg-background/95 backdrop-blur border rounded-xl shadow-xl overflow-hidden"
        style="top: 1rem; bottom: 1rem; left: calc(1rem + 350px + 0.5rem); right: 1rem;"
    >
        <!-- Header -->
        <div
            class="flex items-center justify-between px-5 py-4 border-b shrink-0"
        >
            <h2 class="text-lg font-bold flex items-center gap-2">
                <i class="fas fa-code text-primary"></i>
                Technical Details
            </h2>
            <Button
                variant="ghost"
                size="sm"
                onclick={() => (open = false)}
                class="h-8 w-8 p-0"
            >
                <i class="fas fa-times"></i>
            </Button>
        </div>

        <!-- Content -->
        <div class="flex-1 overflow-y-auto px-5 py-4 space-y-6">
            <section>
                <h5
                    class="text-sm font-bold uppercase text-muted-foreground mb-3 flex items-center gap-2"
                >
                    <i class="fas fa-microchip"></i> Specifications
                </h5>
                {#if geoData}
                    <div
                        class="border rounded-lg overflow-hidden border-border/50"
                    >
                        <table class="w-full text-sm">
                            <tbody class="divide-y divide-border/30">
                                <tr class="bg-muted/30">
                                    <th
                                        class="px-4 py-2 text-left font-medium text-muted-foreground w-1/3"
                                        >Region</th
                                    >
                                    <td class="px-4 py-2"
                                        ><kbd
                                            class="bg-muted px-1.5 py-0.5 rounded text-xs font-mono"
                                            >{geoData.metadata.region}</kbd
                                        ></td
                                    >
                                </tr>
                                <tr>
                                    <th
                                        class="px-4 py-2 text-left font-medium text-muted-foreground"
                                        >Transit services for day¹</th
                                    >
                                    <td class="px-4 py-2"
                                        ><kbd
                                            class="bg-muted px-1.5 py-0.5 rounded text-xs font-mono"
                                            >{geoData.metadata.gtfs.date}</kbd
                                        ></td
                                    >
                                </tr>
                                <tr class="bg-muted/30">
                                    <th
                                        class="px-4 py-2 text-left font-medium text-muted-foreground"
                                        >Shapes considered²</th
                                    >
                                    <td class="px-4 py-2">
                                        <kbd
                                            class="bg-muted px-1.5 py-0.5 rounded text-xs font-mono"
                                        >
                                            {geoData.metadata.prioritization
                                                .shapes_total -
                                                geoData.metadata.prioritization
                                                    .shapes_missing.length} of {geoData
                                                .metadata.prioritization
                                                .shapes_total}
                                            ({(
                                                ((geoData.metadata
                                                    .prioritization
                                                    .shapes_total -
                                                    geoData.metadata
                                                        .prioritization
                                                        .shapes_missing
                                                        .length) /
                                                    geoData.metadata
                                                        .prioritization
                                                        .shapes_total) *
                                                100
                                            ).toFixed(2)}%)
                                        </kbd>
                                    </td>
                                </tr>
                                <tr>
                                    <th
                                        class="px-4 py-2 text-left font-medium text-muted-foreground"
                                        >OSM query</th
                                    >
                                    <td class="px-4 py-2 flex flex-wrap gap-1">
                                        {#each geoData.metadata.osm_query as q}
                                            <kbd
                                                class="bg-muted px-1.5 py-0.5 rounded text-[10px] font-mono"
                                                >{q.key}={q.value}</kbd
                                            >
                                        {/each}
                                    </td>
                                </tr>
                                {#if geoData.metadata.rt}
                                    <tr class="bg-muted/30">
                                        <th
                                            class="px-4 py-2 text-left font-medium text-muted-foreground"
                                            >Real-time data interval</th
                                        >
                                        <td class="px-4 py-2"
                                            ><kbd
                                                class="bg-muted px-1.5 py-0.5 rounded text-xs font-mono"
                                                >{geoData.metadata.rt
                                                    .period}</kbd
                                            ></td
                                        >
                                    </tr>
                                {/if}
                                <tr>
                                    <th
                                        class="px-4 py-2 text-left font-medium text-muted-foreground"
                                        >Running environment</th
                                    >
                                    <td class="px-4 py-2 flex flex-wrap gap-1">
                                        <kbd
                                            class="bg-muted px-1.5 py-0.5 rounded text-[10px] font-mono"
                                            >GTFShift {geoData.metadata
                                                .environment.GTFShift}</kbd
                                        >
                                        <kbd
                                            class="bg-muted px-1.5 py-0.5 rounded text-[10px] font-mono"
                                            >{geoData.metadata.environment
                                                .r}</kbd
                                        >
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                {/if}
            </section>

            <section
                class="bg-muted/20 p-4 rounded-lg border border-border/50 text-[11px] space-y-2 text-muted-foreground leading-relaxed"
            >
                <p>¹ Transit frequency computed for representative day</p>
                <p>
                    ² <a
                        href="https://u-shift.github.io/GTFShift/reference/prioritize_lanes.html"
                        target="_blank"
                        class="text-primary hover:underline"
                        >GTFShift::prioritize_lanes()</a
                    >
                    uses
                    <a
                        href="https://u-shift.github.io/GTFShift/reference/get_way_frequency_hourly.html"
                        target="_blank"
                        class="text-primary hover:underline"
                        >GTFShift::get_way_frequency_hourly()</a
                    > to match routes with OSM ways.
                </p>
                {#if geoData?.metadata.rt}
                    <p>
                        ³ Real-time data points within {geoData.metadata.rt
                            .stop_buffer_size} meters from a bus stop are ignored
                        for speed calculations.
                    </p>
                {/if}
            </section>

            <section>
                <div class="flex items-center justify-between mb-2">
                    <h5
                        class="text-sm font-bold uppercase text-muted-foreground flex items-center gap-2"
                    >
                        <i class="fas fa-terminal"></i> R Analysis Code
                    </h5>
                    <a
                        href="https://u-shift.github.io/GTFShift/articles/prioritize.html"
                        target="_blank"
                        class="text-[10px] text-primary hover:underline"
                    >
                        View Tutorial
                    </a>
                </div>

                {#if geoData}
                    <div
                        class="rounded-lg overflow-hidden border border-border/50"
                    >
                        <pre class="p-4 text-xs overflow-x-auto"><code>
                            {@html hljs.highlight(
                                    `library(GTFShift)
library(tidytransit)
library(osmdata)
library(sf)

# Prioritize based on planned operation and infrastructure characteristics
gtfs = GTFShift::load_feed("gtfs.zip", create_transfers=FALSE)
osm_q = opq(bbox=sf::st_bbox(tidytransit::shapes_as_sf(gtfs$shapes)))  |>
  ${geoData.metadata.osm_query.map((q) => `add_osm_feature(key = "${q.key}", value = ${Array.isArray(q.value) ? `c(${q.value.map((v) => `"${v}"`).join(", ")})` : `"${q.value}"`}, key_exact = ${q.key_exact ? "TRUE" : "FALSE"})`).join(" |> \n  ")}

lane_prioritization = prioritize_lanes(gtfs, osm_q)
` +
                                        (geoData.metadata.rt
                                            ? `
# Extend with real-time data
rt_collection <- read.csv("updates_collected.csv") |> sf::st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
# ... filtering omitted ...
lane_prioritization <- GTFShift::rt_extend_prioritization(lane_prioritization, rt_collection)
`
                                            : ""),
                                    { language: "r" },
                                ).value}
                        </code></pre>
                    </div>
                {/if}
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
