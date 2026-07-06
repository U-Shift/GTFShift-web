# GTFS RT commercial speed computation
# Run with: $ Rscript 00_fetch_rt/4_compute_speed/gtfs_rt_commercial_speed.R > data/cm_20260413_220260430_business/processing_speed_shape_distance/gtfs_rt_commercial_speed.log 2>&1

library(jsonlite)
library(lubridate)
library(geosphere)
library(dplyr)
library(readr)
library(sf)

## Parameters ---------------------------------------------------------------------
METRIC_CRS <- 3763 # Portugal

# > Carris, Lisboa, Portugal
UPDATES_RAW_FOLDER <- "data/cm_20260413_220260430_business/processing_speed_shape_distance"
OUTPUT_FOLDER <- "data/cm_20260413_220260430_business/processing_speed_shape_distance"
GTFS_FEED_URL = "https://github.com/U-Shift/busclar/releases/download/0.9/gtfs_carris.zip"
OSM_SHAPES = "https://github.com/U-Shift/busclar/releases/download/0.9/shapes_match_carris_gtfs20260527_run20260626.gpkg"

## main() ---------------------------------------------------------------------

### 1. Load GTFS 
message("Loading GTFS feed...")
gtfs = tidytransit::read_gtfs(GTFS_FEED_URL)

### 2. Load OSM shapes 
message("Loading OSM shapes...")
osm_shapes = st_read(OSM_SHAPES) 
nrow(osm_shapes)
# mapview(osm_shapes)

### 3. Convert OSM shapes to LINESTRING  
message("Converting OSM shapes to LINESTRING...")
osm_shapes_file = file.path(OUTPUT_FOLDER, "osm_shapes_linestring.gpkg")
if (file.exists(osm_shapes_file)) {
  message(sprintf("OSM shapes LINESTRING file already exists: %s", osm_shapes_file))
  osm_shapes_linestring = st_read(osm_shapes_file)
} else {
  message(sprintf("OSM shapes LINESTRING file does not exist, creating it: %s", osm_shapes_file))

  # > Get first stop of each shape from GTFS
  osm_shapes_first_stop = osm_shapes |> 
    st_drop_geometry() |> 
    select(osm_id, shape_id) |>
    left_join(gtfs$trips |> select(trip_id, shape_id), by = c("shape_id" = "shape_id"), multiple="first") |>
    left_join(
      gtfs$stop_times |> 
        select(trip_id, stop_id, stop_sequence) |>
        arrange(trip_id, stop_sequence) ,
      by = c("trip_id" = "trip_id"), multiple="first"
    ) |>
    left_join(
      gtfs$stops |> select(stop_id, stop_name, stop_lat, stop_lon),
      by = c("stop_id" = "stop_id"), multiple="first"
    ) |>
    st_as_sf(coords = c("stop_lon", "stop_lat"), crs = 4326, remove = FALSE) |>
    rename(first_stop_geometry = geometry)
  # mapview(osm_shapes_first_stop)
  assertthat::are_equal(nrow(osm_shapes_first_stop), nrow(osm_shapes))
  # > Join OSM shapes with first stop geometry
  osm_shapes_base_data = osm_shapes |> st_drop_geometry() |> select(osm_id, shape_id) |>
    left_join(
      osm_shapes_first_stop |> select(osm_id, first_stop_geometry),
      by = c("osm_id" = "osm_id")
    ) |> 
    left_join(
      osm_shapes |> select(osm_id, geom) |> rename(osm_geometry = geom),
      by = c("osm_id" = "osm_id")
    )
  # mapview((osm_shapes_base_data[1, ])$osm_geometry) + mapview((osm_shapes_base_data[1, ])$first_stop_geometry)
  # > Convert to LINESTRING
  start_time = Sys.time()
  osm_shapes_linestring = osm_shapes_base_data |>
    rowwise() |>
    mutate(
      osm_geometry = GTFShift::multiline_to_sorted_linestring(
        multilinestring = osm_geometry,
        start_point = first_stop_geometry,
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

### 4. Compute speed between updates
message("Starting computation of average speed between updates...")
csv_files <- list.files(UPDATES_RAW_FOLDER, pattern = "updates_raw.*\\.csv$", full.names = TRUE)
# Example: "data/cm_20260413_220260430_business/processing_speed_shape_distance/updates_raw_20260413.csv"
csv_files_dates <- sort(unique( substr(basename(csv_files), 13, 20) ))
for (date in csv_files_dates) {
  message(sprintf("> Processing date: %s", date))
  RECORDS <- read.csv(file.path(OUTPUT_FOLDER, sprintf("updates_raw_%s.csv", date)))

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

  result <- GTFShift::rt_commercial_speed(
    rt_collection = RECORDS_WITH_GTFS_AND_OSM_MATCH |> st_as_sf(coords = c("longitude", "latitude"), crs = 4326, remove = FALSE),
    trips_geometries = osm_shapes_linestring,
    rt_collection_trips_geometries_match_col = "osm_id",
    metric_crs = METRIC_CRS
  )
  
  message(sprintf("> Computed speed for %d records, with %.2f average updates per trip and an average speed of %.2f km/h", 
    nrow(result), 
    mean(result |> group_by(trip_id) |> summarise(updates_count = n(), .groups = "drop") |> pull(updates_count), na.rm = TRUE), 
    mean(result$speed_kmh, na.rm = TRUE))
  )
  write.csv(result |> sf::st_drop_geometry(), file.path(OUTPUT_FOLDER, sprintf("updates_with_speed_%s.csv", date)), row.names = FALSE)
}
