library(mapview)
library(sf)
library(dplyr)

# Parameters
output_root <- "osm_match"
gtfs_regions <- data.frame(
    name = character(),
    gtfs_date = character(),
    run_date = character(),
    run_hour = character()
)

gtfs_regions <- bind_rows(
    gtfs_regions,
    data.frame(
        name = "lisboa",
        gtfs_date = "20260519",
        run_date = "20260519",
        run_hour = "151258"
    )
)

# main()
for (i in 1:nrow(gtfs_regions)) {
    region_name <- gtfs_regions$name[i]
    gtfs_date <- gtfs_regions$gtfs_date[i]
    run_date <- gtfs_regions$run_date[i]
    run_hour <- gtfs_regions$run_hour[i]
    message(sprintf("Running for %s (GTFS %s | OSM Match %s at %s)", region_name, gtfs_date, run_date, run_hour))

    # Load GTFS
    gtfs_file <- sprintf("%s/%s/gtfs_%s/gtfs_%s_%s.zip", output_root, tolower(region_name), gsub("-", "", gtfs_date), region_name, gtfs_date)
    gtfs <- tidytransit::read_gtfs(gtfs_file)
    summary(gtfs)
    shapes_gtfs <- tidytransit::shapes_as_sf(gtfs$shapes)
    message(sprintf("> GTFS has %s shapes", nrow(shapes_gtfs)))

    # Load OSM shapes
    osm_shapes <- sf::st_read(sprintf("%s/%s/gtfs_%s/run_%s_%s/shapes_match_%s_gtfs%s_run%s.gpkg", output_root, tolower(region_name), gsub("-", "", gtfs_date), run_date, run_hour, region_name, gtfs_date, run_date))
    # names(osm_shapes)
    # View(osm_shapes)
    message(sprintf("> OSM has %s shapes", nrow(osm_shapes)))
    osm_shapes <- osm_shapes |> filter(distance_diff < 1000 & points_diff < 500)
    message(sprintf("> Of those, %d meet distance criteria", nrow(osm_shapes)))

    # Filter GTFS for shapes
    osm_shape_ids <- unique(osm_shapes$shape_id)
    gtfs_trips_with_osm_shapes <- gtfs$trips |>
        filter(shape_id %in% osm_shape_ids) |>
        pull(trip_id) |>
        unique()
    gtfs_filtered <- tidytransit::filter_feed_by_trips(gtfs, trip_ids = gtfs_trips_with_osm_shapes)
    message(sprintf("> GTFS has %s trips", nrow(gtfs$trips)))
    message(sprintf("> Reduced to %s trips meeting distance criteria", nrow(gtfs_filtered$trips)))

    # Replace shapes on GTFS
    message("> Starting conversion of OSM shapes from MULTILINESTRING to LINESTRING (takes some time...)")
    osm_shapes_linestrings <- osm_shapes |>
        # sample_n(10) |> # For debug only
        rowwise() |>
        mutate(geom = multiline_to_sorted_linestring(geom)$geometry) |>
        st_set_geometry("geom")
    # mapview(osm_shapes_linestrings |> filter(shape_id == shape_id_debug), zcol="shape_id")
    shapes_gtfstools <- gtfstools::convert_sf_to_shapes(osm_shapes_linestrings |> st_transform(4326), calculate_distance = FALSE)
    message(sprintf("> OSM MULTILINESTRING → LINESTRING → shapes.txt conversion generated %d points", nrow(shapes_gtfstools)))

    message("> Replacing GTFS shapes with OSM shapes and saving to new GTFS file")
    gtfs_filtered$shapes <- shapes_gtfstools
    summary(gtfs_filtered)

    # Append _osm to gtfs_file
    gtfs_file_osm <- sub(".zip", "_osm_alt.zip", gtfs_file)
    tidytransit::write_gtfs(gtfs_filtered, gtfs_file_osm)
    message(sprintf("> Saved to %s", gtfs_file_osm))
}

# Debug

gtfs_filtered_sf <- tidytransit::shapes_as_sf(gtfs_filtered$shapes)
mapview::mapview(shapes_gtfs, layer.name = "GTFS Shapes", color = "#fcc9b5", legend = FALSE) +
    mapview::mapview(osm_shapes |> filter(shape_id == shape_id_debug), layer.name = "OSM Shapes", color = "#ff006e", legend = FALSE, hide = TRUE) +
    mapview::mapview(gtfs_filtered_sf |> filter(shape_id == shape_id_debug), layer.name = "GTFS OSM Shapes", color = "#00b4c5", legend = FALSE, hide = TRUE)

# Same, but filter by shape_id_debug
shape_id_debug <- "201_2_DESC_shp"
shape_id_debug <- gtfs_filtered$shapes |>
    sample_n(1) |>
    pull(shape_id)
mapview::mapview(shapes_gtfs |> filter(shape_id == shape_id_debug), layer.name = "GTFS Shapes", color = "#fcc9b5") +
    mapview::mapview(osm_shapes |> filter(shape_id == shape_id_debug), layer.name = "OSM Shapes", color = "#ff006e", hide = TRUE) +
    mapview::mapview(gtfs_filtered_sf |> filter(shape_id == shape_id_debug), layer.name = "GTFS OSM Shapes", color = "#00b4c5", hide = TRUE)
