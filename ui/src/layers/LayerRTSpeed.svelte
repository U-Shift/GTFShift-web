<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_GRADIENT_RED } from "../data";
    import { createFeaturePopup, deduplicateByWayId, dataCensus, type DataCensus } from "../lib/layerUtils";

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
        const census = dataCensus(
            uniqueFeatures,
            "speed_avg"
        );

        // Create and add new layer to map
        const newLayer = L.geoJSON(uniqueFeatures, {
            style: (feature) => {
                let properties = feature.properties;
                let speed_avg = properties.speed_avg || 0;
                let colorIndex = Math.min(
                    Math.ceil(
                        (speed_avg * COLOR_GRADIENT_RED.length) / (census.max ?? 1),
                    ),
                    COLOR_GRADIENT_RED.length - 1,
                );
                return {
                    color: COLOR_GRADIENT_RED.toReversed()[colorIndex],
                    weight: 2.5,
                };
            },
            onEachFeature: createFeaturePopup,
        }).addTo(map);

        // Update parent state
        untrack(() => {
            currentLayer = newLayer;
            onLayerCreate(newLayer, census);
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
