# GTFS RT aggregation
# Run with: $ Rscript 00_fetch_rt/3_gather/gtfs_rt_gather_CarrisMetropolitana.R

library(jsonlite)
library(lubridate)
library(geosphere)
library(dplyr)
library(readr)
library(sf)

## Parameters
METRIC_CRS <- 3763 # Portugal

FOLDER_PATH <- "data/cmet_20260413_220260430_business/updates"
OUTPUT_FOLDER <- "data/cmet_20260413_220260430_business_a3/processing_speed_shape_distance"
AGENCY_ID = "43" # None 

## Methods
process_json <- function(data, filename, RECORDS_LIST, agency_id = NULL) {
  day <- strsplit(filename, "_", fixed = TRUE)[[1]][1]

  for (e in data) {
    vehicle <- e
    if (is.null(vehicle$trip_id)) {
      # message("Skipping vehicle with no trip information in file: ", filename)
      next
    }
    if (!is.null(agency_id) && vehicle$agency_id != agency_id) {
      # message("Skipping vehicle with trip_id not matching agency_id in file: ", filename)
      next
    }

    trip_id <- vehicle$trip_id
    # Remove GTFS feed id from trip_id if present (e.g., "[43]trip_id" -> "trip_id")
    trip_id <- gsub("^\\[[^]]*\\]\\s*", "", trip_id)
    route_id <- vehicle$route_id
    trip_id_day <- paste0(trip_id, "_", day)
    

    # If previous has same timestamp, skip (to avoid duplicates)
    if (is.null(RECORDS_LIST[[trip_id_day]])) {
      RECORDS_LIST[[trip_id_day]] <- data.frame()
    }
    if (nrow(RECORDS_LIST[[trip_id_day]]) > 0 && RECORDS_LIST[[trip_id_day]] |>
        slice_tail(n = 1) |>
        pull(timestamp) == vehicle$timestamp) 
    {
      #message("Skipping duplicate timestamp for trip_id: ", trip_id, " on day: ", day)
      next
    }

    RECORDS_LIST[[trip_id_day]] <- bind_rows(RECORDS_LIST[[trip_id_day]], data.frame(
      trip_id = trip_id,
      route_id = route_id,
      day = day,
      latitude = vehicle$lat,
      longitude = vehicle$lon,
      timestamp = vehicle$timestamp,
      stop_id = vehicle$stop_id,
      speed_instant = vehicle$speed
    ))
  }

  RECORDS_LIST
}


## main()
source("00_fetch_rt/3_gather/gtfs_rt_gather.R")
gtfs_rt_gather(FOLDER_PATH, OUTPUT_FOLDER, process_json)