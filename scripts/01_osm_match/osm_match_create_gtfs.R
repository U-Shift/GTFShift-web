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
    message(sprintf("> OSM has %s shapes (meeting distance criteria)", nrow(osm_shapes)))

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
    # gtfs_filtered$shapes
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

    # shapes_alternative -------------
    shapes_osm_alternative <- osm_shapes |>
        st_transform(4326) |>
        st_cast("MULTILINESTRING")
    coords <- st_coordinates(shapes_osm_alternative)
    shapes_osm_alternative_points <- data.frame(
        shape_id = shapes_osm_alternative$shape_id[coords[, "L2"]],
        shape_pt_lat = coords[, "Y"],
        shape_pt_lon = coords[, "X"],
        stringsAsFactors = FALSE
    ) |>
        group_by(shape_id) |>
        mutate(shape_pt_sequence = row_number()) |>
        ungroup()


    # shapes_alternative -------------

    gtfs_filtered$shapes <- shapes_osm
    summary(gtfs_filtered)

    # Append _osm to gtfs_file
    gtfs_file_osm <- sub(".zip", "_osm_alt.zip", gtfs_file)
    tidytransit::write_gtfs(gtfs_filtered, gtfs_file_osm)
}

# Debug
View(osm_shapes |> st_drop_geometry())
shapes_osm_sf_points <- shapes_osm |> st_as_sf(coords = c("shape_pt_lon", "shape_pt_lat"), crs = 4326)
shapes_gtfs_filtered <- tidytransit::shapes_as_sf(gtfs_filtered$shapes)
shapes_osm_alternative_points_sf <- tidytransit::shapes_as_sf(shapes_osm_alternative_points)

shapes_osm_merged <- osm_shapes |>
    # sample_n(1) |>
    group_by(shape_id) |>
    summarise(do_union = FALSE) |>
    ungroup() |>
    st_line_merge()
st_cast("MULTILINESTRING") |>
    st_cast("LINESTRING")
nrow(shapes_osm_merged)
shapes_osm_merged_linestrings <- shapes_osm_merged[st_geometry_type(shapes_osm_merged) == "LINESTRING", ]
nrow(shapes_osm_merged_linestrings)

shapes_gtfstools <- gtfstools::convert_sf_to_shapes(shapes_osm_merged_linestrings |> st_transform(4326), calculate_distance = FALSE)
nrow(shapes_gtfstools)
shapes_gtfstools_sf <- tidytransit::shapes_as_sf(shapes_gtfstools)

# Filter more than 1 occurance
table(shapes_osm_merged_linestrings$shape_id) |>
    as.data.frame() |>
    filter(Freq > 1)

gtfs_shapes_points_sf <- gtfs$shapes |> st_as_sf(coords = c("shape_pt_lon", "shape_pt_lat"), crs = 4326)
shapes_osm_merged_linestrings_sorted <- shapes_osm_merged_linestrings |>
    # For each shape_id, sort linestrings according to proximity to gtfs$shapes points and its shape_pt_sequence
    group_split(shape_id) |>
    purrr::map_dfr(function(shape_linestrings) {
        # shape_linestrings <- shapes_osm_merged_linestrings |> filter(shape_id == shape_id_debug)
        shape_id <- unique(shape_linestrings$shape_id)
        shape_points_gtfs <- gtfs_shapes_points_sf |>
            filter(shape_id == !!shape_id) |>
            st_transform(3857)

        # For each shape_linestrings, find points in buffer and determine average of shape_pt_sequence
        shape_linestrings <- shape_linestrings |>
            mutate(row_n = 1:n())
        shape_linestrings_matched <- shape_linestrings |>
            st_transform(3857) |>
            st_buffer(50) |>
            st_join(shape_points_gtfs |> select(shape_pt_sequence), join = st_intersects) |>
            group_by(row_n, shape_id) |>
            summarise(shape_pt_sequence = median(shape_pt_sequence, na.rm = TRUE)) |>
            ungroup()


        # Sort linestrings by shape_pt_sequence
        shape_linestrings_sorted <- shape_linestrings |>
            left_join(shape_linestrings_matched |> st_drop_geometry() |> select(row_n, shape_pt_sequence), by = "row_n") |>
            arrange(shape_pt_sequence)
        shape_linestrings_sorted
    })

