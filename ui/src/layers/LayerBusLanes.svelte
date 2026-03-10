<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_TEAL } from "../data";
    import type { Feature } from "geojson";
    import type { GeoPrioritization } from "../types/GeoPrioritization";

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

    $effect(() => {
        if (!map || !geoData) return;

        wayLayerMap = new Map();

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
            style: { color: COLOR_TEAL, weight: 3.5 },
            onEachFeature: (feature, layer) => {
                const wayId = feature.properties?.way_osm_id;
                if (wayId) wayLayerMap.set(wayId, layer as L.Path);
                layer.on("click", (e) => {
                    L.DomEvent.stopPropagation(e);
                    if (wayId) onWaySelect(wayId);
                });
                layer.on("mouseover", () => {
                    if (wayId && wayId !== selectedWayId) {
                        (layer as L.Path).setStyle({
                            color: "#FCF1DD",
                            weight: 5,
                        });
                        (layer as L.Path).bringToFront();
                    }
                });
                layer.on("mouseout", () => {
                    if (wayId && wayId !== selectedWayId) {
                        (layer as L.Path).setStyle({
                            color: COLOR_TEAL,
                            weight: 3.5,
                        });
                    }
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
                path.setStyle({ color: COLOR_TEAL, weight: 3.5 });
            }
        });
    });
</script>
