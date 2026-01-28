

export const BASE_URL: string = 'http://localhost:5173';
export const API_URL: string = 'http://127.0.0.1:16361';

export const MAP_DARK: string = 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}{r}.png';
export const MAP_LIGHT: string = 'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}{r}.png';
export const MAP_INIT_ZOOM: number = 3; // 3
export const MAP_INIT_CENTER: [number, number] = [38.7169, -9.1399];

export const COLOR_YELLOW: string = '#DAD887';
export const COLOR_TEAL: string = '#3BC1A8';
export const COLOR_RED: string = '#F63049';
export const COLOR_GRAY: string = '#e6e6e6';

export const COLOR_GRADIENT: string[] = ["#ffffe5","#f7fcc4","#e4f4ac","#c7e89b","#a2d88a","#78c578","#4eaf63","#2f944e","#15793f","#036034","#004529"];
// From https://observablehq.com/@d3/color-schemes

export type DATA_REGION = { id: string; name: string; geojson: string; date: string };

export const DB_REGIONS: DATA_REGION[] = [
    {
        id: 'lisboa_gtfs2026-01-28_run20260123',
        name: 'Carris, Lisbon, PT',
        geojson: BASE_URL + '/static/data/prioritization_lisboa_gtfs2026-01-28_run20260123.geojson',
        date: '2026-01-28'
    },
    {
        id: 'prioritization_cascais_gtfs2026-01-28_run20260127',
        name: 'MobiCascais, Cascais, PT',
        geojson: BASE_URL + '/static/data/prioritization_cascais_gtfs2026-01-28_run20260127.geojson',
        date: '2026-01-28'
    }
]