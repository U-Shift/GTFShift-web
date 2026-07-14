<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_GRADIENT, COLOR_GRAY } from "../data";
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

    function getDemandValue(wayId: string | undefined): number | undefined {
        if (!wayId) return undefined;
        const demand = geoData.wayData[wayId]?.demand;
        const demandValue = Number(demand);
        return Number.isNaN(demandValue) ? undefined : demandValue;
    }

    function formatDemandLabel(wayId: string): string {
        const demandValue = getDemandValue(wayId);
        if (demandValue === undefined) return "Demand: n/a";
        return `${Math.round(demandValue).toLocaleString()} passengers/day`;
    }

    function getDemandStyle(wayId: string): L.PathOptions {
        const props = geoData.wayData[wayId];
        const demandValue = getDemandValue(wayId);
        let color = COLOR_GRAY;
        const weight = getLineWeight(geoData, props, criteriaHour, lineWeightBy);
        if (demandValue !== undefined) {
            color = getColorFromGradient(
                demandValue,
                geoData.metadata.data_census.demand_length?.p5 || 0,
                geoData.metadata.data_census.demand_length?.p95 || 1,
                COLOR_GRADIENT,
            );
        }
        return { color, weight };
    }

    $effect(() => {
        if (!map || !geoData) return;

        wayLayerMap = new Map();

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
                return getDemandValue(wayId) !== undefined;
            },
        );
        const visibleWayIds = filteredFeatures
            .map((feature) => feature?.properties?.way_osm_id)
            .filter((wayId): wayId is string => !!wayId);

        const newLayer = L.geoJSON(
            filteredFeatures.sort((a, b) => {
                const demandA = getDemandValue(a.properties?.way_osm_id) || 0;
                const demandB = getDemandValue(b.properties?.way_osm_id) || 0;
                return demandA - demandB;
            }),
            {
                style: (feature: Feature | undefined) => {
                    const wayId = feature?.properties?.way_osm_id;
                    if (!wayId) return {};
                    return getDemandStyle(wayId);
                },
                onEachFeature: (feature, layer) => {
                    const wayId = feature.properties?.way_osm_id;
                    if (wayId) wayLayerMap.set(wayId, layer as L.Path);
                    if (wayId) {
                        bindWayValueTooltip(layer, formatDemandLabel(wayId));
                    }
                    layer.on("click", (e) => {
                        L.DomEvent.stopPropagation(e);
                        if (wayId) onWaySelect(wayId);
                    });
                    layer.on("mouseover", () => {
                        handleWayMouseOver(layer, wayId, selectedWayId);
                    });
                    layer.on("mouseout", () => {
                        handleWayMouseOut(layer, wayId, selectedWayId, getDemandStyle);
                    });
                },
            },
        ).addTo(map);

        untrack(() => {
            currentLayer = newLayer;
            onLayerCreate(newLayer);
            onVisibleWayIdsChange(visibleWayIds);
        });

        if (filteredFeatures.length > 0) {
            const bounds = newLayer.getBounds();
            if (bounds.isValid()) map.fitBounds(bounds);
        }

        return () => {
            if (currentLayer) {
                map.removeLayer(currentLayer);
                currentLayer = null;
            }
            wayLayerMap = new Map();
            onVisibleWayIdsChange([]);
        };
    });

    $effect(() => {
        const selected = selectedWayId;
        wayLayerMap.forEach((path, wayId) => {
            if (wayId === selected) {
                path.setStyle({ weight: 7, color: "#FFD4B8", opacity: 1 });
                path.bringToFront();
            } else {
                path.setStyle(getDemandStyle(wayId));
            }
        });
    });
</script>