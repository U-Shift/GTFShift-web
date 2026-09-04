library(dplyr)

# Run with: $ Rscript 00_fetch_rt/4_compute_speed/gtfs_rt_average_speed_STCP.R > data/stcp_20260413_220260430_business/processing_speed_shape_distance_2/gtfs_rt_average_speed.log 2>&1

# > STCP, Porto, Portugal
UPDATES_RAW_FOLDER <- "data/stcp_20260413_220260430_business/processing_speed_shape_distance_2"
OUTPUT_FOLDER <- "data/stcp_20260413_220260430_business/processing_speed_shape_distance_2"
GTFS_FEED_URL <- "https://github.com/U-Shift/GTFShift/releases/download/v0.9/gtfs_stcp_2026-05-07.zip"
GTFS_MANIPULATE <- "manipulate_gtfs_stcp"
OSM_SHAPES <- "https://github.com/U-Shift/GTFShift/releases/download/v0.11/shapes_match_stcp_gtfs20260520_run20260710.gpkg"
UPDATES_MANIPULATE <- "manipulate_updates_stcp"
manipulate_gtfs_stcp <- function(gtfs) {
  # Rename trip_id to remove offer plan id from second number between || (e.g. 504_0_2|220|D3|T1|N26 > 504_0_2|D3|T1|N26)
  gtfs$trips$trip_id <- stringr::str_replace_all(gtfs$trips$trip_id, "\\|[0-9]+\\|", "|")
  gtfs$stop_times$trip_id <- stringr::str_replace_all(gtfs$stop_times$trip_id, "\\|[0-9]+\\|", "|")
  return(gtfs)
}
manipulate_updates_stcp <- function(osm_shapes) {
  # Rename trip_id to remove offer plan id from second number between || (e.g. 504_0_2|220|D3|T1|N26 > 504_0_2|D3|T1|N26)
  osm_shapes$trip_id <- stringr::str_replace_all(osm_shapes$trip_id, "\\|[0-9]+\\|", "|")
  return(osm_shapes)
}

source("00_fetch_rt/4_compute_speed/gtfs_rt_average_speed.R")

gtfs_rt_average_speed(
  UPDATES_RAW_FOLDER = UPDATES_RAW_FOLDER,
  OUTPUT_FOLDER = OUTPUT_FOLDER,
  GTFS_FEED_URL = GTFS_FEED_URL,
  GTFS_MANIPULATE = GTFS_MANIPULATE,
  OSM_SHAPES = OSM_SHAPES,
  UPDATES_MANIPULATE = UPDATES_MANIPULATE
)
