
# Run with: $ Rscript 00_fetch_rt/4_compute_speed/gtfs_rt_average_speed_CarrisMetropolitana.R > data/cmet_20260413_220260430_business_a4/processing_speed_shape_distance_2/gtfs_rt_average_speed.log 2>&1

manipulate_carris_met <- function(gtfs, filter_date=TRUE) {
  if (filter_date) {
    # Filter GTFS for 13/04/2026 to avoid duplicate trips and shapes because of multiple offer plans
    # Offer plan is the same for whole 04/2026, so no need to filter for other dates
    gtfs = tidytransit::filter_feed_by_date(gtfs, extract_date = "2026-04-13")
  }
  # Remove offer plan id from trip_id (e.g., "[43]trip_id" -> "trip_id")
  gtfs$trips$trip_id <- stringr::str_replace_all(gtfs$trips$trip_id, "\\[.*\\]", "")
  gtfs$stop_times$trip_id <- stringr::str_replace_all(gtfs$stop_times$trip_id, "\\[.*\\]", "")
  gtfs$trips$shape_id <- stringr::str_replace_all(gtfs$trips$shape_id, "\\[.*\\]", "")
  gtfs$shapes$shape_id <- stringr::str_replace_all(gtfs$shapes$shape_id, "\\[.*\\]", "")
  return(gtfs)
}

# > Carris Metropolitana, Area 1
UPDATES_RAW_FOLDER <- "data/cmet_20260413_220260430_business_a1/processing_speed_shape_distance_2"
OUTPUT_FOLDER <- "data/cmet_20260413_220260430_business_a1/processing_speed_shape_distance_2"
GTFS_FEED_URL = "https://files.mobilitydatabase.org/mdb-2027/mdb-2027-202604110055/mdb-2027-202604110055.zip" # MobilityDatabase Snapshot for 11/04/2026
GTFS_MANIPULATE = "manipulate_carris_met_area_1"
OSM_SHAPES = "https://github.com/U-Shift/busclar/releases/download/0.9/shapes_match_carris_metropolitana_gtfs20260527_run20260626.gpkg"
manipulate_carris_met_area_1 <- function(gtfs) {
  gtfs <- manipulate_carris_met(gtfs)
  gtfs <- GTFShift::filter_by_agency(gtfs, id = 41)
  return(gtfs)
}

# > Carris Metropolitana, Area 2
UPDATES_RAW_FOLDER <- "data/cmet_20260413_220260430_business_a2/processing_speed_shape_distance_2"
OUTPUT_FOLDER <- "data/cmet_20260413_220260430_business_a2/processing_speed_shape_distance_2"
GTFS_FEED_URL = "https://files.mobilitydatabase.org/mdb-2027/mdb-2027-202604110055/mdb-2027-202604110055.zip" # MobilityDatabase Snapshot for 11/04/2026
GTFS_MANIPULATE = "manipulate_carris_met_area_2"
OSM_SHAPES = "https://github.com/U-Shift/busclar/releases/download/0.9/shapes_match_carris_metropolitana_gtfs20260527_run20260626.gpkg"
manipulate_carris_met_area_2 <- function(gtfs) {
  gtfs <- manipulate_carris_met(gtfs)
  gtfs <- GTFShift::filter_by_agency(gtfs, id = 42)
  return(gtfs)
}

# > Carris Metropolitana, Area 3
UPDATES_RAW_FOLDER <- "data/cmet_20260413_220260430_business_a3/processing_speed_shape_distance_2"
OUTPUT_FOLDER <- "data/cmet_20260413_220260430_business_a3/processing_speed_shape_distance_2"
GTFS_FEED_URL = "https://files.mobilitydatabase.org/mdb-2027/mdb-2027-202604110055/mdb-2027-202604110055.zip" # MobilityDatabase Snapshot for 11/04/2026
GTFS_MANIPULATE = "manipulate_carris_met_area_3"
OSM_SHAPES = "https://github.com/U-Shift/busclar/releases/download/0.9/shapes_match_carris_metropolitana_gtfs20260527_run20260626.gpkg"
manipulate_carris_met_area_3 <- function(gtfs) {
  gtfs <- manipulate_carris_met(gtfs)
  gtfs <- GTFShift::filter_by_agency(gtfs, id = 43)
  return(gtfs)
}

# > Carris Metropolitana, Area 4
UPDATES_RAW_FOLDER <- "data/cmet_20260413_220260430_business_a4/processing_speed_shape_distance_2"
OUTPUT_FOLDER <- "data/cmet_20260413_220260430_business_a4/processing_speed_shape_distance_2"
GTFS_FEED_URL = "https://files.mobilitydatabase.org/mdb-2027/mdb-2027-202604110055/mdb-2027-202604110055.zip" # MobilityDatabase Snapshot for 11/04/2026
GTFS_MANIPULATE = "manipulate_carris_met_area_4"
OSM_SHAPES = "https://github.com/U-Shift/busclar/releases/download/0.9/shapes_match_carris_metropolitana_gtfs20260527_run20260626.gpkg"
manipulate_carris_met_area_4 <- function(gtfs) {
  gtfs <- manipulate_carris_met(gtfs, filter_date = FALSE) # Don't filter by date because area 4 has one service_id per day, so trips are not duplicated
  gtfs <- GTFShift::filter_by_agency(gtfs, id = 44)
  return(gtfs)
}

source("00_fetch_rt/4_compute_speed/gtfs_rt_average_speed.R")

gtfs_rt_average_speed(
  UPDATES_RAW_FOLDER = UPDATES_RAW_FOLDER,
  OUTPUT_FOLDER = OUTPUT_FOLDER,
  GTFS_FEED_URL = GTFS_FEED_URL,
  GTFS_MANIPULATE = GTFS_MANIPULATE,
  OSM_SHAPES = OSM_SHAPES
)