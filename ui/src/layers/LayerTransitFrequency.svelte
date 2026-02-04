<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_GRADIENT } from "../data";
    import { createFeaturePopup } from "../lib/layerUtils";
    import type { GeoPrioritization } from "../types/GeoPrioritization";
    import type { Feature } from "geojson";

    let {
        map,
        geoData,
        criteriaHour = 8,
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

        // Filter for hour==criteriaHour and has frequency
        const filteredFeatures = geoData.features.filter(
            (feature:Feature) =>
                feature.properties?.hour === criteriaHour &&
                feature.properties?.frequency,
        );

        // Create and add new layer to map
        const newLayer = L.geoJSON(filteredFeatures, {
            style: (feature: Feature) => {
                let properties = feature.properties;
                let freq = properties?.frequency || 0;
                let colorIndex = Math.min(
                    Math.ceil(
                        (freq * COLOR_GRADIENT.length) / (geoData.metadata.data_census.frequency_hour[criteriaHour]?.max || 1),
                    ),
                    COLOR_GRADIENT.length - 1,
                );
                return {
                    color: COLOR_GRADIENT[colorIndex],
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
