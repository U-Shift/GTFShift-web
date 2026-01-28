#
# This is a Plumber API. You can run the API by clicking
# the 'Run API' button above.
#
# Find out more about building APIs with Plumber here:
#
#    https://www.rplumber.io/
#

library(plumber)


#* @apiTitle GTFShift
#* @apiDescription Web API for [GTFShift](https://u-shift.github.io/GTFShift/index.html), an R package for bus lane prioritization

#* Handle CORS preflight
#* @options /prioritize_lanes
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
  res$setHeader("Access-Control-Allow-Headers",
                req$HTTP_ACCESS_CONTROL_REQUEST_HEADERS)
  res$status <- 200
  res$body <- ""
  res
}

#* @options /geojson/<filename>
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
  res$setHeader("Access-Control-Allow-Headers",
                req$HTTP_ACCESS_CONTROL_REQUEST_HEADERS)
  res$status <- 200
  res$body <- ""
  res
}

#* Prioritize lanes based on GTFS feed and OSM query
#* @param req The request object containing JSON body with gtfs_url, osm_q, and optionally date
#* @param res The response object
#* @post /prioritize_lanes
#* @parser json
#* @serializer json
function(req, res) {

  tryCatch({
    request_start <- Sys.time()
    # Extract parameters from request body
    body <- req$body
    gtfs_url <- body[["gtfs_url"]]
    osm_q <- body[["osm_q"]]
    date <- body[["date"]]

    message(paste0("[", Sys.time(), "] Starting prioritize_lanes request"))
    message(paste0("[", Sys.time(), "] GTFS URL: ", gtfs_url))
    message(paste0("[", Sys.time(), "] OSM query features: ", length(osm_q)))
    if (is.null(date)) {
      date <- GTFShift::calendar_nextBusinessWednesday()
    }

    # Load GTFS feed
    message(paste0("[", Sys.time(), "] Loading GTFS feed..."))
    gtfs <- GTFShift::load_feed(gtfs_url)
    message(paste0("[", Sys.time(), "] GTFS feed loaded successfully"))

    gtfs_name <- NA
    if (!is.null(gtfs$feed_info) && !is.null(gtfs$feed_info$feed_publisher_name)) {
      gtfs_name <- gtfs$feed_info$feed_publisher_name[1]
    }

    # Create initial OSM query with bounding box from GTFS shapes
    message(paste0("[", Sys.time(), "] Creating OSM query with bounding box..."))
    bbox <- sf::st_bbox(tidytransit::shapes_as_sf(gtfs$shapes))
    osm_query <- osmdata::opq(bbox = bbox)

    # Add OSM features based on osm_q parameter
    message(paste0("[", Sys.time(), "] Adding OSM features..."))
    message(paste0("[", Sys.time(), "] OSM query structure: ", paste(names(osm_q), collapse=", ")))

    # Check if osm_q is a data frame-like structure
    if ("key" %in% names(osm_q) && "value" %in% names(osm_q)) {
      # Handle data frame-like structure
      keys <- osm_q[["key"]]
      values <- osm_q[["value"]]
      key_exacts <- osm_q[["key_exact"]]

      num_features <- length(keys)
      message(paste0("[", Sys.time(), "] Processing ", num_features, " features"))

      for (i in 1:num_features) {
        feature_key <- keys[[i]]
        feature_value <- values[[i]]
        feature_key_exact <- if (!is.null(key_exacts)) key_exacts[[i]] else NULL

        message(paste0("[", Sys.time(), "] Adding feature ", i, ": key=", feature_key,
                     ", values=", paste(feature_value, collapse=", "),
                     ", key_exact=", ifelse(is.null(feature_key_exact), "NULL", feature_key_exact)))

        # Check if key_exact should be used
        if (!is.null(feature_key_exact) && !is.na(feature_key_exact) && isTRUE(feature_key_exact)) {
          osm_query <- osmdata::add_osm_feature(
            osm_query,
            key = feature_key,
            value = feature_value,
            key_exact = TRUE
          )
        } else {
          osm_query <- osmdata::add_osm_feature(
            osm_query,
            key = feature_key,
            value = feature_value
          )
        }
      }
    }

    # Prioritize lanes
    message(paste0("[", Sys.time(), "] Running prioritize_lanes..."))
    logs <- list(message = character(), warning = character(), error   = NULL)

    lanes <- tryCatch(
      withCallingHandlers(
        GTFShift::prioritize_lanes(gtfs, osm_query, date = date),
        message = function(m) {
          logs$message <<- c(logs$message, conditionMessage(m))
          invokeRestart("muffleMessage")
        },
        warning = function(w) {
          logs$warning <<- c(logs$warning, conditionMessage(w))
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) {
        logs$error <<- conditionMessage(e)
        # Still raise error
        stop(e)
      }
    )
    message(paste0("[", Sys.time(), "] Prioritize_lanes completed successfully"))

    # Return as GeoJSON with metadata
    message(paste0("[", Sys.time(), "] Returning GeoJSON result"))

    tmp_geojson <- tempfile(fileext = ".geojson")
    sf::st_write(lanes, tmp_geojson, driver = "GeoJSON", quiet = TRUE)

    running_time_sec <- as.numeric(difftime(Sys.time(), request_start, units = "secs"))

    return(list(
      # Split tmp_geojson string by "/" and return last
      features = stringr::str_split(tmp_geojson, "/")[[1]][length(stringr::str_split(tmp_geojson, "/")[[1]])],
      region = list(
        name = gtfs_name,
        date = date
      ),
      running_time_sec = running_time_sec,
      logs = logs
    ))
  }, error = function(e) {
    # Log error
    message(paste0("[", Sys.time(), "] ERROR: ", e$message))
    message(paste0("[", Sys.time(), "] Stack trace: ", paste(capture.output(traceback()), collapse = " | ")))

    # Return error as JSON
    res$status <- 500
    res$serializer <- plumber::serializer_json()
    return(list(
      error = TRUE,
      message = e$message,
      trace = paste(capture.output(traceback()), collapse = "\n")
    ))
  })
}


#* Get GeoJSON file from temp directory
#* @param filename The GeoJSON filename
#* @param res The response object
#* @get /geojson/<filename>
#* @serializer geojson
function(filename, res) {
  # Validate that filename ends with .geojson
  if (!grepl("\\.geojson$", filename, ignore.case = TRUE)) {
    res$status <- 400
    res$serializer <- plumber::serializer_json()
    return(list(
      error = TRUE,
      message = "Only GeoJSON files are supported",
      filename = filename
    ))
  }

  # Construct full path
  file_path <- file.path(tempdir(), filename)

  # Check if file exists
  if (!file.exists(file_path)) {
    res$status <- 404
    res$serializer <- plumber::serializer_json()
    return(list(
      error = TRUE,
      message = "GeoJSON file not found",
      path = file_path
    ))
  }

  # Read and return GeoJSON
  tryCatch({
    sf_data <- sf::st_read(file_path, quiet = TRUE)
    return(sf_data)
  }, error = function(e) {
    res$status <- 500
    res$serializer <- plumber::serializer_json()
    return(list(
      error = TRUE,
      message = paste0("Error reading GeoJSON: ", e$message)
    ))
  })
}
