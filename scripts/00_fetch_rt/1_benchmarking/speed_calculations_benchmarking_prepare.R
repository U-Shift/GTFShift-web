library(dplyr)
library(sf)
library(mapview)

OPERATOR = "carris"
UPDATES_RAW = "data/cm_20260413_220260430_business/processing_20260508/updates.csv"
GTFS_FEED_URL = "https://github.com/U-Shift/busclar/releases/download/0.9/gtfs_carris.zip"
TRIP_ID_UPDATES = "20260416_41474_20260101_190_0_3"
TRIP_ID_GTFS = "41474_20260101_190_0_3"
# Carris Route 108_3
TRIP_ID_UPDATES = "20260428_5977_20260101_108_3_2"
TRIP_ID_GTFS = "5977_20260101_108_3_2"

UPDATES_RAW = "data/cm_20260413_220260430_business/processing_speed_shape_distance/updates_with_speed_20260415.csv"
TRIP_ID_UPDATES = "22224_20260101_251_0_21"
TRIP_ID_GTFS = "22224_20260101_251_0_21" # Circular geometry

UPDATES_RAW = "data/cm_20260413_220260430_business/processing_speed_shape_distance_osm_thresholds_circular_fix/updates_with_speed_20260413.csv"
TRIP_ID_UPDATES = "19141_20260101_226_0_6" # Circular geometry II
TRIP_ID_GTFS = "19141_20260101_226_0_6" 


OPERATOR = "cmet"
UPDATES_RAW = "data/cmet_20260413_220260430_business_a3/updates_instantSpeeds.csv"
GTFS_FEED_URL = "https://github.com/U-Shift/busclar/releases/download/0.9/gtfs_carris_metropolitana.zip"
TRIP_ID_UPDATES = "20260413_[KFULM]3526_1_1_0930_0959_0_ESC_DU"
TRIP_ID_GTFS = "3526_1_1_0930_0959_0_ESC_DU"

OPERATOR = "stcp"
UPDATES_RAW = "data/stcp_20260413_220260430_business/updates_prev_crs_fix.csv"
GTFS_FEED_URL = "https://opendata.porto.digital/dataset/5275c986-592c-43f5-8f87-aabbd4e4f3a4/resource/d4bc4f97-5a43-42a4-b30d-09dd9604f90c/download/gtfs_feed.zip"
TRIP_ID_UPDATES = "20260421_600_0_2|224|D1|T8|N7"
TRIP_ID_GTFS = "600_0_2\\|224\\|D1\\|T8\\|N7"

OPERATOR = "tcb"
UPDATES_RAW = "data/barreiro_20260511_20260515/calculations_before_crs_fix/updates_beforeCRSFix.csv"
GTFS_FEED_URL = "https://github.com/U-Shift/busclar/releases/download/0.9/gtfs_tcb.zip"
TRIP_ID_UPDATES = "20260513_DUPE_7-PTABB-TERM_0_DUPE_22_0925"
TRIP_ID_GTFS = "7-PTABB-TERM_0_DUPE_22_0925"
# Shape 7-PTABB-TERM, Route 7_7-PTABB-TERM


# Get shape for TRIP
gtfs = tidytransit::read_gtfs(GTFS_FEED_URL)
summary(gtfs)
# View(gtfs$trips)
trip_info = gtfs$trips |> 
  # Match trip_id that contains the TRIP_ID_GTFS string (to avoid issues with GTFS trip_id formatting)
  filter(grepl(TRIP_ID_GTFS, trip_id))
trip_info
trip_shape_id = trip_info$shape_id[[1]]
trip_shape_id
if (is.na(trip_shape_id)) {
  stop("No shape_id found for trip_id: ", TRIP_ID_GTFS)
}
gtfs_shapes_sf = tidytransit::shapes_as_sf(gtfs$shapes)
shape_case_study = gtfs_shapes_sf |> 
  filter(shape_id==trip_shape_id)


# Get updates for TRIP
updates = read.csv(UPDATES_RAW)
names(updates)
updates_case_study = updates |> 
  filter(trip_id==TRIP_ID_UPDATES)
updates_case_study_sf = updates_case_study |> 
  st_as_sf(coords=c("longitude","latitude"), crs=4326)
nrow(updates_case_study)
names(updates_case_study)
updates_case_study

mapview(shape_case_study, color="navyblue", lwd=3, layer.name="GTFS Shape", alpha=0.3) + 
    mapview(updates_case_study_sf, zcol="timestamp", layer.name="GTFS-RT updates") 
  
## Store sample 
write.csv(updates_case_study, paste0("data/samples/updates_case_study_", OPERATOR,"_", TRIP_ID_UPDATES, ".csv"), row.names=FALSE)

# Get updates for Route
updates = read.csv(UPDATES_RAW)
ROUTE_ID="4_4-CS-TERM"
updates_route = updates |> filter(route_id == ROUTE_ID) |>
  rename(
    latitude = lat,
    longitude = lon
  ) |> select(-timestamp_formatted) |>
  mutate(speed = round(speed, digits=2)) |>
  sample_n(100)
names(updates_route)

write.csv(updates_route, paste0("data/samples/updates_case_study_", OPERATOR,"_", ROUTE_ID, ".csv"), row.names=FALSE)
