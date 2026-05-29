import type { Feature } from "geojson";

export interface StatisticsBundle {
    min: number;
    max: number;
    p5: number;
    p25: number;
    p75: number;
    p95: number;
    mean: number;
    median: number;
    variance: number;
    sd: number;
}

export interface PrioritizationStats {
    extension: number;
    extension_bus_lane: number;
    speed_avg?: number;
    speed_min?: number;
    speed_max?: number;
    n_lanes_avg: number;
    n_lanes_min: number;
    n_lanes_max: number;
}

interface HourlyFrequency {
    [hour: string]: StatisticsBundle;
}

export interface GeoPrioritization {
    features: Feature[];
    wayData: Record<string, any>;
    routes: Record<string, any>;
    shapes: {
        [key: string]: {
            route_id: string;
            route_short_name: string;
            route_long_name: string;
            route_color: string;
            route_type: number;
            direction_id: number;
            schedule: {
                [hour: string]: number;
            };
            stats: PrioritizationStats;
        };
    };
    metadata: {
        region: string;
        gtfs: {
            date: string;
            url: string;
        };
        osm_query: Array<{
            key: string;
            value: string | string[];
            key_exact: boolean;
        }>;
        prioritization: {
            shapes_missing: string[];
            routes_missing: { [key: string]: { n_shapes: number, n_shapes_missing: number } };

            shapes_total: number,
            shapes_found_n: number,
            shapes_missing_n: number,

            shapes_total_frequency: number,
            shapes_found_frequency: number,
            shapes_missing_frequency: number,

            routes_missing_n: number,
            routes_found_n: number
        };
        data_census: {
            frequency: StatisticsBundle;
            frequency_hour: HourlyFrequency;
            speed_avg_length: StatisticsBundle | undefined;
            speed_avg_frequency: StatisticsBundle | undefined;
            lanes_length: StatisticsBundle | undefined;
            lanes_frequency: StatisticsBundle | undefined;
            prioritization_stats_frequency: PrioritizationStats | undefined;
            prioritization_stats_length: PrioritizationStats | undefined;
        };
        rt: {
            url: string;
            period: string;
            stop_buffer_size: number;
        } | undefined;
        execution: {
            moment: string;
            script: string;
            git_commit: string;
        };
        environment: {
            r: string;
            GTFShift: string;
            os: string;
            os_release: string;
        };
    };
}