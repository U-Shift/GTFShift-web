<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_TEAL } from "../data";
    import { createFeaturePopup, deduplicateByWayId } from "../lib/layerUtils";
    import type { Feature } from "geojson";

    let {
        map,
        geoData,
        onLayerCreate = (layer) => {},
    }: {
        map: L.Map;
        geoData: any;
        onLayerCreate: (layer: L.Layer) => void;
    } = $props();

    let currentLayer: L.Layer | null = $state(null);

    $effect(() => {
        if (!map || !geoData) return;

        // Filter for bus lanes
        const filteredFeatures = geoData.features.filter(
            (feature: Feature | undefined) => feature?.properties?.is_bus_lane,
        );

        // Deduplicate by way_osm_id
        const uniqueFeatures = deduplicateByWayId(filteredFeatures);

        // Create and add new layer to map
        const newLayer = L.geoJSON(uniqueFeatures, {
            style: {
                color: COLOR_TEAL,
                weight: 2.5,
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
