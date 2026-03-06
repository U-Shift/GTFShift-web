<script lang="ts">
    import { untrack } from "svelte";
    import * as L from "leaflet";
    import { COLOR_GRADIENT_RED, COLOR_GRAY } from "../data";
    import { createFeaturePopup } from "../lib/layerUtils";
    import type { GeoPrioritization } from "../types/GeoPrioritization";
    import type { Feature } from "geojson";

    let {
        map,
        geoData,
        criteriaHour,
        onLayerCreate = (layer) => {},
        onWaySelect = (wayId) => {},
    }: {
        map: L.Map;
        geoData: GeoPrioritization;
        criteriaHour: number;
        onLayerCreate: (layer: L.Layer) => void;
        onWaySelect: (wayId: string) => void;
    } = $props();

    let currentLayer: L.Layer | null = $state(null);

    $effect(() => {
        if (!map || !geoData) return;

        // Filter out features with no speed data
        const filteredFeatures = geoData.features.filter(
            (feature: Feature | undefined) => {
                const wayId = feature?.properties?.way_osm_id;
                const props = wayId ? geoData.wayData[wayId] : undefined;
                return (
                    props?.speed_avg !== undefined && props?.speed_avg !== null
                );
            },
        );

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
                    const props = wayId ? geoData.wayData[wayId] : undefined;
                    let speed_avg = props?.speed_avg || undefined;
                    let colorIndex =
                        speed_avg !== undefined
                            ? Math.min(
                                  Math.ceil(
                                      (speed_avg * COLOR_GRADIENT_RED.length) /
                                          (geoData.metadata.data_census
                                              .speed_avg?.max || 1),
                                  ),
                                  COLOR_GRADIENT_RED.length - 1,
                              )
                            : undefined;
                    return {
                        color:
                            colorIndex !== undefined
                                ? COLOR_GRADIENT_RED.slice().reverse()[
                                      colorIndex
                                  ]
                                : COLOR_GRAY,
                        weight: 2.5,
                    };
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
