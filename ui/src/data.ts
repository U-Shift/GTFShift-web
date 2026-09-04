import type { DataRegion } from "./types/DataRegion";


export const BASE_URL: string = '.'; // 'https://ushift.tecnico.ulisboa.pt/apps/gtfshift/' // 'https://localhost:5173/';

export const ABOUT_METHODOLOGICAL_SLIDES: string = 'https://ushift.tecnico.ulisboa.pt/~ushift.daemon/apps/gtfshift/slides_gmu_20260512';

export const MAP_DARK: string = 'https://tiles.openfreemap.org/styles/dark';
export const MAP_LIGHT: string = 'https://tiles.openfreemap.org/styles/positron';
export const MAP_LIGHT_OPACITY: number = 0.5;
export const MAP_DARK_OPACITY: number = 0.9;
export const MAP_ATTRIBUTION: string = '&copy; <a href="https://openfreemap.org" target="_blank">OpenFreeMap</a> &copy; <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> contributors';
export const MAP_INIT_ZOOM: number = 3; // 3
export const MAP_INIT_CENTER: [number, number] = [38.7169, -9.1399];

export const COLOR_YELLOW: string = '#DAD887';
export const COLOR_TEAL: string = '#3BC1A8';
export const COLOR_RED: string = '#F63049';
export const COLOR_GRAY: string = '#e6e6e6';

