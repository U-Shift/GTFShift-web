<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_GRADIENT } from "../data";
    import { createFeaturePopup, deduplicateByWayId, calculateMinMax } from "../lib/layerUtils";

    let {
        map,
        geoData,
        onLayerCreate = (layer, min, max) => {},
    }: {
        map: L.Map;
        geoData: any;
        onLayerCreate: (layer: L.Layer, min: number, max: number) => void;
    } = $props();

    let currentLayer: L.Layer | null = $state(null);

    $effect(() => {
        if (!map || !geoData) return;

        // Deduplicate by way_osm_id
        const uniqueFeatures = deduplicateByWayId(geoData.features);

        // Calculate min and max
        const { min: dataMin, max: dataMax } = calculateMinMax(
            uniqueFeatures,
            "n_lanes_direction",
            1
        );

        // Create and add new layer to map
        const newLayer = L.geoJSON(uniqueFeatures, {
            style: (feature) => {
                let properties = feature.properties;
                let n_lanes_direction = properties.n_lanes_direction || 0;
                let colorIndex = Math.min(
                    Math.ceil(
                        (n_lanes_direction * COLOR_GRADIENT.length) / dataMax,
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
            onLayerCreate(newLayer, dataMin, dataMax);
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
