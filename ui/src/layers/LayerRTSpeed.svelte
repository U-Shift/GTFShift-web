<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_GRADIENT_RED, COLOR_GRAY } from "../data";
    import type { GeoPrioritization } from "../types/GeoPrioritization";
    import type { LineWeightMetric } from "../types/LineWeightMetric";
    import type { Feature } from "geojson";
    import {
        bindWayValueTooltip,
        handleWayMouseOut,
        handleWayMouseOver,
    } from "../lib/layerInteractions";

    let {
        map,
        geoData,
        criteriaHour,
        lineWeightBy = "frequency",
        selectedWayId = undefined,
        selectedShapeId = undefined,
        onLayerCreate = (layer) => {},
        onVisibleWayIdsChange = (wayIds) => {},
        onWaySelect = (wayId) => {},
    }: {
        map: L.Map;
        geoData: GeoPrioritization;
        criteriaHour: number;
        lineWeightBy: LineWeightMetric;
        selectedWayId: string | undefined;
        selectedShapeId: string | undefined;
        onLayerCreate: (layer: L.Layer) => void;
        onVisibleWayIdsChange: (wayIds: string[]) => void;
        onWaySelect: (wayId: string) => void;
    } = $props();

    let currentLayer: L.Layer | null = $state(null);
    let wayLayerMap: Map<string, L.Path> = new Map();

    import {
        getColorFromGradient,
        getLineWeight,
    } from "../lib/utils";

    function formatSpeedLabel(wayId: string): string {
        const speed = geoData.wayData[wayId]?.speed_avg;
        const speedValue = Number(speed);
        if (isNaN(speedValue)) return "Speed: n/a";
        return `${speedValue.toFixed(1)} km/h`;
    }

    function getSpeedStyle(wayId: string): L.PathOptions {
        const props = geoData.wayData[wayId];
        const speed_avg = props?.speed_avg;
        let color = COLOR_GRAY;
        const weight = getLineWeight(geoData, props, criteriaHour, lineWeightBy);
        if (speed_avg !== undefined && speed_avg !== null && !isNaN(Number(speed_avg))) {
            const speedValue = Number(speed_avg);
            color = getColorFromGradient(
                speedValue,
                geoData.metadata.data_census.speed_avg_length?.p5 || 0,
                geoData.metadata.data_census.speed_avg_length?.p95 || 1,
                COLOR_GRADIENT_RED.slice().reverse(),
            );
        }
        return {
            color,
            weight,
        };
    }

    $effect(() => {
        if (!map || !geoData) return;

        wayLayerMap = new Map();

        // Filter out features with no speed data
        const filteredFeatures = geoData.features.filter(
            (feature: Feature | undefined) => {
                const wayId = feature?.properties?.way_osm_id;
                const props = wayId ? geoData.wayData[wayId] : undefined;
                if (
                    selectedShapeId &&
                    selectedShapeId !== "all" &&
                    !props?.shapes?.includes(selectedShapeId)
                ) {
                    return false;
                }
                return (
                    props?.speed_avg !== undefined &&
                    props?.speed_avg !== null &&
                    !isNaN(Number(props?.speed_avg))
                );
            },
        );
        const visibleWayIds = filteredFeatures
            .map((feature) => feature?.properties?.way_osm_id)
            .filter((wayId): wayId is string => !!wayId);

        // Create and add new layer to map
        const newLayer = L.geoJSON(
            // Order by speed_avg asc, to plot higher speeds on top
            filteredFeatures.sort((a, b) => {
                const propsA = a.properties?.way_osm_id
                    ? geoData.wayData[a.properties.way_osm_id]
                    : null;
                const propsB = b.properties?.way_osm_id
                    ? geoData.wayData[b.properties.way_osm_id]
                    : null;
                return (propsA?.speed_avg || 0) - (propsB?.speed_avg || 0);
            }),
            {
                style: (feature: Feature | undefined) => {
                    const wayId = feature?.properties?.way_osm_id;
                    if (!wayId) return {};
                    return getSpeedStyle(wayId);
                },
                onEachFeature: (feature, layer) => {
                    const wayId = feature.properties?.way_osm_id;
                    if (wayId) wayLayerMap.set(wayId, layer as L.Path);
                    if (wayId) {
                        bindWayValueTooltip(layer, formatSpeedLabel(wayId));
                    }
                    layer.on("click", (e) => {
                        L.DomEvent.stopPropagation(e);
                        if (wayId) onWaySelect(wayId);
                    });
                    layer.on("mouseover", () => {
                        handleWayMouseOver(layer, wayId, selectedWayId);
                    });
                    layer.on("mouseout", () => {
                        handleWayMouseOut(layer, wayId, selectedWayId, getSpeedStyle);
                    });
                },
            },
        ).addTo(map);

        // Update parent state
        untrack(() => {
            currentLayer = newLayer;
            onLayerCreate(newLayer);
            onVisibleWayIdsChange(visibleWayIds);
        });

        // Zoom to layer (only if there are features with valid bounds)
        if (filteredFeatures.length > 0) {
            const bounds = newLayer.getBounds();
            if (bounds.isValid()) map.fitBounds(bounds);
        }

        // Cleanup
        return () => {
            if (currentLayer) {
                map.removeLayer(currentLayer);
                currentLayer = null;
            }
            wayLayerMap = new Map();
            onVisibleWayIdsChange([]);
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
                path.setStyle(getSpeedStyle(wayId));
            }
        });
    });
</script>
