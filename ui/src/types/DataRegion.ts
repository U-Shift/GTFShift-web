export type DataRegion = {
    id: string;
    name: string;
    region: string;
    logo?: string;
    files: {
        ways: string;
        way_data: string;
        metadata: string;
        route_data: string;
        shape_data: string;
        zip: string; // Aggregated data
    };
    date: string;
    color: string;
};