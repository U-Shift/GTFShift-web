<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";

    let {
        map,
        boundaryGeoJSON,
        color = "#2c7abf",
    }: {
        map: L.Map;
        boundaryGeoJSON: any;
        color?: string;
    } = $props();

    let currentLayer: L.Layer | null = $state(null);

    $effect(() => {
        if (!map || !boundaryGeoJSON) return;

        // Create and add boundary layer to map
        const newLayer = L.geoJSON(boundaryGeoJSON, {
            style: {
                color: color,
                weight: 2,
                dashArray: "6, 6",
                fillOpacity: 0,
                interactive: false,
            },
        }).addTo(map);

        // Send boundaries to back so ways/segments are fully clickable
        newLayer.bringToBack();

        untrack(() => {
            currentLayer = newLayer;
        });

        // Cleanup
        return () => {
            if (currentLayer) {
                map.removeLayer(currentLayer);
                currentLayer = null;
            }
        };
    });
</script>
