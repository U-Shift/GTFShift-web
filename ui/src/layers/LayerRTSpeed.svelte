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
        criteriaHour,
        onLayerCreate = (layer) => {},
    }: {
        map: L.Map;
        geoData: GeoPrioritization;
        criteriaHour: number;
        onLayerCreate: (layer: L.Layer) => void;
    } = $props();

    let currentLayer: L.Layer | null = $state(null);

    $effect(() => {
        if (!map || !geoData) return;

        // Filter for hour==criteriaHour
        const filteredFeatures = geoData.features.filter(
            (feature: Feature | undefined) =>
                feature?.properties?.hour === criteriaHour
        );

        // Deduplicate by way_osm_id
        const uniqueFeatures = deduplicateByWayId(filteredFeatures);

        // Create and add new layer to map
        const newLayer = L.geoJSON(
            // Order by speed_avg asc, to plot higher speeds on top
            uniqueFeatures.sort((a, b) => (a.properties?.speed_avg || 0) - (b.properties?.speed_avg || 0)), 
            {
            style: (feature: Feature | undefined) => {
                let properties = feature?.properties;
                let speed_avg = properties?.speed_avg || undefined;
                let colorIndex = speed_avg!==undefined ? Math.min(
                    Math.ceil(
                        (speed_avg * COLOR_GRADIENT_RED.length) / (geoData.metadata.data_census.speed_avg?.max || 1),
                    ),
                    COLOR_GRADIENT_RED.length - 1,
                ) : undefined;
                return {
                    color: colorIndex!==undefined ?COLOR_GRADIENT_RED.slice().reverse()[colorIndex] : COLOR_GRAY,
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
