

export const BASE_URL = 'http://localhost:5173/';

export const MAP_DARK = 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png';
export const MAP_LIGHT = 'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png';
export const MAP_INIT_ZOOM = 3; // 3
export const MAP_INIT_CENTER = [38.7169, -9.1399];

export const DB_REGIONS = [
    {
        name: 'Carris, Lisbon, PT',
        geojson: BASE_URL + 'static/data/prioritization_lisboa_gtfs2026-01-28_run20260123.geojson',
        date: '2026-01-28'
    }
]