export type RegionLayer = {
    id: string;
    name: string;
    date: string;
    rt_data: boolean;
    files: {
        ways: string;
        way_data: string;
        metadata: string;
        route_data: string;
        shape_data: string;
        boundaries?: string;
        zip: string; // Aggregated data
    };
};

export type DataRegion = {
    id: string;
    name: string;
    region: string;
    logo?: string;
    rt_data: boolean;
    date: string;
    color: string;
    layers: RegionLayer[];
};