export const COLOR_GRADIENT: string[] = ["#440154", "#440256", "#450457", "#450559", "#46075a", "#46085c", "#460a5d", "#460b5e", "#470d60", "#470e61", "#471063", "#471164", "#471365", "#481467", "#481668", "#481769", "#48186a", "#481a6c", "#481b6d", "#481c6e", "#481d6f", "#481f70", "#482071", "#482173", "#482374", "#482475", "#482576", "#482677", "#482878", "#482979", "#472a7a", "#472c7a", "#472d7b", "#472e7c", "#472f7d", "#46307e", "#46327e", "#46337f", "#463480", "#453581", "#453781", "#453882", "#443983", "#443a83", "#443b84", "#433d84", "#433e85", "#423f85", "#424086", "#424186", "#414287", "#414487", "#404588", "#404688", "#3f4788", "#3f4889", "#3e4989", "#3e4a89", "#3e4c8a", "#3d4d8a", "#3d4e8a", "#3c4f8a", "#3c508b", "#3b518b", "#3b528b", "#3a538b", "#3a548c", "#39558c", "#39568c", "#38588c", "#38598c", "#375a8c", "#375b8d", "#365c8d", "#365d8d", "#355e8d", "#355f8d", "#34608d", "#34618d", "#33628d", "#33638d", "#32648e", "#32658e", "#31668e", "#31678e", "#31688e", "#30698e", "#306a8e", "#2f6b8e", "#2f6c8e", "#2e6d8e", "#2e6e8e", "#2e6f8e", "#2d708e", "#2d718e", "#2c718e", "#2c728e", "#2c738e", "#2b748e", "#2b758e", "#2a768e", "#2a778e", "#2a788e", "#29798e", "#297a8e", "#297b8e", "#287c8e", "#287d8e", "#277e8e", "#277f8e", "#27808e", "#26818e", "#26828e", "#26828e", "#25838e", "#25848e", "#25858e", "#24868e", "#24878e", "#23888e", "#23898e", "#238a8d", "#228b8d", "#228c8d", "#228d8d", "#218e8d", "#218f8d", "#21908d", "#21918c", "#20928c", "#20928c", "#20938c", "#1f948c", "#1f958b", "#1f968b", "#1f978b", "#1f988b", "#1f998a", "#1f9a8a", "#1e9b8a", "#1e9c89", "#1e9d89", "#1f9e89", "#1f9f88", "#1fa088", "#1fa188", "#1fa187", "#1fa287", "#20a386", "#20a486", "#21a585", "#21a685", "#22a785", "#22a884", "#23a983", "#24aa83", "#25ab82", "#25ac82", "#26ad81", "#27ad81", "#28ae80", "#29af7f", "#2ab07f", "#2cb17e", "#2db27d", "#2eb37c", "#2fb47c", "#31b57b", "#32b67a", "#34b679", "#35b779", "#37b878", "#38b977", "#3aba76", "#3bbb75", "#3dbc74", "#3fbc73", "#40bd72", "#42be71", "#44bf70", "#46c06f", "#48c16e", "#4ac16d", "#4cc26c", "#4ec36b", "#50c46a", "#52c569", "#54c568", "#56c667", "#58c765", "#5ac864", "#5cc863", "#5ec962", "#60ca60", "#63cb5f", "#65cb5e", "#67cc5c", "#69cd5b", "#6ccd5a", "#6ece58", "#70cf57", "#73d056", "#75d054", "#77d153", "#7ad151", "#7cd250", "#7fd34e", "#81d34d", "#84d44b", "#86d549", "#89d548", "#8bd646", "#8ed645", "#90d743", "#93d741", "#95d840", "#98d83e", "#9bd93c", "#9dd93b", "#a0da39", "#a2da37", "#a5db36", "#a8db34", "#aadc32", "#addc30", "#b0dd2f", "#b2dd2d", "#b5de2b", "#b8de29", "#bade28", "#bddf26", "#c0df25", "#c2df23", "#c5e021", "#c8e020", "#cae11f", "#cde11d", "#d0e11c", "#d2e21b", "#d5e21a", "#d8e219", "#dae319", "#dde318", "#dfe318", "#e2e418", "#e5e419", "#e7e419", "#eae51a", "#ece51b", "#efe51c", "#f1e51d", "#f4e61e", "#f6e620", "#f8e621", "#fbe723", "#fde725"];
export const COLOR_GRADIENT_RED: string[] = ["#ffffcc", "#fffecb", "#fffec9", "#fffdc8", "#fffdc6", "#fffcc5", "#fffcc4", "#fffbc2", "#fffac1", "#fffac0", "#fff9be", "#fff9bd", "#fff8bb", "#fff8ba", "#fff7b9", "#fff6b7", "#fff6b6", "#fff5b5", "#fff5b3", "#fff4b2", "#fff4b0", "#fff3af", "#fff2ae", "#fff2ac", "#fff1ab", "#fff1aa", "#fff0a8", "#fff0a7", "#ffefa6", "#ffeea4", "#ffeea3", "#ffeda2", "#ffeda0", "#ffec9f", "#ffeb9d", "#ffeb9c", "#ffea9b", "#ffea99", "#ffe998", "#ffe897", "#ffe895", "#ffe794", "#ffe693", "#ffe691", "#ffe590", "#ffe48f", "#ffe48d", "#ffe38c", "#fee28b", "#fee289", "#fee188", "#fee087", "#fee085", "#fedf84", "#fede83", "#fedd82", "#fedc80", "#fedc7f", "#fedb7e", "#feda7c", "#fed97b", "#fed87a", "#fed778", "#fed777", "#fed676", "#fed574", "#fed473", "#fed372", "#fed270", "#fed16f", "#fed06e", "#fecf6c", "#fece6b", "#fecd6a", "#fecb69", "#feca67", "#fec966", "#fec865", "#fec764", "#fec662", "#fec561", "#fec460", "#fec25f", "#fec15e", "#fec05c", "#febf5b", "#febe5a", "#febd59", "#febb58", "#feba57", "#feb956", "#feb855", "#feb754", "#feb553", "#feb452", "#feb351", "#feb250", "#feb14f", "#feb04e", "#feae4d", "#fead4d", "#feac4c", "#feab4b", "#feaa4a", "#fea84a", "#fea749", "#fea648", "#fea547", "#fea347", "#fea246", "#fea145", "#fda045", "#fd9e44", "#fd9d44", "#fd9c43", "#fd9b42", "#fd9942", "#fd9841", "#fd9741", "#fd9540", "#fd9440", "#fd923f", "#fd913f", "#fd8f3e", "#fd8e3e", "#fd8d3d", "#fd8b3c", "#fd893c", "#fd883b", "#fd863b", "#fd853a", "#fd833a", "#fd8139", "#fd8039", "#fd7e38", "#fd7c38", "#fd7b37", "#fd7937", "#fd7736", "#fc7535", "#fc7335", "#fc7234", "#fc7034", "#fc6e33", "#fc6c33", "#fc6a32", "#fc6832", "#fb6731", "#fb6531", "#fb6330", "#fb6130", "#fb5f2f", "#fa5d2e", "#fa5c2e", "#fa5a2d", "#fa582d", "#f9562c", "#f9542c", "#f9522b", "#f8512b", "#f84f2a", "#f74d2a", "#f74b29", "#f64929", "#f64828", "#f54628", "#f54427", "#f44227", "#f44127", "#f33f26", "#f23d26", "#f23c25", "#f13a25", "#f03824", "#f03724", "#ef3524", "#ee3423", "#ed3223", "#ed3123", "#ec2f22", "#eb2e22", "#ea2c22", "#e92b22", "#e92921", "#e82821", "#e72621", "#e62521", "#e52420", "#e42220", "#e32120", "#e22020", "#e11f20", "#e01d20", "#df1c20", "#de1b20", "#dd1a20", "#dc1920", "#db1820", "#da1720", "#d91620", "#d81520", "#d71420", "#d51320", "#d41221", "#d31121", "#d21021", "#d10f21", "#cf0e21", "#ce0d21", "#cd0d22", "#cc0c22", "#ca0b22", "#c90a22", "#c80a22", "#c60923", "#c50823", "#c40823", "#c20723", "#c10723", "#bf0624", "#be0624", "#bc0524", "#bb0524", "#b90424", "#b80424", "#b60425", "#b50325", "#b30325", "#b10325", "#b00225", "#ae0225", "#ac0225", "#ab0225", "#a90125", "#a70126", "#a50126", "#a40126", "#a20126", "#a00126", "#9e0126", "#9c0026", "#9a0026", "#990026", "#970026", "#950026", "#930026", "#910026", "#8f0026", "#8d0026", "#8b0026", "#8a0026", "#880026", "#860026", "#840026", "#820026", "#800026"];
// From https://observablehq.com/@d3/color-schemes

