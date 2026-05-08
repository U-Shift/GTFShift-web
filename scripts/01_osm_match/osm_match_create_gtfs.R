library(dplyr)
library(mapview)
library(sf)

# MAke sure these variables are defined
output_root
regions
gtfs_date <- "2026-05-05"
run_date <- "20260505"
run_hour <- "090741"

region <- regions |> slice_head(n = 1)

# Load GTFS
gtfs_file <- sprintf("%s/gtfs_%s_%s.zip", output_root, region$name, region$gtfs_day)
gtfs <- GTFShift::load_feed(region$gtfs_url, create_transfers = FALSE)
gtfs_shapes <- tidytransit::shapes_as_sf(gtfs$shapes)
summary(gtfs)

# Load OSM shapes
osm_shapes <- sf::st_read(sprintf("%s/%s/gtfs_%s/run_%s_%s/shapes_match_%s_gtfs%s_run%s.gpkg", output_root, tolower(region$name), gsub("-", "", gtfs_date), run_date, run_hour, region$name, gtfs_date, run_date))
names(osm_shapes)

# Filter GTFS for shapes
osm_shape_ids <- unique(osm_shapes$shape_id)
gtfs_trips_with_osm_shapes <- gtfs$trips |>
    filter(shape_id %in% osm_shape_ids) |>
    pull(trip_id) |>
    unique()
gtfs_filtered <- tidytransit::filter_feed_by_trips(gtfs, trip_ids = gtfs_trips_with_osm_shapes)
summary(gtfs_filtered)

# Replace shapes on GTFS
gtfs_filtered$shapes
shapes_test_multi <- osm_shapes |>
    st_transform(4326) |>
    st_cast("MULTILINESTRING")
nrow(shapes_test_multi)

coords <- st_coordinates(shapes_test_multi)
length(coords)

shapes_test <- data.frame(
    shape_id = shapes_test_multi$shape_id[coords[, "L2"]],
    shape_pt_lat = coords[, "Y"],
    shape_pt_lon = coords[, "X"],
    stringsAsFactors = FALSE
) |>
    group_by(shape_id) |>
    mutate(shape_pt_sequence = row_number()) |>
    ungroup()
shapes_test_sf_points <- shapes_test |> st_as_sf(coords = c("shape_pt_lon", "shape_pt_lat"), crs = 4326)
shapes_test_sf_routes <- tidytransit::shapes_as_sf(shapes_test)

mapview(gtfs_shapes |> filter(shape_id == "143_1_ASC_shp"), layer.name = "Original Shape", color = "gray") +
    mapview(shapes_test_sf_routes |> filter(shape_id == "143_1_ASC_shp"), layer.name = "OSM Shape", color = "black") +
    mapview(shapes_test_sf_points |> filter(shape_id == "143_1_ASC_shp"), layer.name = "OSM Points", color = "black", point_size = 0.5, zcol = "shape_pt_sequence")

gtfs_filtered$shapes <- shapes_test
