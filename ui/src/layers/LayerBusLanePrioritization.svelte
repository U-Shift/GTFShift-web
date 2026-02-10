<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_YELLOW, COLOR_TEAL, COLOR_RED } from "../data";
    import { createFeaturePopup } from "../lib/layerUtils";
    import type { Feature } from "geojson";
    import type { GeoPrioritization } from "../types/GeoPrioritization";

    let {
        map,
        geoData,
        criteriaHour = 8,
        criteriaBusFrequency = 5,
        criteriaBusFrequencyEnabled = true,
        criteriaNLanesDirection = 2,
        criteriaNLanesDirectionEnabled = true,
        criteriaAvgSpeed = undefined,
        criteriaAvgSpeedEnabled = true,
        onLayerCreate = (layer) => {},
    }: {
        map: L.Map;
        geoData: GeoPrioritization;
        criteriaHour: number;
        criteriaBusFrequency: number;
        criteriaBusFrequencyEnabled: boolean;
        criteriaNLanesDirection: number;
        criteriaNLanesDirectionEnabled: boolean;
        criteriaAvgSpeed: number | undefined;
        criteriaAvgSpeedEnabled: boolean;
        onLayerCreate: (layer: L.Layer) => void;
    } = $props();

    let currentLayer: L.Layer | null = $state(null);

    $effect(() => {
        if (!map || !geoData) return;

        // Filter for hour==criteriaHour
        const filteredFeatures = geoData.features.filter(
            (feature: Feature | undefined) => {
                if (feature?.properties?.hour !== criteriaHour) return false;

                if (feature?.properties?.is_bus_lane) return true;

                const frequencyOk =
                    !criteriaBusFrequencyEnabled ||
                    (feature?.properties?.frequency !== undefined &&
                        feature?.properties?.frequency >= criteriaBusFrequency);

                const lanesOk =
                    !criteriaNLanesDirectionEnabled ||
                    (feature?.properties?.n_lanes_direction !== undefined &&
                        feature?.properties?.n_lanes_direction >=
                            criteriaNLanesDirection);

                const speedOk =
                    !criteriaAvgSpeedEnabled ||
                    criteriaAvgSpeed === undefined ||
                    (feature?.properties?.speed_avg !== undefined &&
                        feature?.properties?.speed_avg <= criteriaAvgSpeed);

                return frequencyOk && lanesOk && speedOk;
            },
        );

        // Create and add new layer to map
        const newLayer = L.geoJSON(
            // Order by frequency to plot higher priority on top
            filteredFeatures.sort((a, b) => (a.properties?.frequency || 0) - (b.properties?.frequency || 0)), 
            {
            style: (feature: Feature | undefined) => {
                let properties = feature?.properties;

                if (properties?.is_bus_lane) {
                    const frequencyOk =
                        !criteriaBusFrequencyEnabled ||
                        (properties.frequency !== undefined &&
                            properties.frequency >= criteriaBusFrequency);

                    const lanesOk =
                        !criteriaNLanesDirectionEnabled ||
                        (properties.n_lanes !== undefined &&
                            properties.n_lanes_direction !== undefined &&
                            properties.n_lanes_direction >= criteriaNLanesDirection);

                    const speedOk =
                        !criteriaAvgSpeedEnabled ||
                        criteriaAvgSpeed === undefined ||
                        (properties.speed_avg !== undefined &&
                            properties.speed_avg > criteriaAvgSpeed);

                    if (frequencyOk && lanesOk && speedOk) {
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
