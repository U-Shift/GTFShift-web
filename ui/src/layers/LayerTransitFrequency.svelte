<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_GRADIENT } from "../data";
    import type { GeoPrioritization } from "../types/GeoPrioritization";
    import type { Feature } from "geojson";

    let {
        map,
        geoData,
        criteriaHour = 8,
        selectedWayId = undefined,
        selectedShapeId = undefined,
        onLayerCreate = (layer) => {},
        onWaySelect = (wayId) => {},
    }: {
        map: L.Map;
        geoData: GeoPrioritization;
        criteriaHour: number;
        selectedWayId: string | undefined;
        selectedShapeId: string | undefined;
        onLayerCreate: (layer: L.Layer) => void;
        onWaySelect: (wayId: string) => void;
    } = $props();

    let currentLayer: L.Layer | null = $state(null);
    let wayLayerMap: Map<string, L.Path> = new Map();

    function getFreqStyle(wayId: string): L.PathOptions {
        const props = geoData.wayData[wayId];
        const freq = props?.hour_frequency?.[criteriaHour] || 0;
        const colorIndex = Math.min(
            Math.ceil(
                (freq * COLOR_GRADIENT.length) /
                    (geoData.metadata.data_census.frequency_hour[criteriaHour]
                        ?.max || 1),
            ),
            COLOR_GRADIENT.length - 1,
        );
        return { color: COLOR_GRADIENT[colorIndex], weight: 3.5 };
    }

    $effect(() => {
        if (!map || !geoData) return;

        wayLayerMap = new Map();

        // Filter for valid features based on criteria
        const filteredFeatures = geoData.features.filter(
            (feature: Feature | undefined) => {
                const wayId = feature?.properties?.way_osm_id;
                const props = wayId ? geoData.wayData[wayId] : undefined;
                if (selectedShapeId && selectedShapeId !== "all" && !props?.shapes?.includes(selectedShapeId)) {
                    return false;
                }
                return props?.hour_frequency?.[criteriaHour];
            },
        );

        // Create and add new layer to map
        const newLayer = L.geoJSON(
            // Order by frequency asc, to plot higher frequencies on top
            filteredFeatures.sort((a, b) => {
                const propsA = a.properties?.way_osm_id
                    ? geoData.wayData[a.properties.way_osm_id]
                    : null;
                const propsB = b.properties?.way_osm_id
                    ? geoData.wayData[b.properties.way_osm_id]
                    : null;
                return (
                    (propsA?.hour_frequency?.[criteriaHour] || 0) -
                    (propsB?.hour_frequency?.[criteriaHour] || 0)
                );
            }),
            {
                style: (feature: Feature | undefined) => {
                    const wayId = feature?.properties?.way_osm_id;
                    if (!wayId) return {};
                    return getFreqStyle(wayId);
                },
                onEachFeature: (feature, layer) => {
                    const wayId = feature.properties?.way_osm_id;
                    if (wayId) wayLayerMap.set(wayId, layer as L.Path);
                    layer.on("click", (e) => {
                        L.DomEvent.stopPropagation(e);
                        if (wayId) onWaySelect(wayId);
                    });
                    layer.on("mouseover", () => {
                        if (wayId && wayId !== selectedWayId) {
                            (layer as L.Path).setStyle({
                                color: "#FCF1DD",
                                weight: 5,
                            });
                            (layer as L.Path).bringToFront();
                        }
                    });
                    layer.on("mouseout", () => {
                        if (wayId && wayId !== selectedWayId) {
                            (layer as L.Path).setStyle(getFreqStyle(wayId));
                        }
                    });
                },
            },
        ).addTo(map);

        // Update parent state
        untrack(() => {
            currentLayer = newLayer;
            onLayerCreate(newLayer);
        });

        // Zoom to layer
        map.fitBounds(newLayer.getBounds());

        // Cleanup
        return () => {
            if (currentLayer) {
                map.removeLayer(currentLayer);
                currentLayer = null;
            }
            wayLayerMap = new Map();
        };
    });

    // Highlight the selected way reactively
    $effect(() => {
        const selected = selectedWayId;
        wayLayerMap.forEach((path, wayId) => {
            if (wayId === selected) {
                path.setStyle({ weight: 7, color: "#FFD4B8", opacity: 1 });
                path.bringToFront();
            } else {
                path.setStyle(getFreqStyle(wayId));
            }
        });
    });
</script>
