<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_TEAL } from "../data";
    import type { Feature } from "geojson";
    import type { GeoPrioritisation } from "../types/GeoPrioritisation";
    import type { LineWeightMetric } from "../types/LineWeightMetric";
    import { getLineWeight } from "../lib/utils";

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

    function getWayStyle(wayId: string): L.PathOptions {
        const props = geoData.wayData[wayId];
        const weight = getLineWeight(
            geoData,
            props,
            criteriaHour,
            lineWeightBy,
        );
        return { color: COLOR_TEAL, weight };
    }

    $effect(() => {
        if (!map || !geoData) return;

        wayLayerMap = new Map();

        // Filter for bus lanes
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
                return props?.is_bus_lane;
            },
        );
        const visibleWayIds = filteredFeatures
            .map((feature) => feature?.properties?.way_osm_id)
            .filter((wayId): wayId is string => !!wayId);

        // Create and add new layer to map
        const newLayer = L.geoJSON(filteredFeatures, {
            style: (feature: Feature | undefined) => {
                const wayId = feature?.properties?.way_osm_id;
                if (!wayId) return {};
                return getWayStyle(wayId);
            },
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
                        (layer as L.Path).setStyle(getWayStyle(wayId));
                    }
                });
            },
        }).addTo(map);

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
                path.setStyle(getWayStyle(wayId));
            }
        });
    });
</script>
