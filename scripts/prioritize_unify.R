# Aggregate prioritization results for multiple agencies

library(sf)
library(dplyr)
library(jsonlite)
library(purrr)

# Define input regions and output directory
# You can customize these variables as needed
regions <- c("lisboa_rt", "aml_rt")
gtfs_day <- "2026-02-04"

# Note: specify your run dates here
runs <- list(
  "lisboa_rt" = "20260310",
  "aml_rt" = "20260210"
)

input_base_dir <- "web_data"
output_dir <- sprintf("web_data/unified_rt/%s", gtfs_day)

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Helper to construct path
get_file_path <- function(region, gtfs_day, run_date, prefix, ext) {
  sprintf("%s/%s/%s/%s_%s_gtfs%s_run%s.%s", input_base_dir, region, gtfs_day, prefix, region, gtfs_day, run_date, ext)
}

# 1. Merge Ways (Geometries)
message("Merging ways (geometries)...")
ways_list <- list()
for (region in regions) {
  gpkg_path <- get_file_path(region, gtfs_day, runs[[region]], "ways", "gpkg")
  if (file.exists(gpkg_path)) {
    ways_list[[region]] <- st_read(gpkg_path, quiet = TRUE)
  } else {
    warning(sprintf("File missing: %s", gpkg_path))
  }
}

if (length(ways_list) > 0) {
  all_ways <- bind_rows(ways_list)
  # Drop duplicates by way_osm_id
  unified_ways <- all_ways |> distinct(way_osm_id, .keep_all = TRUE)
  
  st_write(unified_ways, sprintf("%s/ways_unified_rt_gtfs%s_run%s.gpkg", output_dir, gtfs_day, gsub("-", "", Sys.Date())), append=FALSE, delete_dsn=TRUE)
  st_write(unified_ways, sprintf("%s/ways_unified_rt_gtfs%s_run%s.geojson", output_dir, gtfs_day, gsub("-", "", Sys.Date())), append=FALSE, delete_dsn=TRUE)
}

# 2. Merge Way Data (JSON)
message("Merging way data...")
merged_ways_json <- list()
for (region in regions) {
  json_path <- get_file_path(region, gtfs_day, runs[[region]], "way_data", "json")
  if (file.exists(json_path)) {
    way_data <- read_json(json_path)
    
    for (way_id in names(way_data)) {
      way <- way_data[[way_id]]
      if (is.null(merged_ways_json[[way_id]])) {
        merged_ways_json[[way_id]] <- way
      } else {
        # Combine hourly frequencies
        for (hour in names(way$hour_frequency)) {
          if (is.null(merged_ways_json[[way_id]]$hour_frequency[[hour]])) {
            merged_ways_json[[way_id]]$hour_frequency[[hour]] <- way$hour_frequency[[hour]]
          } else {
            merged_ways_json[[way_id]]$hour_frequency[[hour]] <- merged_ways_json[[way_id]]$hour_frequency[[hour]] + way$hour_frequency[[hour]]
          }
        }
        # Combine arrays
        merged_ways_json[[way_id]]$routes <- unique(c(merged_ways_json[[way_id]]$routes, way$routes))
        merged_ways_json[[way_id]]$shapes <- unique(c(merged_ways_json[[way_id]]$shapes, way$shapes))
      }
    }
  }
}

json_string <- toJSON(
  merged_ways_json, 
  na = "null", 
  auto_unbox = TRUE, 
  pretty = TRUE
)
write(json_string, sprintf("%s/way_data_unified_rt_gtfs%s_run%s.json", output_dir, gtfs_day, gsub("-", "", Sys.Date())))

# 3. Merge Route Data (JSON)
message("Merging route data...")
merged_routes_json <- list()
for (region in regions) {
  json_path <- get_file_path(region, gtfs_day, runs[[region]], "route_data", "json")
  if (file.exists(json_path)) {
    route_data <- read_json(json_path)
    for (route_id in names(route_data)) {
      merged_routes_json[[route_id]] <- route_data[[route_id]]
    }
  }
}
write_json(
  merged_routes_json,
  sprintf("%s/route_data_unified_rt_gtfs%s_run%s.json", output_dir, gtfs_day, gsub("-", "", Sys.Date())),
  auto_unbox = TRUE,
  digits=NA 
)

# 4. Merge Shape Data (JSON)
message("Merging shape data...")
merged_shapes_json <- list()
for (region in regions) {
  json_path <- get_file_path(region, gtfs_day, runs[[region]], "shape_data", "json")
  if (file.exists(json_path)) {
    shape_data <- read_json(json_path)
    for (shape_id in names(shape_data)) {
      merged_shapes_json[[shape_id]] <- shape_data[[shape_id]]
    }
  }
}
write_json(
  merged_shapes_json,
  sprintf("%s/shape_data_unified_rt_gtfs%s_run%s.json", output_dir, gtfs_day, gsub("-", "", Sys.Date())),
  auto_unbox = TRUE,
  digits=NA 
)

# 5. Build Unified Metadata
message("Building unified metadata...")
metadata_list <- list()
for (region in regions) {
  json_path <- get_file_path(region, gtfs_day, runs[[region]], "metadata", "json")
  if (file.exists(json_path)) {
    metadata_list[[region]] <- read_json(json_path)
  }
}

if (length(metadata_list) > 0) {
  # Build a baseline from the first metadata doc
  unified_metadata <- list(
    region = "Unified Metro Area",
    gtfs = list(
      date = gtfs_day,
      url = paste(sapply(metadata_list, function(x) x$gtfs$url), collapse = "; ")
    ),
    osm_query = metadata_list[[1]]$osm_query,
    execution = list(
      moment = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      script = "prioritize_unify.R",
      git_commit = system("git rev-parse HEAD", intern=TRUE)
    ),
    environment = metadata_list[[1]]$environment,
    source_regions = regions
  )
  
  write_json(
    unified_metadata,
    sprintf("%s/metadata_unified_rt_gtfs%s_run%s.json", output_dir, gtfs_day, gsub("-", "", Sys.Date())),
    auto_unbox = TRUE,
    digits=NA
  )
}

message("Done!")
