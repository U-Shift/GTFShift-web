# Debug
# gtfs <- tidytransit::read_gtfs("osm_match/barreiro/gtfs_20260518/gtfs_barreiro_20260518.zip")
gtfs <- tidytransit::read_gtfs("osm_match/cascais/gtfs_20260507/gtfs_cascais_20260507.zip")
shapes_gtfs <- tidytransit::shapes_as_sf(gtfs$shapes)
# gtfs_filtered <- tidytransit::read_gtfs("osm_match/barreiro/gtfs_20260518/gtfs_barreiro_20260518_osm.zip")
gtfs_filtered <- tidytransit::read_gtfs("osm_match/cascais/gtfs_20260507/gtfs_cascais_20260507_osm.zip")
summary(gtfs_filtered)
gtfs_filtered_sf <- tidytransit::shapes_as_sf(gtfs_filtered$shapes)
mapview::mapview(gtfs_filtered_sf, layer.name = "GTFS OSM Shapes", color = "#00b4c5", legend = FALSE, hide = TRUE) +
    mapview::mapview(shapes_gtfs, layer.name = "GTFS Shapes", color = "#fcc9b5", legend = FALSE)

mapview::mapview(shapes_gtfs, layer.name = "GTFS Shapes", color = "#fcc9b5", legend = FALSE) +
    mapview::mapview(osm_shapes, layer.name = "OSM Shapes", color = "#ff006e", legend = FALSE, hide = TRUE) +
    mapview::mapview(gtfs_filtered_sf, layer.name = "GTFS OSM Shapes", color = "#00b4c5", legend = FALSE, hide = TRUE)

# Same, but filter by shape_id_debug
osm_shapes |>
    st_drop_geometry() |>
    filter(grepl("728", route_short_name))
shape_id_debug <- "103_0_DESC_shp"
shape_id_debug <- "204_1_ASC_shp"

shape_id_debug <- gtfs_filtered$shapes |>
    sample_n(1) |>
    pull(shape_id)

mapview::mapview(shapes_gtfs |> filter(shape_id == shape_id_debug), layer.name = "GTFS Shapes", color = "#fcc9b5") +
    mapview::mapview(
        gtfs$shapes |> filter(shape_id == shape_id_debug) |> st_as_sf(coords = c("shape_pt_lon", "shape_pt_lat"), crs = 4326),
        layer.name = "GTFS Shapes (txt)", zcol = "shape_pt_sequence", hide = TRUE
    ) +
    mapview::mapview(osm_shapes |> filter(shape_id == shape_id_debug), layer.name = "OSM Shapes", color = "#ff006e", hide = TRUE) +
    mapview::mapview(gtfs_filtered_sf |> filter(shape_id == shape_id_debug), layer.name = "GTFS OSM Shapes", color = "#00b4c5", hide = TRUE) +
    mapview::mapview(
        osm_shapes_txt |> filter(shape_id == shape_id_debug) |>
            st_as_sf(coords = c("shape_pt_lon", "shape_pt_lat"), crs = 4326),
        layer.name = "GTFS OSM Shapes (txt)", zcol = "shape_pt_sequence", hide = TRUE
    )
