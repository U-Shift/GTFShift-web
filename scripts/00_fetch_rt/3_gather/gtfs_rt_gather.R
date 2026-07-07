### 1. Aggregate JSONs (one per minute) by trip_id, with record of all updates per trip
gtfs_rt_gather <- function(FOLDER_PATH, OUTPUT_FOLDER, process_json) {
  print("\n1. Starting aggregation of GTSF-RT files...")
  if (!dir.exists(FOLDER_PATH)) {
    stop(sprintf("Folder '%s' does not exist.", FOLDER_PATH))
  }
  if (!dir.exists(OUTPUT_FOLDER)) {
    dir.create(OUTPUT_FOLDER, recursive = TRUE)
  }

  json_files <- list.files(FOLDER_PATH, pattern = "\\.json$", full.names = TRUE)
  json_files_dates <- sort(unique(substr(basename(json_files), 1, 8)))
  for (date in json_files_dates) {
    RECORDS_LIST <- list()
    message(sprintf("Processing date: %s", date))
    date_files <- json_files[substr(basename(json_files), 1, 8) == date]
    for (file_path in date_files) {
      filename <- basename(file_path)
      tryCatch({
        data <- jsonlite::fromJSON(file_path, simplifyVector = FALSE)
        RECORDS_LIST <- process_json(data, filename, RECORDS_LIST)
      }, error = function(e) {
        message(sprintf("Unexpected error processing file %s: %s", filename, e$message))
      })
    }
    
    RECORDS <- data.frame()
    # Combine all individual trip data frames into a single data frame
    RECORDS <- do.call(rbind, RECORDS_LIST)
    
    avg_updates <- RECORDS |> group_by(trip_id) |>
      summarise(updates_count = n(), .groups = "drop") |>
      summarise(avg_updates = mean(updates_count)) |>
      pull(avg_updates)
    message(sprintf("\nDONE! Processed %d updates, corresponding to %d individual trips, with an average number of %s updates per trip\n", nrow(RECORDS), length(unique(RECORDS$trip_id)), avg_updates))
    write.csv(RECORDS, file.path(OUTPUT_FOLDER, sprintf("updates_raw_%s.csv", date)), row.names = FALSE)

    # Remove variables and clear memory
    rm(RECORDS_LIST, RECORDS, avg_updates)
    gc()  # Call garbage collector to free up memory
  }
}