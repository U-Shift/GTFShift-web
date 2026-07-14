<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_GRADIENT } from "../data";
    import type { GeoPrioritization } from "../types/GeoPrioritization";
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
        selectedWayId = undefined,
        selectedShapeId = undefined,
        onLayerCreate = (layer) => {},
        onVisibleWayIdsChange = (wayIds) => {},
        onWaySelect = (wayId) => {},
    }: {
        map: L.Map;
        geoData: GeoPrioritization;
        criteriaHour: number;
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
        getFrequencyWeightedLineWidth,
        getWayHourlyFrequency,
    } from "../lib/utils";

    function formatParkingLaneLabel(wayId: string): string {
        const lanes = geoData.wayData[wayId]?.n_lanes_parking || 0;
        return `${lanes} parking lanes`;
    }

    function getParkingLaneStyle(wayId: string): L.PathOptions {
        const props = geoData.wayData[wayId];
        const n_lanes_parking = props?.n_lanes_parking || 0;
        const p5 = (geoData.metadata.data_census as any).parking_lanes_length?.p5 ?? 0;
        const p95 = (geoData.metadata.data_census as any).parking_lanes_length?.p95 ?? Math.max(n_lanes_parking, 1);
        const frequency = getWayHourlyFrequency(props, criteriaHour);
        const color = getColorFromGradient(
            n_lanes_parking,
            p5,
            p95,
            COLOR_GRADIENT,
        );
        const weight = getFrequencyWeightedLineWidth(
            frequency,
            geoData.metadata.data_census.frequency_hour[criteriaHour]?.p5,
            geoData.metadata.data_census.frequency_hour[criteriaHour]?.p95,
        );
        return { color, weight };
    }

    $effect(() => {
        if (!map || !geoData) return;

        wayLayerMap = new Map();

        // Filter to segments that have at least 1 parking lane, and optionally by shape
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
                // Only show segments with parking lanes
                return props?.n_lanes_parking !== undefined && props.n_lanes_parking > 0;
            },
        );
        const visibleWayIds = filteredFeatures
            .map((feature) => feature?.properties?.way_osm_id)
            .filter((wayId): wayId is string => !!wayId);

        // Create and add new layer to map, sorted asc so higher counts plot on top
        const newLayer = L.geoJSON(
            filteredFeatures.sort((a, b) => {
                const propsA = a.properties?.way_osm_id
                    ? geoData.wayData[a.properties.way_osm_id]
                    : null;
                const propsB = b.properties?.way_osm_id
                    ? geoData.wayData[b.properties.way_osm_id]
                    : null;
                return (propsA?.n_lanes_parking || 0) - (propsB?.n_lanes_parking || 0);
            }),
            {
                style: (feature: Feature | undefined) => {
                    const wayId = feature?.properties?.way_osm_id;
                    if (!wayId) return {};
                    return getParkingLaneStyle(wayId);
                },
                onEachFeature: (feature, layer) => {
                    const wayId = feature.properties?.way_osm_id;
                    if (wayId) wayLayerMap.set(wayId, layer as L.Path);
                    if (wayId) {
                        bindWayValueTooltip(layer, formatParkingLaneLabel(wayId));
                    }
                    layer.on("click", (e) => {
                        L.DomEvent.stopPropagation(e);
                        if (wayId) onWaySelect(wayId);
                    });
                    layer.on("mouseover", () => {
                        handleWayMouseOver(layer, wayId, selectedWayId);
                    });
                    layer.on("mouseout", () => {
                        handleWayMouseOut(layer, wayId, selectedWayId, getParkingLaneStyle);
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
                path.setStyle(getParkingLaneStyle(wayId));
            }
        });
    });
</script>
