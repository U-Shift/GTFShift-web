library(mapview)
library(sf)
library(dplyr)

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
shapes_gtfs <- tidytransit::shapes_as_sf(gtfs$shapes)
summary(gtfs)

# Load OSM shapes
osm_shapes <- sf::st_read(sprintf("%s/%s/gtfs_%s/run_%s_%s/shapes_match_%s_gtfs%s_run%s.gpkg", output_root, tolower(region$name), gsub("-", "", gtfs_date), run_date, run_hour, region$name, gtfs_date, run_date))
# names(osm_shapes)
# View(osm_shapes)
nrow(osm_shapes)
osm_shapes <- osm_shapes |> filter(distance_diff < 1000 & points_diff < 500)
nrow(osm_shapes)

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
shapes_osm_merged <- osm_shapes |>
    st_transform(4326) |>
    st_line_merge() |>
    st_cast("MULTILINESTRING")

coords <- st_coordinates(shapes_osm_merged)

shapes_osm_raw <- data.frame(
    shape_id = shapes_osm_merged$shape_id[coords[, "L2"]],
    shape_pt_lat = coords[, "Y"],
    shape_pt_lon = coords[, "X"],
    stringsAsFactors = FALSE
)


# Reorder/reverse points to match the direction of the original shapes in shapes_gtfs
shapes_list <- list()
for (sh_id in unique(shapes_osm_raw$shape_id)) {
    df_sh <- shapes_osm_raw[shapes_osm_raw$shape_id == sh_id, ]
    sh_orig <- shapes_gtfs[shapes_gtfs$shape_id == sh_id, ]
    if (nrow(sh_orig) > 0) {
        gtfs_coords <- st_coordinates(sh_orig)
        gtfs_start <- gtfs_coords[1, c("X", "Y")]

        p_first <- c(df_sh$shape_pt_lon[1], df_sh$shape_pt_lat[1])
        p_last <- c(df_sh$shape_pt_lon[nrow(df_sh)], df_sh$shape_pt_lat[nrow(df_sh)])

        dist_first <- (p_first[1] - gtfs_start[1])^2 + (p_first[2] - gtfs_start[2])^2
        dist_last <- (p_last[1] - gtfs_start[1])^2 + (p_last[2] - gtfs_start[2])^2

        if (dist_last < dist_first) {
            df_sh <- df_sh[nrow(df_sh):1, ]
        }
    }
    df_sh$shape_pt_sequence <- 1:nrow(df_sh)
    shapes_list[[sh_id]] <- df_sh
}

shapes_osm <- do.call(rbind, shapes_list)
rownames(shapes_osm) <- NULL

gtfs_filtered$shapes <- shapes_osm
summary(gtfs_filtered)

# Append _osm to gtfs_file
gtfs_file_osm <- sub(".zip", "_osm.zip", gtfs_file)
tidytransit::write_gtfs(gtfs_filtered, gtfs_file_osm)

# Debug
shapes_osm_sf_points <- shapes_osm |> st_as_sf(coords = c("shape_pt_lon", "shape_pt_lat"), crs = 4326)
shapes_osm_sf_routes <- shapes_osm_sf_points |>
    group_by(shape_id) |>
    summarize(geometry = st_union(geometry)) |>
    st_cast("LINESTRING")

shapes_osm_sf_routes <- tidytransit::shapes_as_sf(shapes_osm)

shape_id_debug <- "165_0_DESC_shp"
mapview(shapes_gtfs |> filter(shape_id == shape_id_debug), layer.name = "Original Shape", color = "gray") +
    mapview(shapes_osm_sf_routes |> filter(shape_id == shape_id_debug), layer.name = "OSM Shape with sort fix", color = "pink") +
    mapview(
        shapes_osm_sf_points |> filter(shape_id == shape_id_debug),
        layer.name = "OSM Points", color = "black", point_size = 0.5, zcol = "shape_pt_sequence"
    )

osm_shapes |> filter(shape_id == shape_id_debug)

gtfs_filtered$shapes <- shapes_osm
