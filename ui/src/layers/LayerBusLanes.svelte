<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_TEAL } from "../data";
    import { createFeaturePopup } from "../lib/layerUtils";
    import type { Feature } from "geojson";
    import type { GeoPrioritization } from "../types/GeoPrioritization";

    let {
        map,
        geoData,
        criteriaHour,
        onLayerCreate = (layer) => {},
        onWaySelect = (wayId) => {},
    }: {
        map: L.Map;
        geoData: GeoPrioritization;
        criteriaHour: number;
        onLayerCreate: (layer: L.Layer) => void;
        onWaySelect: (wayId: string) => void;
    } = $props();

    let currentLayer: L.Layer | null = $state(null);

    $effect(() => {
        if (!map || !geoData) return;

        // Filter for bus lanes
        const filteredFeatures = geoData.features.filter(
            (feature: Feature | undefined) => {
                const wayId = feature?.properties?.way_osm_id;
                const props = wayId ? geoData.wayData[wayId] : undefined;
                return props?.is_bus_lane;
            },
        );

        // Create and add new layer to map
        const newLayer = L.geoJSON(filteredFeatures, {
            style: {
                color: COLOR_TEAL,
                weight: 2.5,
            },
            onEachFeature: (feature, layer) => {
                // createFeaturePopup(feature, layer, geoData, criteriaHour),
                layer.on("click", (e) => {
                    L.DomEvent.stopPropagation(e);
                    const wayId = feature.properties?.way_osm_id;
                    if (wayId) onWaySelect(wayId);
                });
            },
        }).addTo(map);

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
        };
    });
</script>
