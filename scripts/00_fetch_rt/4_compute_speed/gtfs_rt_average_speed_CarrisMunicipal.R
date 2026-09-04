# > Carris, Lisboa, Portugal
UPDATES_RAW_FOLDER <- "data/cm_20260413_220260430_business/processing_speed_shape_distance"
OUTPUT_FOLDER <- "data/cm_20260413_220260430_business/osm_multiline_to_line_circular_fix_2"
GTFS_FEED_URL = "https://github.com/U-Shift/busclar/releases/download/0.9/gtfs_carris.zip"
GTFS_MANIPULATE = NULL
OSM_SHAPES = "https://github.com/U-Shift/busclar/releases/download/0.9/shapes_match_carris_gtfs20260527_run20260626.gpkg"

source("00_fetch_rt/4_compute_speed/gtfs_rt_average_speed.R")

gtfs_rt_average_speed(
  UPDATES_RAW_FOLDER = UPDATES_RAW_FOLDER,
  OUTPUT_FOLDER = OUTPUT_FOLDER,
  GTFS_FEED_URL = GTFS_FEED_URL,
  GTFS_MANIPULATE = GTFS_MANIPULATE,
  OSM_SHAPES = OSM_SHAPES
)