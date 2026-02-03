import type { FeatureCollection } from "geojson";

export interface GeoPrioritization extends FeatureCollection {
    metadata: {
        region: string;
        generated_at: string;
        gtfs_source: string;
        gtfs_date: string;
        stop_buffer_size_meters: number;
        rt_data_included: boolean;
        rt_data_url: string;
        rt_interval: string;
        r_version: string;
        gtfshift_version: string;
        routes_missing: string;
        routes_covered: number;
        routes_total: number;
        osm_query: Array<{
            key: string;
            value: string;
            key_exact: boolean;
        }>;
    }
}