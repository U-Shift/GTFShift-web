<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_GRADIENT } from "../data";
    import type { GeoPrioritisation } from "../types/GeoPrioritisation";
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
        criteriaHour = 8,
        lineWeightBy = "frequency",
        selectedWayId = undefined,
        selectedShapeId = undefined,
        onLayerCreate = (layer) => {},
        onVisibleWayIdsChange = (wayIds) => {},
        onWaySelect = (wayId) => {},
    }: {
        map: L.Map;
        geoData: GeoPrioritisation;
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
        getWayHourlyFrequency,
    } from "../lib/utils";

    function getFrequencyValue(wayId: string): number {
        return getWayHourlyFrequency(geoData.wayData[wayId], criteriaHour);
    }

    function formatFrequencyLabel(wayId: string): string {
        const frequency = getFrequencyValue(wayId);
        return `${frequency.toFixed(1)} buses/h`;
    }

    function getFreqStyle(wayId: string): L.PathOptions {
        const props = geoData.wayData[wayId];
        const freq = getFrequencyValue(wayId);
        const color = getColorFromGradient(
            freq,
            geoData.metadata.data_census.frequency_hour[criteriaHour]?.p5 || 0,
            geoData.metadata.data_census.frequency_hour[criteriaHour]?.p95 || 1,
            COLOR_GRADIENT,
        );
        const weight = getLineWeight(
            geoData,
            props,
            criteriaHour,
            lineWeightBy,
        );
        return { color, weight };
    }

    $effect(() => {
        if (!map || !geoData) return;

        wayLayerMap = new Map();

        // Filter for valid features based on criteria
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
                return props?.hour_frequency?.[criteriaHour];
            },
        );
        const visibleWayIds = filteredFeatures
            .map((feature) => feature?.properties?.way_osm_id)
            .filter((wayId): wayId is string => !!wayId);

        // Create and add new layer to map
        const newLayer = L.geoJSON(
            // Order by frequency asc, to plot higher frequencies on top
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
                    if (!wayId) return {};
                    return getFreqStyle(wayId);
                },
                onEachFeature: (feature, layer) => {
                    const wayId = feature.properties?.way_osm_id;
                    if (wayId) wayLayerMap.set(wayId, layer as L.Path);
                    if (wayId) {
                        bindWayValueTooltip(layer, formatFrequencyLabel(wayId));
                    }
                    layer.on("click", (e) => {
                        L.DomEvent.stopPropagation(e);
                        if (wayId) onWaySelect(wayId);
                    });
                    layer.on("mouseover", () => {
                        handleWayMouseOver(layer, wayId, selectedWayId);
                    });
                    layer.on("mouseout", () => {
                        handleWayMouseOut(
                            layer,
                            wayId,
                            selectedWayId,
                            getFreqStyle,
                        );
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

        // Zoom to operations layer (only if there are features with valid bounds)
        if (geoData.features.length > 0) {
            const opsLayer = L.geoJSON(geoData.features);
            const bounds = opsLayer.getBounds();
            if (bounds.isValid()) map.fitBounds(bounds, { padding: [10, 10] });
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
                path.setStyle(getFreqStyle(wayId));
            }
        });
    });
</script>
