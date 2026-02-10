<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_GRADIENT } from "../data";
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
        const newLayer = L.geoJSON(uniqueFeatures, {
            style: (feature: Feature | undefined) => {
                let properties = feature?.properties;
                let n_lanes_direction = properties?.n_lanes_direction || 0;
                let colorIndex = Math.min(
                    Math.ceil(
                        (n_lanes_direction * COLOR_GRADIENT.length) / geoData.metadata.data_census.lanes.max,
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
