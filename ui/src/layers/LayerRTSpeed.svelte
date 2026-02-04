<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_GRADIENT_RED, COLOR_GRAY } from "../data";
    import { createFeaturePopup, deduplicateByWayId } from "../lib/layerUtils";
    import type { GeoPrioritization } from "../types/GeoPrioritization";
    import type { Feature } from "geojson";

    let {
        map,
        geoData,
        onLayerCreate = (layer) => {},
    }: {
        map: L.Map;
        geoData: GeoPrioritization;
        onLayerCreate: (layer: L.Layer) => void;
    } = $props();

    let currentLayer: L.Layer | null = $state(null);

    $effect(() => {
        if (!map || !geoData) return;

        // Deduplicate by way_osm_id
        const uniqueFeatures = deduplicateByWayId(geoData.features);

        // Create and add new layer to map
        const newLayer = L.geoJSON(uniqueFeatures, {
            style: (feature: Feature) => {
                let properties = feature.properties;
                let speed_avg = properties?.speed_avg || undefined;
                let colorIndex = speed_avg!==undefined ? Math.min(
                    Math.ceil(
                        (speed_avg * COLOR_GRADIENT_RED.length) / (geoData.metadata.data_census.speed_avg?.max || 1),
                    ),
                    COLOR_GRADIENT_RED.length - 1,
                ) : undefined;
                return {
                    color: colorIndex!==undefined ?COLOR_GRADIENT_RED.toReversed()[colorIndex] : COLOR_GRAY,
                    weight: 2.5,
                };
            },
            onEachFeature: createFeaturePopup,
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