export const DB_REGIONS: DataRegion[] = [
    {
        id: 'prioritisation_lisboa_rt_gtfs2026-02-04_run20260316',
        name: 'Carris',
        region: 'Lisbon, PT',
        rt_data: true,
        logo: BASE_URL + '/static/regions/carris.png',
        date: 'May 2026',
        color: '#003f8f',
        layers: [
            {
                id: 'run_20260806_095220',
                name: 'All network',
                date: 'May 2026',
                rt_data: true,
                matched_frequencies_peak: 100,
                files: {
                    ways: BASE_URL + '/data/lisbon/run_20260806_095220/ways_lisboa_rt_gtfs20260520_run20260806.geojson',
                    boundaries: BASE_URL + '/data/lisbon/run_20260806_095220/prioritisation_area_polygon_lisboa_rt_gtfs20260520_run20260806.geojson',
                    way_data: BASE_URL + '/data/lisbon/run_20260806_095220/way_data_lisboa_rt_gtfs20260520_run20260806.json',
                    metadata: BASE_URL + '/data/lisbon/run_20260806_095220/metadata_lisboa_rt_gtfs20260520_run20260806.json',
                    route_data: BASE_URL + '/data/lisbon/run_20260806_095220/route_data_lisboa_rt_gtfs20260520_run20260806.json',
                    shape_data: BASE_URL + '/data/lisbon/run_20260806_095220/shape_data_lisboa_rt_gtfs20260520_run20260806.json',
                    zip: BASE_URL + '/data/lisbon/run_20260806_095220/lisbon.zip'
                }
            }
        ]
    },
    {
        id: 'aml',
        name: 'Carris Metropolitana',
        region: 'Lisbon Metro Area, PT',
        rt_data: true,
        demand_data: true,
        logo: './static/regions/carrismetropolitana.png',
        date: 'Feb - May 2026',
        color: '#363636',
        layers: [
            {
                id: 'aml_all',
                name: 'All network',
                date: 'May 2026',
                rt_data: true,
                demand_data: true,
                matched_frequencies_peak: 96.4,
                files: {
                    ways: './data/aml_1_2_3_4/aml_cm_all_gtfs20260520_run20260806_aggregation_at_20260825_175619/ways_aml_cm_all_gtfs20260520_run20260806.geojson',
                    boundaries: './data/aml_1_2_3_4/aml_cm_all_gtfs20260520_run20260806_aggregation_at_20260825_175619/prioritisation_area_polygon_aml_cm_all_gtfs20260520_run20260806.geojson',
                    way_data: './data/aml_1_2_3_4/aml_cm_all_gtfs20260520_run20260806_aggregation_at_20260825_175619/way_data_aml_cm_all_gtfs20260520_run20260806.json',
                    metadata: './data/aml_1_2_3_4/aml_cm_all_gtfs20260520_run20260806_aggregation_at_20260825_175619/metadata_aml_cm_all_gtfs20260520_run20260806.json',
                    route_data: './data/aml_1_2_3_4/aml_cm_all_gtfs20260520_run20260806_aggregation_at_20260825_175619/route_data_aml_cm_all_gtfs20260520_run20260806.json',
                    shape_data: './data/aml_1_2_3_4/aml_cm_all_gtfs20260520_run20260806_aggregation_at_20260825_175619/shape_data_aml_cm_all_gtfs20260520_run20260806.json',
                    zip: './data/aml_1_2_3_4/aml_cm_all_gtfs20260520_run20260806_aggregation_at_20260825_175619/aml_1_2_3_4.zip'
                }
            },
            {
                id: 'aml_a1',
                name: 'Area 1',
                date: 'May 2026',
                rt_data: true,
                demand_data: true,
                matched_frequencies_peak: 97.3,
                files: {
                    ways: './data/aml_1/run_20260806_100211/ways_aml_rt_area_1_gtfs20260520_run20260806.geojson',
                    boundaries: './data/aml_1/run_20260806_100211/prioritisation_area_polygon_aml_rt_area_1_gtfs20260520_run20260806.geojson',
                    way_data: './data/aml_1/run_20260806_100211/way_data_aml_rt_area_1_gtfs20260520_run20260806.json',
                    metadata: './data/aml_1/run_20260806_100211/metadata_aml_rt_area_1_gtfs20260520_run20260806.json',
                    route_data: './data/aml_1/run_20260806_100211/route_data_aml_rt_area_1_gtfs20260520_run20260806.json',
                    shape_data: './data/aml_1/run_20260806_100211/shape_data_aml_rt_area_1_gtfs20260520_run20260806.json',
                    zip: './data/aml_1/run_20260806_100211/aml_1.zip'
                }
            },
            {
                id: 'aml_a2',
                name: 'Area 2',
                date: 'May 2026',
                rt_data: true,
                demand_data: true,
                matched_frequencies_peak: 91.9,
                files: {
                    ways: './data/aml_2/run_20260806_101548/ways_aml_rt_area_2_gtfs20260520_run20260806.geojson',
                    boundaries: './data/aml_2/run_20260806_101548/prioritisation_area_polygon_aml_rt_area_2_gtfs20260520_run20260806.geojson',
                    way_data: './data/aml_2/run_20260806_101548/way_data_aml_rt_area_2_gtfs20260520_run20260806.json',
                    metadata: './data/aml_2/run_20260806_101548/metadata_aml_rt_area_2_gtfs20260520_run20260806.json',
                    route_data: './data/aml_2/run_20260806_101548/route_data_aml_rt_area_2_gtfs20260520_run20260806.json',
                    shape_data: './data/aml_2/run_20260806_101548/shape_data_aml_rt_area_2_gtfs20260520_run20260806.json',
                    zip: './data/aml_2/run_20260806_101548/aml_2.zip'
                }
            },
            {
                id: 'aml_a3',
                name: 'Area 3',
                date: 'May 2026',
                rt_data: true,
                demand_data: true,
                matched_frequencies_peak: 99.7,
                files: {
                    ways: './data/aml_3/run_20260806_102830/ways_aml_rt_area_3_gtfs20260520_run20260806.geojson',
                    boundaries: './data/aml_3/run_20260806_102830/prioritisation_area_polygon_aml_rt_area_3_gtfs20260520_run20260806.geojson',
                    way_data: './data/aml_3/run_20260806_102830/way_data_aml_rt_area_3_gtfs20260520_run20260806.json',
                    metadata: './data/aml_3/run_20260806_102830/metadata_aml_rt_area_3_gtfs20260520_run20260806.json',
                    route_data: './data/aml_3/run_20260806_102830/route_data_aml_rt_area_3_gtfs20260520_run20260806.json',
                    shape_data: './data/aml_3/run_20260806_102830/shape_data_aml_rt_area_3_gtfs20260520_run20260806.json',
                    zip: './data/aml_3/run_20260806_102830/aml_3.zip'
                }
            },
            {
                id: 'aml_a4',
                name: 'Area 4',
                date: 'Jul 2026',
                rt_data: true,
                demand_data: true,
                matched_frequencies_peak: 98.29,
                files: {
                    ways: './data/aml_4/run_20260806_103907/ways_aml_rt_area_4_gtfs20260520_run20260806.geojson',
                    boundaries: './data/aml_4/run_20260806_103907/prioritisation_area_polygon_aml_rt_area_4_gtfs20260520_run20260806.geojson',
                    way_data: './data/aml_4/run_20260806_103907/way_data_aml_rt_area_4_gtfs20260520_run20260806.json',
                    metadata: './data/aml_4/run_20260806_103907/metadata_aml_rt_area_4_gtfs20260520_run20260806.json',
                    route_data: './data/aml_4/run_20260806_103907/route_data_aml_rt_area_4_gtfs20260520_run20260806.json',
                    shape_data: './data/aml_4/run_20260806_103907/shape_data_aml_rt_area_4_gtfs20260520_run20260806.json',
                    zip: './data/aml_4/run_20260806_103907/aml_4.zip'
                }
            }
        ]
    },
    {
        id: 'cascais',
        name: 'MobiCascais',
        region: 'Cascais, PT',
        rt_data: false,
        logo: './static/regions/mobicascais.png',
        date: 'May 2026',
        color: '#31bcad',
        layers: [
            {
                id: 'cascais',
                name: 'All network',
                date: 'May 2026',
                rt_data: false,
                matched_frequencies_peak: 100,
                files: {
                    ways: './data/cascais/run_20260825_183932/ways_cascais_gtfs20260520_run20260825.geojson',
                    boundaries: './data/cascais/run_20260825_183932/prioritisation_area_polygon_cascais_gtfs20260520_run20260825.geojson',
                    way_data: './data/cascais/run_20260825_183932/way_data_cascais_gtfs20260520_run20260825.json',
                    metadata: './data/cascais/run_20260825_183932/metadata_cascais_gtfs20260520_run20260825.json',
                    route_data: './data/cascais/run_20260825_183932/route_data_cascais_gtfs20260520_run20260825.json',
                    shape_data: './data/cascais/run_20260825_183932/shape_data_cascais_gtfs20260520_run20260825.json',
                    zip: './data/cascais/run_20260825_183932/cascais.zip'
                }
            }
        ]
    },
    {
        id: 'barreiro',
        name: 'Barreiro',
        region: 'Barreiro, PT',
        logo: './static/regions/tcb.png',
        date: 'May 2026',
        color: '#97d700',
        layers: [
            {
                id: 'barreiro',
                name: 'All network',
                date: 'May 2026',
                matched_frequencies_peak: 97.2,
                files: {
                    ways: './data/barreiro/run_20260825_184250/ways_barreiro_gtfs20260520_run20260825.geojson',
                    boundaries: './data/barreiro/run_20260825_184250/prioritisation_area_polygon_barreiro_gtfs20260520_run20260825.geojson',
                    way_data: './data/barreiro/run_20260825_184250/way_data_barreiro_gtfs20260520_run20260825.json',
                    metadata: './data/barreiro/run_20260825_184250/metadata_barreiro_gtfs20260520_run20260825.json',
                    route_data: './data/barreiro/run_20260825_184250/route_data_barreiro_gtfs20260520_run20260825.json',
                    shape_data: './data/barreiro/run_20260825_184250/shape_data_barreiro_gtfs20260520_run20260825.json',
                    zip: './data/barreiro/run_20260825_184250/barreiro.zip'
                }
            }
        ]
    },
    {
        id: 'prioritisation_porto',
        name: 'STCP',
        region: 'Porto, PT',
        rt_data: true,
        logo: BASE_URL + '/static/regions/stcp.png',
        date: 'May 2026',
        color: '#0074c7',
        layers: [
            {
                id: 'run_20260806_095220',
                name: 'All network',
                date: 'May 2026',
                rt_data: true,
                matched_frequencies_peak: 74.8,
                // TODO! Rerun to fix speed <70% 
                // > 673 (0.10%) have at least 70.00% of updates ratio (updates_count / planned_updates_count)
                files: {
                    ways: BASE_URL + '/data/porto/run_20260827_111247/ways_stcp_gtfs20260520_run20260827.geojson',
                    boundaries: BASE_URL + '/data/porto/run_20260827_111247/prioritisation_area_polygon_stcp_gtfs20260520_run20260827.geojson',
                    way_data: BASE_URL + '/data/porto/run_20260827_111247/way_data_stcp_gtfs20260520_run20260827.json',
                    metadata: BASE_URL + '/data/porto/run_20260827_111247/metadata_stcp_gtfs20260520_run20260827.json',
                    route_data: BASE_URL + '/data/porto/run_20260827_111247/route_data_stcp_gtfs20260520_run20260827.json',
                    shape_data: BASE_URL + '/data/porto/run_20260827_111247/shape_data_stcp_gtfs20260520_run20260827.json',
                    zip: BASE_URL + '/data/porto/run_20260827_111247/porto.zip'
                }
            }
        ]
    },
    {
        id: 'madrid',
        name: 'EMT Madrid',
        region: 'Madrid, ES',
        rt_data: false,
        logo: './static/regions/emt.png',
        date: 'May 2026',
        color: '#2c7abf',
        layers: [
            {
                id: 'madrid',
                name: 'All network',
                date: 'May 2026',
                rt_data: false,
                matched_frequencies_peak: 88.5,
                files: {
                    ways: './data/madrid/run_20260825_184549/ways_madrid_gtfs20260520_run20260825.geojson',
                    way_data: './data/madrid/run_20260825_184549/way_data_madrid_gtfs20260520_run20260825.json',
                    metadata: './data/madrid/run_20260825_184549/metadata_madrid_gtfs20260520_run20260825.json',
                    route_data: './data/madrid/run_20260825_184549/route_data_madrid_gtfs20260520_run20260825.json',
                    shape_data: './data/madrid/run_20260825_184549/shape_data_madrid_gtfs20260520_run20260825.json',
                    boundaries: './data/madrid/run_20260825_184549/prioritisation_area_polygon_madrid_gtfs20260520_run20260825.geojson',
                    zip: './data/madrid/run_20260825_184549/madrid.zip'
                }
            }
        ]
    }
]
