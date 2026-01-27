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


#* Prioritize lanes based on GTFS feed and OSM query
#* @param req The request object containing JSON body with gtfs_url and osm_q
#* @param res The response object
#* @post /prioritize_lanes
#* @parser json
#* @serializer geojson
function(req, res) {
  tryCatch({
    # Extract parameters from request body
    body <- req$body
    gtfs_url <- body[["gtfs_url"]]
    osm_q <- body[["osm_q"]]
    
    message(paste0("[", Sys.time(), "] Starting prioritize_lanes request"))
    message(paste0("[", Sys.time(), "] GTFS URL: ", gtfs_url))
    message(paste0("[", Sys.time(), "] OSM query features: ", length(osm_q)))
    
    # Load GTFS feed
    message(paste0("[", Sys.time(), "] Loading GTFS feed..."))
    gtfs <- GTFShift::load_feed(gtfs_url)
    message(paste0("[", Sys.time(), "] GTFS feed loaded successfully"))
    
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
    lanes <- GTFShift::prioritize_lanes(gtfs, osm_query)
    message(paste0("[", Sys.time(), "] Prioritize_lanes completed successfully"))
    
    # Return as GeoJSON
    message(paste0("[", Sys.time(), "] Returning GeoJSON result"))
    return(lanes)
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