# For each row (linestring), split into several lines of points, then for each shape_id, sort points by shape_pt_sequence and row number
shapes_osm_merged_linestrings_sorted_coords <- st_coordinates(shapes_osm_merged_linestrings_sorted)
shapes_osm_merged_linestrings_sorted_points <- data.frame(
    shape_id = shapes_osm_merged_linestrings_sorted$shape_id[shapes_osm_merged_linestrings_sorted_coords[, "L1"]],
    shape_pt_lat = shapes_osm_merged_linestrings_sorted_coords[, "Y"],
    shape_pt_lon = shapes_osm_merged_linestrings_sorted_coords[, "X"],
    stringsAsFactors = FALSE
) |>
    group_by(shape_id) |>
    mutate(shape_pt_sequence = row_number()) |>
    ungroup()
shapes_osm_merged_linestrings_sorted_points_sf <- tidytransit::shapes_as_sf(shapes_osm_merged_linestrings_sorted_points)

shapes_osm_merged_linestrings_sorted_gtfstools <- gtfstools::convert_sf_to_shapes(shapes_osm_merged_linestrings_sorted, calculate_distance = FALSE)
table((shapes_osm_merged_linestrings_sorted_gtfstools |> filter(shape_id == shape_id_debug))$shape_pt_sequence) |>
    as.data.frame() |>
    filter(Freq > 1)
shapes_osm_merged_linestrings_sorted_gtfstools_sf <- tidytransit::shapes_as_sf(shapes_osm_merged_linestrings_sorted_gtfstools)
# DEbug specific shape
shape_id_debug <- "201_2_DESC_shp"
# shape_id_debug <- "204_1_DESC_shp"
# shape_id_debug <- gtfs_filtered$shapes |>
#    sample_n(1) |>
#    pull(shape_id) # Random shape

shape_id_name <- sprintf(
    "%s - %s %d (%s - %s)", osm_shapes |> filter(shape_id == shape_id_debug) |> pull(route_short_name),
    osm_shapes |> filter(shape_id == shape_id_debug) |> pull(route_long_name),
    osm_shapes |> filter(shape_id == shape_id_debug) |> pull(direction_id),
    osm_shapes |> filter(shape_id == shape_id_debug) |> pull(shape_id),
    osm_shapes |> filter(shape_id == shape_id_debug) |> pull(osm_id)
)
shape_id_name

# Filter more than 1 occurance
table((shapes_gtfstools |> filter(shape_id == shape_id_debug))$shape_pt_sequence) |>
    as.data.frame() |>
    filter(Freq > 1)

if (nrow(shapes_gtfstools |> filter(shape_id == shape_id_debug)) == 0) {
    stop("Shape ID not found")
}

