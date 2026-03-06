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
        onWaySelect = (wayId) => {},
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
        onWaySelect: (wayId: string) => void;
    } = $props();

    let currentLayer: L.Layer | null = $state(null);

    console.log("LayerBusLanePrioritization component executing script block");

    let filteredFeatures = $derived.by(() => {
        if (!geoData) return [];
        return geoData.features.filter((feature: Feature | undefined) => {
            const wayId = feature?.properties?.way_osm_id;
            const props = wayId ? geoData.wayData[wayId] : undefined;
            if (!props) return false;

            if (props.is_bus_lane) return true;

            const frequencyOk =
                !criteriaBusFrequencyEnabled ||
                (props.hour_frequency?.[criteriaHour] !== undefined &&
                    props.hour_frequency[criteriaHour] >= criteriaBusFrequency);

            const lanesOk =
                !criteriaNLanesDirectionEnabled ||
                (props.n_lanes !== undefined &&
                    props.n_lanes_direction !== undefined &&
                    props.n_lanes_direction >= criteriaNLanesDirection);

            const speedOk =
                !criteriaAvgSpeedEnabled ||
                criteriaAvgSpeed === undefined ||
                (props.speed_avg !== undefined &&
                    props.speed_avg <= criteriaAvgSpeed);

            return frequencyOk && lanesOk && speedOk;
        });
    });

    $effect(() => {
        if (!map || !geoData) return;

        console.log(
            "LayerBusLanePrioritization effect running. filteredFeatures length:",
            filteredFeatures.length,
        );

        // Create and add new layer to map
        const newLayer = L.geoJSON(
            // Order by frequency to plot higher priority on top
            filteredFeatures.sort((a, b) => {
                const propsA = a.properties?.way_osm_id
                    ? geoData.wayData[a.properties.way_osm_id]
                    : null;
                const propsB = b.properties?.way_osm_id
                    ? geoData.wayData[b.properties.way_osm_id]
                    : null;
                return (
                    (propsA?.hour_frequency?.[criteriaHour] || 0) -
                    (propsB?.hour_frequency?.[criteriaHour] || 0)
                );
            }),
            {
                style: (feature: Feature | undefined) => {
                    const wayId = feature?.properties?.way_osm_id;
                    const props = wayId ? geoData.wayData[wayId] : undefined;

                    if (props?.is_bus_lane) {
                        const frequencyOk =
                            !criteriaBusFrequencyEnabled ||
                            (props.hour_frequency?.[criteriaHour] !==
                                undefined &&
                                props.hour_frequency[criteriaHour] >=
                                    criteriaBusFrequency);

                        const lanesOk =
                            !criteriaNLanesDirectionEnabled ||
                            (props.n_lanes !== undefined &&
                                props.n_lanes_direction !== undefined &&
                                props.n_lanes_direction >=
                                    criteriaNLanesDirection);

                        const speedOk =
                            !criteriaAvgSpeedEnabled ||
                            criteriaAvgSpeed === undefined ||
                            (props.speed_avg !== undefined &&
                                props.speed_avg > criteriaAvgSpeed);

                        if (frequencyOk && lanesOk && speedOk) {
                            return {
                                color: COLOR_TEAL,
                                weight: 3.5,
                            };
                        } else {
                            return {
                                color: COLOR_YELLOW,
                                weight: 3.5,
                            };
                        }
                    } else {
                        return {
                            color: COLOR_RED,
                            weight: 3.5,
                        };
                    }
                },
                onEachFeature: (feature, layer) => {
                    // createFeaturePopup(feature, layer, geoData, criteriaHour),
                    layer.on("click", (e) => {
                        L.DomEvent.stopPropagation(e);
                        const wayId = feature.properties?.way_osm_id;
                        if (wayId) onWaySelect(wayId);
                    });
                },
            },
        ).addTo(map);

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
