import * as L from "leaflet";

/**
 * Create a feature popup with standard properties
 */
export const createFeaturePopup = (feature: any, layer: L.Layer) => {
    let properties = feature.properties;

    let rt_str = properties.speed_avg && !isNaN(properties.speed_avg) ? `<dt>Average commercial speed</dt><dd><b>${properties.speed_avg.toFixed(1)} km/h</b></dd>` : '';

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
            <dt>Routes</dt>
            <dd><b>${properties.route_names}</b></dd>
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
 * Calculate data centraity and spread measures
 */
export type DataCensus = {
    min: number | undefined;
    max: number | undefined;
    p25: number | undefined;
    p75: number | undefined;
    mean: number | undefined;
    median: number | undefined;
    variance: number | undefined;
    sd: number | undefined;
};

export const dataCensus = (
    features: any[],
    propertyName: string
): DataCensus | undefined => {
    if (features.length === 0) {
        return undefined;
    }
    const values = features
        .map((f) => f.properties[propertyName] || 0)
        .filter((v) => v > 0);
    
    const sorted = [...values].sort((a, b) => a - b);
    const n = sorted.length;    

    return {
        min: sorted[0],
        max: sorted[n - 1],
        p25: sorted[Math.floor(0.25 * (n - 1))],
        p75: sorted[Math.floor(0.75 * (n - 1))],
        mean: sorted.reduce((a, b) => a + b, 0) / n,
        median: n % 2 === 0 ? (sorted[n / 2 - 1] + sorted[n / 2]) / 2 : sorted[Math.floor(n / 2)],
        variance: sorted.reduce((a, b) => a + Math.pow(b - (sorted.reduce((a, b) => a + b, 0) / n), 2), 0) / n,
        sd: Math.sqrt(sorted.reduce((a, b) => a + Math.pow(b - (sorted.reduce((a, b) => a + b, 0) / n), 2), 0) / n),
    };
}