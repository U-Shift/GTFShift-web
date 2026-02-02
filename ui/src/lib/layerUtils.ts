import * as L from "leaflet";

/**
 * Create a feature popup with standard properties
 */
export const createFeaturePopup = (feature: any, layer: L.Layer) => {
    let properties = feature.properties;

    let rt_str = properties.speed_avg ? `<dt>RT Speed</dt><dd><b>${properties.speed_avg.toFixed(1)} km/h</b></dd>` : '';

    layer.bindPopup(`
        <h6>Way ${properties.way_osm_id}</h6>
        <dl>
            <dt>Bus services/hour</dt>
            <dd><b>${properties.frequency}</b></dd>
            <dt>Is bus lane?</dt>
            <dd><b>${properties.is_bus_lane ? "Yes" : "No"}</b></dd>
            <dt>Total lanes</dt>
            <dd><b>${properties.n_lanes ?? "N/A"}</b></dd>
            <dt>Nr directions</dt>
            <dd><b>${properties.n_directions ?? "N/A"}</b></dd>
            <dt>Lanes in direction</dt>
            <dd><b>${properties.n_lanes_direction ?? "N/A"}</b></dd>
            ${rt_str}
            <dt>OSM Way <i class="fa-solid fa-arrow-up-right-from-square"></i></dt>
            <dd><a href="https://www.openstreetmap.org/way/${properties.way_osm_id}" target="_blank">${properties.way_osm_id}</a></dd>
        </dl>
    `);
};

/**
 * Remove duplicate features by way_osm_id (features repeat for each hour)
 */
export const deduplicateByWayId = (features: any[]): any[] => {
    const uniqueFeatures = [];
    const seenWayIds = new Set();
    for (const feature of features) {
        if (!seenWayIds.has(feature.properties.way_osm_id)) {
            uniqueFeatures.push(feature);
            seenWayIds.add(feature.properties.way_osm_id);
        }
    }
    return uniqueFeatures;
};

/**
 * Calculate min and max values from feature property
 */
export const calculateMinMax = (
    features: any[],
    propertyName: string,
    defaultMin: number = 1
): { min: number; max: number } => {
    const values = features
        .map((f) => f.properties[propertyName] || 0)
        .filter((v) => v > 0);

    if (values.length === 0) {
        return { min: defaultMin, max: defaultMin };
    }

    return {
        min: Math.max(defaultMin, Math.min(...values)),
        max: Math.max(...values),
    };
};
