<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_YELLOW, COLOR_TEAL, COLOR_RED } from "../data";
    import type { Feature } from "geojson";
    import type { GeoPrioritisation } from "../types/GeoPrioritisation";
    import type { LineWeightMetric } from "../types/LineWeightMetric";
    import { getLineWeight } from "../lib/utils";

    let {
        map,
        geoData,
        criteriaHour = 8,
        lineWeightBy = "frequency",
        criteriaBusFrequency = 5,
        criteriaBusFrequencyEnabled = true,
        criteriaNLanesDirection = 2,
        criteriaNLanesDirectionEnabled = true,
        criteriaNLanesParking = 1,
        criteriaNLanesParkingEnabled = false,
        criteriaAvgSpeed = undefined,
        criteriaAvgSpeedEnabled = true,
        criteriaDemand = undefined,
        criteriaDemandEnabled = false,
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
        criteriaBusFrequency: number;
        criteriaBusFrequencyEnabled: boolean;
        criteriaNLanesDirection: number;
        criteriaNLanesDirectionEnabled: boolean;
        criteriaNLanesParking: number;
        criteriaNLanesParkingEnabled: boolean;
        criteriaAvgSpeed: number | undefined;
        criteriaAvgSpeedEnabled: boolean;
        criteriaDemand: number | undefined;
        criteriaDemandEnabled: boolean;
        selectedWayId: string | undefined;
        selectedShapeId: string | undefined;
        onLayerCreate: (layer: L.Layer) => void;
        onVisibleWayIdsChange: (wayIds: string[]) => void;
        onWaySelect: (wayId: string) => void;
    } = $props();

    let currentLayer: L.Layer | null = $state(null);
    // Map from wayId -> leaflet path layer for highlight control
    let wayLayerMap: Map<string, L.Path> = new Map();

    console.log("LayerBusLanePrioritisation component executing script block");

    let filteredFeatures = $derived.by(() => {
        if (!geoData) return [];
        return geoData.features.filter((feature: Feature | undefined) => {
            const wayId = feature?.properties?.way_osm_id;
            const props = wayId ? geoData.wayData[wayId] : undefined;
            if (!props) return false;

            // Filter by shape if selected
            if (
                selectedShapeId &&
                selectedShapeId !== "all" &&
                !props.shapes?.includes(selectedShapeId)
            ) {
                return false;
            }

            if (props.is_bus_lane) return true;

            const frequencyOk =
                !criteriaBusFrequencyEnabled ||
                (props.hour_frequency?.[criteriaHour] !== undefined &&
                    props.hour_frequency[criteriaHour] >= criteriaBusFrequency);

            const lanesOk =
                !criteriaNLanesDirectionEnabled ||
                (props.n_lanes_circulation !== undefined &&
                    props.n_lanes_circulation_direction !== undefined &&
                    props.n_lanes_circulation_direction >=
                        criteriaNLanesDirection);

            const parkingOk =
                !criteriaNLanesParkingEnabled ||
                (props.n_lanes_parking !== undefined &&
                    props.n_lanes_parking >= criteriaNLanesParking);

            const speedOk =
                !criteriaAvgSpeedEnabled ||
                criteriaAvgSpeed === undefined ||
                (props.speed_avg !== undefined &&
                    props.speed_avg <= criteriaAvgSpeed);

            const demandOk =
                !criteriaDemandEnabled ||
                criteriaDemand === undefined ||
                (!Number.isNaN(Number(props.demand)) &&
                    Number(props.demand) >= criteriaDemand);

            return frequencyOk && lanesOk && parkingOk && speedOk && demandOk;
        });
    });

    function getWayStyle(wayId: string): L.PathOptions {
        const props = geoData.wayData[wayId];
        const weight = getLineWeight(
            geoData,
            props,
            criteriaHour,
            lineWeightBy,
        );
        if (props?.is_bus_lane) {
            const frequencyOk =
                !criteriaBusFrequencyEnabled ||
                (props.hour_frequency?.[criteriaHour] !== undefined &&
                    props.hour_frequency[criteriaHour] >= criteriaBusFrequency);
            const lanesOk =
                !criteriaNLanesDirectionEnabled ||
                (props.n_lanes_circulation !== undefined &&
                    props.n_lanes_circulation_direction !== undefined &&
                    props.n_lanes_circulation_direction >=
                        criteriaNLanesDirection);
            const parkingOk =
                !criteriaNLanesParkingEnabled ||
                (props.n_lanes_parking !== undefined &&
                    props.n_lanes_parking >= criteriaNLanesParking);
            const speedOk =
                !criteriaAvgSpeedEnabled ||
                criteriaAvgSpeed === undefined ||
                (props.speed_avg !== undefined &&
                    props.speed_avg > criteriaAvgSpeed);
            const demandOk =
                !criteriaDemandEnabled ||
                criteriaDemand === undefined ||
                (!Number.isNaN(Number(props.demand)) &&
                    Number(props.demand) >= criteriaDemand);
            return {
                color:
                    frequencyOk && lanesOk && parkingOk && speedOk && demandOk
                        ? COLOR_TEAL
                        : COLOR_YELLOW,
                weight,
            };
        }
        return { color: COLOR_RED, weight };
    }

    $effect(() => {
        if (!map || !geoData) return;

        console.log(
            "LayerBusLanePrioritisation effect running. filteredFeatures length:",
            filteredFeatures.length,
        );
        const visibleWayIds = filteredFeatures
            .map((feature) => feature?.properties?.way_osm_id)
            .filter((wayId): wayId is string => !!wayId);

        wayLayerMap = new Map();

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
                path.setStyle(getWayStyle(wayId));
            }
        });
    });
</script>
