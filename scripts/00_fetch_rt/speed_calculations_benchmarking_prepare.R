library(dplyr)
library(sf)
library(mapview)

OPERATOR = "carris"
UPDATES_RAW = "data/cm_20260413_220260430_business/processing_20260508/updates.csv"
GTFS_FEED_URL = "https://github.com/U-Shift/busclar/releases/download/0.9/gtfs_carris.zip"
TRIP_ID_UPDATES = "20260416_41474_20260101_190_0_3"
TRIP_ID_GTFS = "41474_20260101_190_0_3"

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
  st_as_sf(coords=c("lon","lat"), crs=4326)
nrow(updates_case_study)
names(updates_case_study)
updates_case_study

mapview(shape_case_study, color="navyblue", lwd=3, layer.name="GTFS Shape", alpha=0.3) + 
    mapview(updates_case_study_sf, zcol="timestamp", layer.name="GTFS-RT updates") 
  
## Store sample 
write.csv(updates_case_study, paste0("data/samples/updates_case_study_", OPERATOR,"_", TRIP_ID_UPDATES, ".csv"), row.names=FALSE)
