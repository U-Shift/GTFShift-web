<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_GRADIENT_RED, COLOR_GRAY } from "../data";
    import { createFeaturePopup } from "../lib/layerUtils";
    import type { GeoPrioritization } from "../types/GeoPrioritization";
    import type { Feature } from "geojson";

    let {
        map,
        geoData,
        criteriaHour,
        selectedWayId = undefined,
        onLayerCreate = (layer) => {},
        onWaySelect = (wayId) => {},
    }: {
        map: L.Map;
        geoData: GeoPrioritization;
        criteriaHour: number;
        selectedWayId: string | undefined;
        onLayerCreate: (layer: L.Layer) => void;
        onWaySelect: (wayId: string) => void;
    } = $props();

    let currentLayer: L.Layer | null = $state(null);
    let wayLayerMap: Map<string, L.Path> = new Map();

    function getSpeedStyle(wayId: string): L.PathOptions {
        const props = geoData.wayData[wayId];
        const speed_avg = props?.speed_avg || undefined;
        const colorIndex =
            speed_avg !== undefined
                ? Math.min(
                      Math.ceil(
                          (speed_avg * COLOR_GRADIENT_RED.length) /
                              (geoData.metadata.data_census.speed_avg?.max ||
                                  1),
                      ),
                      COLOR_GRADIENT_RED.length - 1,
                  )
                : undefined;
        return {
            color:
                colorIndex !== undefined
                    ? COLOR_GRADIENT_RED.slice().reverse()[colorIndex]
                    : COLOR_GRAY,
            weight: 3.5,
        };
    }

    $effect(() => {
        if (!map || !geoData) return;

        wayLayerMap = new Map();

        // Filter out features with no speed data
        const filteredFeatures = geoData.features.filter(
            (feature: Feature | undefined) => {
                const wayId = feature?.properties?.way_osm_id;
                const props = wayId ? geoData.wayData[wayId] : undefined;
                return (
                    props?.speed_avg !== undefined && props?.speed_avg !== null
                );
            },
        );

        // Create and add new layer to map
        const newLayer = L.geoJSON(
            // Order by speed_avg asc, to plot higher speeds on top
            filteredFeatures.sort((a, b) => {
                const propsA = a.properties?.way_osm_id
                    ? geoData.wayData[a.properties.way_osm_id]
                    : null;
                const propsB = b.properties?.way_osm_id
                    ? geoData.wayData[b.properties.way_osm_id]
                    : null;
                return (propsA?.speed_avg || 0) - (propsB?.speed_avg || 0);
            }),
            {
                style: (feature: Feature | undefined) => {
                    const wayId = feature?.properties?.way_osm_id;
                    if (!wayId) return {};
                    return getSpeedStyle(wayId);
                },
                onEachFeature: (feature, layer) => {
                    const wayId = feature.properties?.way_osm_id;
                    if (wayId) wayLayerMap.set(wayId, layer as L.Path);
                    layer.on("click", (e) => {
                        L.DomEvent.stopPropagation(e);
                        if (wayId) onWaySelect(wayId);
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
                path.setStyle(getSpeedStyle(wayId));
            }
        });
    });
</script>
