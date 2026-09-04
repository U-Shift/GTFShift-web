# GTFS RT commercial speed computation
# Run with: $ Rscript 00_fetch_rt/4_compute_speed/gtfs_rt_average_speed.R > data/cmet_20260413_220260430_business_a3/processing_speed_shape_distance/gtfs_rt_average_speed.log 2>&1

library(jsonlite)
library(lubridate)
library(geosphere)
library(dplyr)
library(readr)
library(sf)

## Parameters ---------------------------------------------------------------------
METRIC_CRS <- 3763 # Portugal
THRESHOLD_GEOMETRY_DISTANCE_DIFF <- 1000
THRESHOLD_GEOMETRY_POINTS_DIFF <- 500

gtfs_rt_average_speed <- function(UPDATES_RAW_FOLDER, OUTPUT_FOLDER, GTFS_FEED_URL, GTFS_MANIPULATE, OSM_SHAPES, UPDATES_MANIPULATE=NULL) {
    
  if (!dir.exists(OUTPUT_FOLDER)) {
    dir.create(OUTPUT_FOLDER, recursive = TRUE)
  }

  ### 1. Load GTFS 
  message("Loading GTFS feed...")
  gtfs = tidytransit::read_gtfs(GTFS_FEED_URL)
  if (!is.null(GTFS_MANIPULATE)) {
    message(sprintf("Manipulating GTFS feed with function: %s", GTFS_MANIPULATE))
    gtfs = do.call(GTFS_MANIPULATE, list(gtfs))
  }

  ### 2. Load OSM shapes 
  message("Loading OSM shapes...")
  osm_shapes = st_read(OSM_SHAPES)
  message(sprintf("Loaded %d OSM shapes", nrow(osm_shapes)))

  ### 3. Convert OSM shapes to LINESTRING  
  message("Converting OSM shapes to LINESTRING...")
  osm_shapes_file = file.path(OUTPUT_FOLDER, "osm_shapes_linestring.gpkg")
  if (file.exists(osm_shapes_file)) {
    message(sprintf("OSM shapes LINESTRING file already exists: %s", osm_shapes_file))
    osm_shapes_linestring = st_read(osm_shapes_file)
  } else {
    message(sprintf("OSM shapes LINESTRING file does not exist, creating it: %s", osm_shapes_file))

    # > Build points per shape from GTFS
    # > - circular trip (first stop_id == last stop_id): use all stops
    # > - otherwise: use only first stop
    trips_by_shape = gtfs$trips |>
      select(shape_id, trip_id) |>
      distinct(shape_id, .keep_all = TRUE)

    stop_points_by_trip = gtfs$stop_times |>
      filter(trip_id %in% trips_by_shape$trip_id) |>
      select(trip_id, stop_id, stop_sequence) |>
      arrange(trip_id, stop_sequence) |>
      group_by(trip_id) |>
      mutate(
        first_stop_id = first(stop_id),
        last_stop_id = last(stop_id),
        is_circular = first_stop_id == last_stop_id,
        keep_stop = if_else(is_circular, TRUE, row_number() %in% c(1,2)) # Keep all stops if circular, otherwise keep only first two stops
      ) |>
      ungroup() |>
      filter(keep_stop) |>
      left_join(
        gtfs$stops |> select(stop_id, stop_lat, stop_lon),
        by = c("stop_id" = "stop_id"),
        multiple = "first"
      ) |>
      filter(!is.na(stop_lon) & !is.na(stop_lat)) |>
      arrange(trip_id, stop_sequence)

    stop_points_by_trip = split(stop_points_by_trip, stop_points_by_trip$trip_id)
    stop_points_by_trip = tibble::tibble(
      trip_id = names(stop_points_by_trip),
      points = lapply(stop_points_by_trip, function(x) {
        st_as_sf(x, coords = c("stop_lon", "stop_lat"), crs = 4326, remove = FALSE) |> st_geometry()
      }),
      n_points = sapply(stop_points_by_trip, nrow)
    )

    osm_shapes_points = osm_shapes |>
      st_drop_geometry() |>
      select(osm_id, shape_id) |>
      left_join(trips_by_shape, by = c("shape_id" = "shape_id"), multiple = "first") |>
      left_join(stop_points_by_trip, by = c("trip_id" = "trip_id"), multiple = "first")

    # mapview(osm_shapes_points)
    assertthat::are_equal(nrow(osm_shapes_points), nrow(osm_shapes))
    # > Join OSM shapes with reference points
    osm_shapes_base_data = osm_shapes |> st_drop_geometry() |> select(osm_id, shape_id) |>
      left_join(
        osm_shapes_points |> select(osm_id, points, n_points),
        by = c("osm_id" = "osm_id")
      ) |> 
      left_join(
        osm_shapes |> select(osm_id, geom) |> rename(osm_geometry = geom),
        by = c("osm_id" = "osm_id")
      )
    # > Filter OSM shapes with points
    message(sprintf("Filtering OSM shapes to those with points (n_points > 0), removing %d shapes without points", sum(is.na(osm_shapes_base_data$n_points) | osm_shapes_base_data$n_points == 0)))
    osm_shapes_base_data = osm_shapes_base_data |> filter(!is.na(n_points) & n_points > 0)

    # mapview((osm_shapes_base_data |> filter(shape_id=="109_3_ASC_shp"))$osm_geometry) + mapview((osm_shapes_base_data |> filter(shape_id=="109_3_ASC_shp"))$points)
    # > Convert to LINESTRING
    start_time = Sys.time()
    osm_shapes_linestring = osm_shapes_base_data |>
      rowwise() |>
      mutate(
        osm_geometry = GTFShift::multiline_to_sorted_linestring(
          multilinestring = osm_geometry,
          points = points,
          metric_crs = METRIC_CRS
        )
      ) |>
      ungroup() |>
      select(osm_id, shape_id, osm_geometry) |> 
      st_as_sf()
    end_time = Sys.time()
    message(sprintf("Done! Time taken to convert %d OSM shapes to LINESTRING: %.2f seconds", nrow(osm_shapes_base_data), as.numeric(difftime(end_time, start_time, units = "secs"))))
    st_write(osm_shapes_linestring, osm_shapes_file, delete_dsn = TRUE)
  }

  # Filter osm_shapes_linestring to those on osm_shapes (that match thresholds)
  osm_shapes = osm_shapes |> filter(distance_diff < THRESHOLD_GEOMETRY_DISTANCE_DIFF & points_diff < THRESHOLD_GEOMETRY_POINTS_DIFF)
  message(sprintf("Filtered OSM shapes to %d with distance_diff < %d and points_diff < %d", nrow(osm_shapes), THRESHOLD_GEOMETRY_DISTANCE_DIFF, THRESHOLD_GEOMETRY_POINTS_DIFF))
  # mapview(osm_shapes)
  osm_shapes_linestring = osm_shapes_linestring |> filter(osm_id %in% osm_shapes$osm_id)
  message(sprintf("Filtered OSM shapes LINESTRING to %d with distance_diff < %d and points_diff < %d", nrow(osm_shapes_linestring), THRESHOLD_GEOMETRY_DISTANCE_DIFF, THRESHOLD_GEOMETRY_POINTS_DIFF))

  # stop("Stopping execution after OSM shapes LINESTRING conversion. Remove this stop() to proceed with speed computation.")

  ### 4. Compute speed between updates
  message("Starting computation of average speed between updates...")
  csv_files <- list.files(UPDATES_RAW_FOLDER, pattern = "updates_raw.*\\.csv$", full.names = TRUE)
  message("Found %d files in %s, starting processing...", length(csv_files), UPDATES_RAW_FOLDER)
  # Example: "data/cm_20260413_220260430_business/processing_speed_shape_distance/updates_raw_20260413.csv"
  csv_files_dates <- sort(unique( substr(basename(csv_files), 13, 20) ))
  for (date in csv_files_dates) {
    message(sprintf("> Processing date: %s", date))
    RECORDS <- read.csv(file.path(UPDATES_RAW_FOLDER, sprintf("updates_raw_%s.csv", date)))
    if (!is.null(UPDATES_MANIPULATE)) {
      message(sprintf("> Manipulating updates with function: %s", UPDATES_MANIPULATE))
      RECORDS <- do.call(UPDATES_MANIPULATE, list(RECORDS))
    }
    

    # Get shape_id for each trip 
    RECORDS <- RECORDS |>
      left_join(
        gtfs$trips |> select(trip_id, shape_id),
        by = c("trip_id" = "trip_id"), multiple="first"
      ) |>
      left_join(
        osm_shapes_linestring |> st_drop_geometry() |> select(shape_id, osm_id),
        by = c("shape_id" = "shape_id"), multiple="first"
      )
    
    message(sprintf("> Loaded %d records", nrow(RECORDS)))
    RECORDS_WITH_GTFS_MATCH <- RECORDS |> filter(!is.na(shape_id))
    message(sprintf("> Number of records with GTFS match: %d (%.2f%%)", nrow(RECORDS_WITH_GTFS_MATCH), nrow(RECORDS_WITH_GTFS_MATCH) / nrow(RECORDS) * 100))
    RECORDS_WITH_OSM_MATCH <- RECORDS |> filter(!is.na(osm_id))
    message(sprintf("> Number of records with OSM match: %d (%.2f%%)", nrow(RECORDS_WITH_OSM_MATCH), nrow(RECORDS_WITH_OSM_MATCH) / nrow(RECORDS) * 100))
    RECORDS_WITH_GTFS_AND_OSM_MATCH <- RECORDS |> filter(!is.na(shape_id) & !is.na(osm_id))
    message(sprintf("> Number of records with GTFS and OSM match: %d (%.2f%%)", nrow(RECORDS_WITH_GTFS_AND_OSM_MATCH), nrow(RECORDS_WITH_GTFS_AND_OSM_MATCH) / nrow(RECORDS) * 100))

    start_time = Sys.time()
    result <- GTFShift::rt_average_speed(
      rt_collection = RECORDS_WITH_GTFS_AND_OSM_MATCH |> st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE),
      trips_geometries = osm_shapes_linestring,
      rt_collection_trips_geometries_match_col = "osm_id",
      metric_crs = METRIC_CRS
    )
    end_time = Sys.time()
    message(sprintf("> Done! Time taken to compute speed for %d records: %.2f seconds", nrow(result), as.numeric(difftime(end_time, start_time, units = "secs"))))
    
    message(sprintf("> Computed speed for %d records, with %.2f average updates per trip and an average speed of %.2f km/h", 
      nrow(result), 
      mean(result |> group_by(trip_id) |> summarise(updates_count = n(), .groups = "drop") |> pull(updates_count), na.rm = TRUE), 
      mean(result$speed_kmh, na.rm = TRUE))
    )
    write.csv(result |> sf::st_drop_geometry() |> select(-any_of("closest_on_shape")), file.path(OUTPUT_FOLDER, sprintf("updates_with_speed_%s.csv", date)), row.names = FALSE)
  }

  warnings()
}