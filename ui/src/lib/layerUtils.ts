import * as L from "leaflet";

import type { GeoPrioritization } from "../types/GeoPrioritization";

/**
 * Create a feature popup with standard properties
 */
export const createFeaturePopup = (feature: any, layer: L.Layer, geoData: GeoPrioritization, hour: number) => {
    console.log("GEODATA", geoData.shapes)
    const wayId = feature.properties.way_osm_id;
    const properties = geoData.wayData[wayId];

    if (!properties) return;

    let rt_str = properties.speed_avg && !isNaN(properties.speed_avg) ? `<dt>Average speed</dt><dd><b>${properties.speed_avg.toFixed(1)} km/h</b></dd>` : '';

    const frequency = properties.hour_frequency?.[hour] ?? 0;

    layer.bindPopup(`
        <h6>Way ${wayId}</h6>
        <dl>
            <dt>Bus services/hour (at ${hour}:00)</dt>
            <dd><b>${frequency}</b></dd>
            <dt>Is bus lane?</dt>
            <dd><b>${properties.is_bus_lane ? "Yes" : "No"}</b></dd>
            <dt>Total lanes (circulation + parking)</dt>
            <dd><b>${properties.n_lanes ?? "N/A"}</b> (${properties.n_lanes_circulation ?? "N/A"} + ${properties.n_lanes_parking ?? "N/A"})</dd>
            <dt>Nr directions</dt>
            <dd><b>${properties.n_directions ?? "N/A"}</b></dd>
            <dt>Lanes per direction</dt>
            <dd><b>${properties.n_lanes_direction ?? "N/A"}</b></dd>
            ${rt_str}
            <dt>Routes</dt>
            <dd><b>${properties.shapes?.map((shape_id: string) => geoData.shapes[shape_id]?.route_short_name || shape_id).join(', ') ?? 'N/A'}</b></dd>
            <dt>OSM Way <i class="fa-solid fa-arrow-up-right-from-square"></i></dt>
            <dd><a href="https://www.openstreetmap.org/way/${wayId}" target="_blank">${wayId}</a></dd>
        </dl>
    `);
};