# GTFS Original
mapview(
    gtfs$shapes |> filter(shape_id == shape_id_debug) |> st_as_sf(coords = c("shape_pt_lon", "shape_pt_lat"), crs = 4326),
    layer.name = paste(shape_id_name, "GTFS Points", sep = ": "), color = "#0073e6", point_size = 0.5, zcol = "shape_pt_sequence", hide = TRUE
) +
    mapview(shapes_gtfs |> filter(shape_id == shape_id_debug), layer.name = paste(shape_id_name, "GTFS Shape", sep = ": "), color = "#8cc6a6", hide = TRUE) +
    # OSM original
    mapview(
        shapes_osm_alternative_points |> filter(shape_id == shape_id_debug) |> st_as_sf(coords = c("shape_pt_lon", "shape_pt_lat"), crs = 4326),
        layer.name = paste(shape_id_name, "OSM Original Points (Raw)", sep = ": "), color = "#0073e6", point_size = 0.5, zcol = "shape_pt_sequence", hide = TRUE
    ) +
    mapview(osm_shapes |> filter(shape_id == shape_id_debug), layer.name = paste(shape_id_name, "OSM Original Geometry", sep = ": "), color = "#00b4c5", hide = TRUE) +
    mapview(shapes_osm_alternative_points_sf |> filter(shape_id == shape_id_debug), layer.name = paste(shape_id_name, "OSM Original Points to Shapes", sep = ": "), color = "#ff0000", hide = TRUE) +
    # OSM Gtfstools
    mapview(
        shapes_gtfstools |> filter(shape_id == shape_id_debug) |> st_as_sf(coords = c("shape_pt_lon", "shape_pt_lat"), crs = 4326),
        layer.name = paste(shape_id_name, "OSM Original Gtfstools", sep = ": "), color = "#9a1688", point_size = 0.5, zcol = "shape_pt_sequence", hide = TRUE
    ) +
    mapview(
        shapes_gtfstools_sf |> filter(shape_id == shape_id_debug),
        layer.name = paste(shape_id_name, "OSM Original Gtfstools (sf)", sep = ": "), color = "#ff006e", hide = TRUE
    ) +
    # OSM merged
    mapview(shapes_osm_merged |> filter(shape_id == shape_id_debug) |> mutate(row_n = 1:n()), layer.name = paste(shape_id_name, "OSM Merged Geometry", sep = ": "), zcol = "row_n", hide = TRUE) +
    mapview(shapes_osm_merged_linestrings_sorted |> filter(shape_id == shape_id_debug) |> mutate(row_n = 1:n()), layer.name = paste(shape_id_name, "OSM Merged Geometry Sorted", sep = ": "), zcol = "row_n", hide = TRUE) +
    mapview(
        shapes_osm_merged_linestrings_sorted_gtfstools |> filter(shape_id == shape_id_debug) |> st_as_sf(coords = c("shape_pt_lon", "shape_pt_lat"), crs = 4326),
        layer.name = paste(shape_id_name, "OSM Merged Geometry Sorted Gtfstools", sep = ": "), hide = TRUE,
        color = "#0073e6", point_size = 0.5, zcol = "shape_pt_sequence"
    ) +
    mapview(
        shapes_osm_merged_linestrings_sorted_gtfstools_sf |> filter(shape_id == shape_id_debug),
        layer.name = paste(shape_id_name, "OSM Merged Geometry Sorted Gtfstools (sf)", sep = ": "), hide = TRUE,
        color = "#ff006e"
    ) +
    mapview(
        shapes_osm_merged_linestrings_sorted_points |> filter(shape_id == shape_id_debug) |> st_as_sf(coords = c("shape_pt_lon", "shape_pt_lat"), crs = 4326),
        layer.name = paste(shape_id_name, "OSM Merged Geometry Manually Sorted Points", sep = ": "), point_size = 0.5, zcol = "shape_pt_sequence", hide = TRUE
    ) +
    mapview(
        shapes_osm_merged_linestrings_sorted_points_sf |> filter(shape_id == shape_id_debug),
        layer.name = paste(shape_id_name, "OSM Merged Geometry Manually Sorted Points (sf)", sep = ": "), color = "#ff006e", hide = TRUE
    ) +
    # GTFS with OSM
    mapview(
        shapes_osm_sf_points |> filter(shape_id == shape_id_debug),
        layer.name = paste(shape_id_name, "GTFS OSM Points (Sorted)", sep = ": "), color = "#0073e6", point_size = 0.5, zcol = "shape_pt_sequence"
    ) +
    mapview(shapes_gtfs_filtered |> filter(shape_id == shape_id_debug), layer.name = paste(shape_id_name, "GTFS OSM Shape", sep = ": "), color = "#fcc9b5", hide = TRUE)


osm_shapes |> filter(shape_id == shape_id_debug)


# View all network
mapview::mapview(shapes_gtfs, layer.name = "GTFS Shapes", color = "#fcc9b5", legend = FALSE) +
    mapview::mapview(shapes_gtfs_filtered, layer.name = "GTFS OSM Shapes", color = "#00b4c5", legend = FALSE, hide = TRUE) +
    mapview::mapview(osm_shapes, layer.name = "OSM Shapes", color = "#ff006e", legend = FALSE, hide = TRUE) +
    mapview::mapview(shapes_osm_sf_points, layer.name = "OSM Points", color = "#0073e6", point_size = 0.2, hide = TRUE) +
    mapview(shapes_osm_merged_linestrings_sorted_gtfstools_sf, layer.name = "OSM Merged Geometry Sorted Gtfstools (sf)", color = "#ff006e", hide = TRUE)
