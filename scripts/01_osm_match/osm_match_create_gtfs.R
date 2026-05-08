library(mapview)
library(sf)
library(dplyr)

# MAke sure these variables are defined
output_root
regions
region_name <- "barreiro"
gtfs_date <- "20260507"
run_date <- "20260507"
run_hour <- "102413"

region <- regions |> filter(name == region_name)

# Load GTFS
gtfs_file <- sprintf("%s/%s/gtfs_%s/gtfs_%s_%s.zip", output_root, tolower(region$name), gsub("-", "", gtfs_date), region$name, gtfs_date)
gtfs <- GTFShift::load_feed(gtfs_file, create_transfers = FALSE)
summary(gtfs)
shapes_gtfs <- tidytransit::shapes_as_sf(gtfs$shapes)

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
summary(gtfs)
summary(gtfs_filtered)

# Replace shapes on GTFS
gtfs_filtered$shapes
# Process shapes on GTFS by extracting connected segments and sorting them at the segment-level
shapes_list <- list()

for (sh_id in unique(osm_shapes$shape_id)) {
    sh_orig <- shapes_gtfs[shapes_gtfs$shape_id == sh_id, ]
    sh_osm <- osm_shapes[osm_shapes$shape_id == sh_id, ] |> st_transform(4326)

    # 1. Topological line merge to stitch touching segments
    geom_merged <- st_line_merge(st_geometry(sh_osm))

    # 2. Extract independent connected segments (individual LINESTRINGs)
    segments <- st_cast(geom_merged, "LINESTRING")

    # 3. For each segment, determine direction and start distance along original shape
    segment_blocks <- list()
    for (i in seq_along(segments)) {
        seg <- segments[i]
        coords_seg <- st_coordinates(seg)
        p_first <- coords_seg[1, c("X", "Y")]
        p_last <- coords_seg[nrow(coords_seg), c("X", "Y")]

        dist_first <- 0
        dist_last <- 0

        if (nrow(sh_orig) > 0) {
            sf_first <- st_sfc(st_point(p_first), crs = 4326)
            sf_last <- st_sfc(st_point(p_last), crs = 4326)
            dist_first <- st_line_project(st_geometry(sh_orig), sf_first)
            dist_last <- st_line_project(st_geometry(sh_orig), sf_last)

            # If the segment's flow direction is reversed relative to the GTFS route, reverse its points
            if (dist_last < dist_first) {
                coords_seg <- coords_seg[nrow(coords_seg):1, ]
                temp <- dist_first
                dist_first <- dist_last
                dist_last <- temp
            }
        }

        segment_blocks[[i]] <- list(
            coords = coords_seg,
            start_dist = dist_first
        )
    }

    # 4. Sort segment blocks by their start distance along original shape and bind coordinates
    if (length(segment_blocks) > 0) {
        sorted_indices <- order(sapply(segment_blocks, function(x) x$start_dist))
        ordered_coords <- do.call(rbind, lapply(sorted_indices, function(idx) {
            segment_blocks[[idx]]$coords[, c("X", "Y"), drop = FALSE]
        }))

        # Build the final dataframe for this shape
        df_sh <- data.frame(
            shape_id = sh_id,
            shape_pt_lat = ordered_coords[, "Y"],
            shape_pt_lon = ordered_coords[, "X"],
            stringsAsFactors = FALSE
        )
        df_sh$shape_pt_sequence <- 1:nrow(df_sh)
        shapes_list[[sh_id]] <- df_sh
    }
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
shapes_gtfs_filtered <- tidytransit::shapes_as_sf(gtfs_filtered$shapes)

shape_id_debug <- "149-TERM"
shape_id_debug <- gtfs_filtered$shapes |>
    sample_n(1) |>
    pull(shape_id) # Random shape

mapview(shapes_gtfs_filtered |> filter(shape_id == shape_id_debug), layer.name = "Original Shape", color = "#fcc9b5") +
    mapview(shapes_osm_sf_routes |> filter(shape_id == shape_id_debug), layer.name = "OSM Shape", color = "#00b4c5") +
    mapview(
        shapes_osm_sf_points |> filter(shape_id == shape_id_debug),
        layer.name = "OSM Points", color = "#0073e6", point_size = 0.5, zcol = "shape_pt_sequence"
    )

osm_shapes |> filter(shape_id == shape_id_debug)

gtfs_filtered$shapes <- shapes_osm


# View all network
mapview::mapview(shapes_gtfs_filtered, layer.name = "GTFS Shapes", color = "#fcc9b5", legend = FALSE) +
    mapview::mapview(shapes_osm_sf_routes, layer.name = "OSM Shapes", color = "#00b4c5", legend = FALSE) +
    mapview::mapview(shapes_osm_sf_points, layer.name = "OSM Points", color = "#0073e6", point_size = 0.2)
