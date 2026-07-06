# GTFS RT aggregation for Carris Municipal
# Run with: $ Rscript 00_fetch_rt/3_gather/gtfs_rt_gather_CarrisMunicipal.R

library(jsonlite)
library(lubridate)
library(geosphere)
library(dplyr)
library(readr)
library(sf)

## Parameters
FOLDER_PATH <- "data/cm_20260413_220260430_business/updates"
OUTPUT_FOLDER <- "data/cm_20260413_220260430_business/processing_speed_shape_distance"

## Methods
process_json <- function(data, filename, RECORDS_LIST, agency_id = NULL) {
  day <- strsplit(filename, "_", fixed = TRUE)[[1]][1]

  for (e in data$entities) {
    vehicle <- e$vehicle
    if (is.null(vehicle$trip)) {
      message("Skipping vehicle with no trip information in file: ", filename)
      next
    }

    trip_id <- vehicle$trip$trip_id
    route_id <- vehicle$trip$route_id
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
      latitude = vehicle$position$latitude,
      longitude = vehicle$position$longitude,
      timestamp = vehicle$timestamp,
      current_stop_sequence = vehicle$current_stop_sequence
    ))
  }

  RECORDS_LIST
}

## main()
source("00_fetch_rt/3_gather/gtfs_rt_gather.R")
gtfs_rt_gather(FOLDER_PATH, OUTPUT_FOLDER, process_json)