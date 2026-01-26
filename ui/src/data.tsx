

export const BASE_URL: string = 'http://localhost:5173/';

export const MAP_DARK: string = 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png';
export const MAP_LIGHT: string = 'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png';
export const MAP_INIT_ZOOM: number = 3; // 3
export const MAP_INIT_CENTER: [number, number] = [38.7169, -9.1399];

export type DATA_REGION = { id: string; name: string; geojson: string; date: string };

export const DB_REGIONS: DATA_REGION[] = [
    {
        id: 'lisboa_gtfs2026-01-28_run20260123',
        name: 'Carris, Lisbon, PT',
        geojson: BASE_URL + 'static/data/prioritization_lisboa_gtfs2026-01-28_run20260123.geojson',
        date: '2026-01-28'
    }
]