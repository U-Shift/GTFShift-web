# Debug

# run_20260521_165353
# run_20260526_102424
# run_20260526_161832
# aml_barreiro_cascais_lisboa
# aml_1_aml_2_aml_3_aml_4_barreiro_cascais_lisboa

gtfs_url = "osm_gtfs/aml_barreiro_cascais_lisboa/run_20260521_165353/gtfs_lisboa.zip"
gtfs_osm_url = "osm_gtfs/aml_barreiro_cascais_lisboa/run_20260521_165353/gtfs_lisboa_osm.zip"

gtfs_url = "osm_gtfs/aml_1_aml_2_aml_3_aml_4_barreiro_cascais_lisboa/run_20260527_144749/gtfs_lisboa_manipulated.zip"
gtfs_osm_url = "osm_gtfs/aml_1_aml_2_aml_3_aml_4_barreiro_cascais_lisboa/run_20260527_144749/gtfs_lisboa_osm.zip"

gtfs <- tidytransit::read_gtfs(gtfs_url)
summary(gtfs)
shapes_gtfs <- tidytransit::shapes_as_sf(gtfs$shapes)

gtfs_osm <- tidytransit::read_gtfs(gtfs_osm_url)
summary(gtfs_osm)
gtfs_osm_sf <- tidytransit::shapes_as_sf(gtfs_osm$shapes)
# mapview::mapview(gtfs_osm_sf, layer.name = sprintf("GTFS OSM Shapes (%d)", length(unique(gtfs_osm$shapes$shape_id))), color = "#00b4c5", legend = FALSE, hide = TRUE)


mapview::mapview(gtfs_osm_sf, layer.name = sprintf("GTFS OSM Shapes (%d)", length(unique(gtfs_osm$shapes$shape_id))), color = "#00b4c5", legend = FALSE, hide = TRUE) +
    mapview::mapview(shapes_gtfs, layer.name = sprintf("GTFS Shapes (%d)", length(unique(gtfs$shapes$shape_id))), color = "#fcc9b5", legend = FALSE)

mapview::mapview(shapes_gtfs, layer.name = "GTFS Shapes", color = "#fcc9b5", legend = FALSE) +
    mapview::mapview(osm_shapes, layer.name = "OSM Shapes", color = "#ff006e", legend = FALSE, hide = TRUE) +
    mapview::mapview(gtfs_osm_sf, layer.name = "GTFS OSM Shapes", color = "#00b4c5", legend = FALSE, hide = TRUE)

shape_id_debug = "mqzg"

mapview::mapview(gtfs_osm_sf |> filter(shape_id==shape_id_debug), layer.name = sprintf("GTFS OSM Shapes (%d)", length(unique(gtfs_osm$shapes$shape_id))), color = "#00b4c5", legend = FALSE, hide = TRUE) +
    mapview::mapview(shapes_gtfs |> filter(shape_id==shape_id_debug), layer.name = sprintf("GTFS Shapes (%d)", length(unique(gtfs$shapes$shape_id))), color = "#fcc9b5", legend = FALSE)

# Same, but filter by shape_id_debug
osm_shapes |>
    st_drop_geometry() |>
    filter(grepl("728", route_short_name))
shape_id_debug <- "103_0_DESC_shp"
shape_id_debug <- "204_1_ASC_shp"

shape_id_debug <- gtfs_osm$shapes |>
    sample_n(1) |>
    pull(shape_id)

mapview::mapview(shapes_gtfs |> filter(shape_id == shape_id_debug), layer.name = "GTFS Shapes", color = "#fcc9b5") +
    mapview::mapview(
        gtfs$shapes |> filter(shape_id == shape_id_debug) |> st_as_sf(coords = c("shape_pt_lon", "shape_pt_lat"), crs = 4326),
        layer.name = "GTFS Shapes (txt)", zcol = "shape_pt_sequence", hide = TRUE
    ) +
    mapview::mapview(osm_shapes |> filter(shape_id == shape_id_debug), layer.name = "OSM Shapes", color = "#ff006e", hide = TRUE) +
    mapview::mapview(gtfs_osm_sf |> filter(shape_id == shape_id_debug), layer.name = "GTFS OSM Shapes", color = "#00b4c5", hide = TRUE) +
    mapview::mapview(
        osm_shapes_txt |> filter(shape_id == shape_id_debug) |>
            st_as_sf(coords = c("shape_pt_lon", "shape_pt_lat"), crs = 4326),
        layer.name = "GTFS OSM Shapes (txt)", zcol = "shape_pt_sequence", hide = TRUE
    )
