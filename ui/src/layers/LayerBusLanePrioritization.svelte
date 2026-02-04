<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_YELLOW, COLOR_TEAL, COLOR_RED } from "../data";
    import { createFeaturePopup } from "../lib/layerUtils";
    import type { Feature } from "geojson";

    let {
        map,
        geoData,
        criteriaHour = 8,
        criteriaBusFrequency = 5,
        criteriaNLanesDirection = 2,
        criteriaAvgSpeed = undefined,
        onLayerCreate = (layer) => {},
    }: {
        map: L.Map;
        geoData: any;
        criteriaHour: number;
        criteriaBusFrequency: number;
        criteriaNLanesDirection: number;
        criteriaAvgSpeed: number | undefined;
        onLayerCreate: (layer: L.Layer) => void;
    } = $props();

    let currentLayer: L.Layer | null = $state(null);

    $effect(() => {
        if (!map || !geoData) return;

        // Filter for hour==criteriaHour
        const filteredFeatures = geoData.features.filter(
            (feature: Feature | undefined) =>
                feature?.properties?.hour === criteriaHour &&
                (feature?.properties?.is_bus_lane ||
                    (
                        feature?.properties?.frequency &&
                        feature?.properties?.frequency >= criteriaBusFrequency &&
                        feature?.properties?.n_lanes_direction &&
                        feature?.properties?.n_lanes_direction >=
                            criteriaNLanesDirection &&
                        (criteriaAvgSpeed===undefined ||
                            (feature?.properties?.speed_avg !== undefined &&
                                feature?.properties?.speed_avg <=
                                    criteriaAvgSpeed)))
                ),
        );

        // Create and add new layer to map
        const newLayer = L.geoJSON(filteredFeatures, {
            style: (feature: Feature | undefined) => {
                let properties = feature?.properties;

                if (properties?.is_bus_lane) {
                    if (
                        properties.frequency >= criteriaBusFrequency &&
                        properties.n_lanes !== undefined &&
                        properties.n_lanes_direction >= criteriaNLanesDirection && 
                        (
                            !criteriaAvgSpeed ||
                            (properties.speed_avg !== undefined &&
                                properties.speed_avg > criteriaAvgSpeed)
                        )
                    ) {
                        return {
                            color: COLOR_TEAL,
                            weight: 2.5,
                        };
                    } else {
                        return {
                            color: COLOR_YELLOW,
                            weight: 2.5,
                        };
                    }
                } else {
                    return {
                        color: COLOR_RED,
                        weight: 2.5,
                    };
                }
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
