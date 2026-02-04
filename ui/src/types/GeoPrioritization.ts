import type { FeatureCollection } from "geojson";

export interface StatisticsBundle {
    min: number;
    max: number;
    p25: number;
    p75: number;
    mean: number;
    median: number;
    variance: number;
    sd: number;
}

interface HourlyFrequency {
    [hour: string]: StatisticsBundle;
}

export interface GeoPrioritization extends FeatureCollection {
    metadata: {
        region: string;
        gtfs: {
            date: string;
            url: string;
        };
        osm_query: Array<{
            key: string;
            value: string;
            key_exact: boolean;
        }>;
        prioritization: {
            routes_missing: string;
            routes_covered: number;
            routes_total: number;
        };
        data_census: {
            frequency: StatisticsBundle;
            frequency_hour: HourlyFrequency;
            speed_avg: StatisticsBundle | undefined;
            lanes: StatisticsBundle;
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