# Aggregate prioritisation results for multiple agencies
## Run with: $ Rscript 02_prioritise/prioritise_unify.R

library(sf)
library(dplyr)
library(jsonlite)
library(purrr)
library(Hmisc)

# Define input regions and output directory
# You can customize these variables as needed
regions <- c("aml_rt_area_1", "aml_rt_area_2", "aml_rt_area_3", "aml_rt_area_4")
regions_name <- "Lisboa Metro Area, PT"
runs <- list(
  "aml_rt_area_1" = list(run = "20260806_100211", gtfs_day = "20260520"),
  "aml_rt_area_2" = list(run = "20260806_101548", gtfs_day = "20260520"),
  "aml_rt_area_3" = list(run = "20260806_102830", gtfs_day = "20260520"),
  "aml_rt_area_4" = list(run = "20260806_103907", gtfs_day = "20260520")
)
output_name <- sprintf(
  "aml_cm_all_gtfs%s_run%s",
  paste(unique(sapply(runs, function(x) x$gtfs_day)), collapse = "_"),
  paste(unique(sapply(runs, function(x) substr(x$run, 1, 8))), collapse = "_")
)
input_base_dir <- "web_data"

output_dir <- sprintf(
  "web_data/unified/%s_aggregation_at_%s",
  output_name,
  format(Sys.time(), "%Y%m%d_%H%M%S")
)

if (!dir.exists(output_dir)) {
  message(sprintf("Creating output directory: %s", output_dir))
  dir.create(output_dir, recursive = TRUE)
} else {
  message(sprintf("Output directory already exists: %s", output_dir))
}

# Helper to construct path for the new folder structure:
# Directory: web_data/[region]/gtfs_[gtfs_day_nodash]/run_[run_timestamp]
# File: [prefix]_[region]_gtfs[gtfs_day]_run[run_date_file].[ext]
get_file_path <- function(region, gtfs_day, run_timestamp, prefix, ext) {
  run_date_file <- substr(run_timestamp, 1, 8)
  dir_path <- sprintf("%s/%s/gtfs_%s/run_%s", input_base_dir, region, gsub("-", "", gtfs_day), run_timestamp)
  sprintf("%s/%s_%s_gtfs%s_run%s.%s", dir_path, prefix, region, gtfs_day, run_date_file, ext)
}

# 1. Merge Ways (Geometries)
message("Merging ways (geometries)...")
ways_list <- list()
for (region in regions) {
  message(sprintf("  Reading ways for region: %s...", region))
  geojson_path <- get_file_path(region, runs[[region]]$gtfs_day, runs[[region]]$run, "ways", "geojson")
  if (file.exists(geojson_path)) {
    ways_list[[region]] <- st_read(geojson_path, quiet = TRUE)
  } else {
    warning(sprintf("File missing: %s", geojson_path))
  }
}
if (length(ways_list) > 0) {
  all_ways <- bind_rows(ways_list)
  # Drop duplicates by way_osm_id
  unified_ways <- all_ways |> distinct(way_osm_id, .keep_all = TRUE)

  st_write(unified_ways, sprintf("%s/ways_%s.geojson", output_dir, output_name), append = FALSE, delete_dsn = TRUE)
}

# 3. Merge Way Data (JSON)
message("Merging way data...")
merged_ways_json <- list()
ways_df <- data.frame(way_osm_id = character(), length_m = numeric())
for (region in regions) {
  message(sprintf("  Reading way data JSON for region: %s...", region))
  json_path <- get_file_path(region, runs[[region]]$gtfs_day, runs[[region]]$run, "way_data", "json")
  if (file.exists(json_path)) {
    way_data <- read_json(json_path)

    for (way_id in names(way_data)) {
      way <- way_data[[way_id]]
      if (!(way_id %in% ways_df$way_osm_id)) {
        # No need to duplicate, as way data does not change with the regions
        ways_df <- rbind(ways_df, data.frame(
          way_osm_id = way_id,
          length_m = way$length_m
        ))
      }
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

        # Demand
        if (!is.null(way$demand)) {
          if (is.null(merged_ways_json[[way_id]]$demand)) {
            merged_ways_json[[way_id]]$demand <- way$demand
          } else {
            merged_ways_json[[way_id]]$demand <- merged_ways_json[[way_id]]$demand + way$demand
          }
        }

        # Compute speed_avg considering speed_count weight
        if (!is.null(way$speed_avg) && !is.null(way$speed_count)) {
          if (is.null(merged_ways_json[[way_id]]$speed_avg)) {
            merged_ways_json[[way_id]]$speed_avg <- way$speed_avg
            merged_ways_json[[way_id]]$speed_count <- way$speed_count
          } else {
            merged_ways_json[[way_id]]$speed_avg <- wtd.mean(c(merged_ways_json[[way_id]]$speed_avg, way$speed_avg), weights = c(merged_ways_json[[way_id]]$speed_count, way$speed_count), na.rm = TRUE)
            merged_ways_json[[way_id]]$speed_count <- merged_ways_json[[way_id]]$speed_count + way$speed_count
          }
        }
        # discard percentiles
        merged_ways_json[[way_id]]$speed_p25 <- NULL
        merged_ways_json[[way_id]]$speed_p75 <- NULL
        merged_ways_json[[way_id]]$speed_median <- NULL

        # Combine hourly speeds
        if (!is.null(way$hour_speed_count)) {
          if (is.null(merged_ways_json[[way_id]]$hour_speed_count)) {
            merged_ways_json[[way_id]]$hour_speed_avg <- way$hour_speed_avg
            merged_ways_json[[way_id]]$hour_speed_count <- way$hour_speed_count
          } else {
            for (hour in names(way$hour_speed_count)) {
              if (is.null(merged_ways_json[[way_id]]$hour_speed_count[[hour]])) {
                merged_ways_json[[way_id]]$hour_speed_avg[[hour]] <- way$hour_speed_avg[[hour]]
                merged_ways_json[[way_id]]$hour_speed_count[[hour]] <- way$hour_speed_count[[hour]]
              } else {
                merged_ways_json[[way_id]]$hour_speed_avg[[hour]] <- wtd.mean(
                  c(merged_ways_json[[way_id]]$hour_speed_avg[[hour]], way$hour_speed_avg[[hour]]),
                  weights = c(merged_ways_json[[way_id]]$hour_speed_count[[hour]], way$hour_speed_count[[hour]]),
                  na.rm = TRUE
                )
                merged_ways_json[[way_id]]$hour_speed_count[[hour]] <- merged_ways_json[[way_id]]$hour_speed_count[[hour]] + way$hour_speed_count[[hour]]
              }
            }
          }
        }
        merged_ways_json[[way_id]]$hour_speed_median <- NULL
        merged_ways_json[[way_id]]$hour_speed_p25 <- NULL
        merged_ways_json[[way_id]]$hour_speed_p75 <- NULL

        merged_ways_json[[way_id]]$merged <- TRUE
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
write(json_string, sprintf("%s/way_data_%s.json", output_dir, output_name))

# 4. Merge Route Data (JSON)
message("Merging route data...")
merged_routes_json <- list()
for (region in regions) {
  message(sprintf("  Reading route data JSON for region: %s...", region))
  json_path <- get_file_path(region, runs[[region]]$gtfs_day, runs[[region]]$run, "route_data", "json")
  if (file.exists(json_path)) {
    route_data <- read_json(json_path)
    for (route_id in names(route_data)) {
      merged_routes_json[[route_id]] <- route_data[[route_id]]
    }
  }
}
write_json(
  merged_routes_json,
  sprintf("%s/route_data_%s.json", output_dir, output_name),
  auto_unbox = TRUE,
  digits = NA
)

# 5. Merge Shape Data (JSON)
message("Merging shape data...")
merged_shapes_json <- list()
for (region in regions) {
  message(sprintf("  Reading shape data JSON for region: %s...", region))
  json_path <- get_file_path(region, runs[[region]]$gtfs_day, runs[[region]]$run, "shape_data", "json")
  if (file.exists(json_path)) {
    shape_data <- read_json(json_path)
    for (shape_id in names(shape_data)) {
      shape <- shape_data[[shape_id]]
      if (is.null(merged_shapes_json[[shape_id]])) {
        merged_shapes_json[[shape_id]] <- shape
      } else {
        stop("Not expecting same shape_id to be defined in multiple regions!")
      }
    }
  }
}
write_json(
  merged_shapes_json,
  sprintf("%s/shape_data_%s.json", output_dir, output_name),
  auto_unbox = TRUE,
  digits = NA
)

# 6. Build Unified Metadata
message("Building unified metadata...")
metadata_list <- list()
for (region in regions) {
  json_path <- get_file_path(region, runs[[region]]$gtfs_day, runs[[region]]$run, "metadata", "json")
  if (file.exists(json_path)) {
    metadata_list[[region]] <- read_json(json_path)
  }
}

message("Merging regional prioritisation datasets for data census...")
prioritisation <- data.frame()
for (region in regions) {
  message(sprintf("  Reading prioritisation GPKG for region: %s...", region))
  gpkg_path <- get_file_path(region, runs[[region]]$gtfs_day, runs[[region]]$run, "prioritisation", "gpkg")
  if (file.exists(gpkg_path)) {
    prioritisation <- bind_rows(prioritisation, st_read(gpkg_path, quiet = TRUE))
  }
}
message("  Grouping prioritisation data by way and hour...")
cols_to_add <- c(
  "speed_avg", "speed_count", "speed_p25", "speed_p75", "speed_median",
  "hour_speed_avg", "hour_speed_count", "hour_speed_p25", "hour_speed_p75", "hour_speed_median",
  "demand"
)
for (col in cols_to_add) {
  if (!col %in% colnames(prioritisation)) {
    prioritisation[[col]] <- if (nrow(prioritisation) == 0) numeric() else NA_real_
  }
}

if (nrow(prioritisation) == 0) {
  stop("No valid prioritisation datasets found for any of the regions! Make sure the GPKG files exist and the paths are correct.")
}

prioritisation <- prioritisation |>
  left_join(ways_df, by = "way_osm_id") |>
  group_by(way_osm_id, hour) |>
  summarise(
    frequency = sum(frequency, na.rm = TRUE),
    is_bus_lane = any(is_bus_lane),
    n_lanes_parking = first(n_lanes_parking),
    n_lanes_circulation = first(n_lanes_circulation),
    n_directions = first(n_directions),
    n_lanes_circulation_direction = first(n_lanes_circulation_direction),
    routes = paste(unique(unlist(lapply(routes, function(x) x))), collapse = "; "),
    shapes = paste(unique(unlist(lapply(shapes, function(x) x))), collapse = "; "),
    name = first(name),
    speed_avg = wtd.mean(speed_avg, weights = speed_count, na.rm = TRUE),
    speed_p25 = wtd.mean(speed_p25, weights = speed_count, na.rm = TRUE),
    speed_p75 = wtd.mean(speed_p75, weights = speed_count, na.rm = TRUE),
    speed_median = wtd.mean(speed_median, weights = speed_count, na.rm = TRUE),
    speed_count = sum(speed_count, na.rm = TRUE),
    hour_speed_avg = wtd.mean(hour_speed_avg, weights = hour_speed_count, na.rm = TRUE),
    hour_speed_p25 = wtd.mean(hour_speed_p25, weights = hour_speed_count, na.rm = TRUE),
    hour_speed_p75 = wtd.mean(hour_speed_p75, weights = hour_speed_count, na.rm = TRUE),
    hour_speed_median = wtd.mean(hour_speed_median, weights = hour_speed_count, na.rm = TRUE),
    hour_speed_count = sum(hour_speed_count, na.rm = TRUE),
    demand = sum(demand, na.rm = TRUE),
    length_m = first(length_m),
    geom = first(geom)
  ) |>
  ungroup() |>
  st_as_sf()

# nrow(prioritisation)
prioritisation_infrastructure <- prioritisation |>
  distinct(way_osm_id, .keep_all = TRUE)

# nrow(prioritisation_infrastructure)

# 2. Merge Prioritisation Area Polygons
message("Merging prioritisation area polygons...")
prioritisation_area_polygon <- prioritisation |>
  st_union() |>
  st_convex_hull()

st_write(
  prioritisation_area_polygon,
  sprintf("%s/prioritisation_area_polygon_%s.geojson", output_dir, output_name),
  append = FALSE,
  delete_dsn = TRUE
)
# mapview::mapview(unified_polygon)

message("Merging metadata...")
if (length(metadata_list) > 0) {
  unified_metadata <- list(
    region = regions_name,
    gtfs = list(
      date = paste(unique(unlist(lapply(metadata_list, function(x) x$gtfs$date))), collapse = "; "),
      url = paste(unique(sapply(metadata_list, function(x) x$gtfs$url), collapse = "; "))
    ),
    osm_query = unique(unlist(unname(lapply(metadata_list, function(x) x$osm_query)), recursive = FALSE)),
    execution = list(
      moment = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      script = "prioritise_unify.R",
      git_commit = system("git rev-parse HEAD", intern = TRUE)
    ),
    environment = list(
      r = paste(unique(unlist(lapply(metadata_list, function(x) x$environment$r))), collapse = "; "),
      GTFShift = paste(unique(unlist(lapply(metadata_list, function(x) x$environment$GTFShift))), collapse = "; "),
      os = paste(unique(unlist(lapply(metadata_list, function(x) x$environment$os))), collapse = "; "),
      os_release = paste(unique(unlist(lapply(metadata_list, function(x) x$environment$os_release))), collapse = "; ")
    ),
    source_regions = regions
  )

  # Unify data census
  dataCensus <- function(numberArray, weights) {
    quantiles <- wtd.quantile(numberArray, weights = weights, probs = c(0.05, 0.15, 0.25, 0.5, 0.75, 0.85, 0.95))
    return(list(
      min = round(min(numberArray, na.rm = TRUE), digits = 2),
      max = round(max(numberArray, na.rm = TRUE), digits = 2),
      p5 = round(as.numeric(quantiles[1]), digits = 2),
      p15 = round(as.numeric(quantiles[2]), digits = 2),
      p25 = round(as.numeric(quantiles[3]), digits = 2),
      p75 = round(as.numeric(quantiles[5]), digits = 2),
      p85 = round(as.numeric(quantiles[6]), digits = 2),
      p95 = round(as.numeric(quantiles[7]), digits = 2),
      mean = round(wtd.mean(numberArray, weights = weights, na.rm = TRUE), digits = 2),
      median = round(as.numeric(quantiles[4]), digits = 2),
      median_below_p95 = round(wtd.quantile(numberArray[numberArray <= quantiles[7]], weights = weights[numberArray <= quantiles[7]], probs = 0.5, na.rm = TRUE), digits = 2),
      median_below_p85 = round(wtd.quantile(numberArray[numberArray <= quantiles[6]], weights = weights[numberArray <= quantiles[6]], probs = 0.5, na.rm = TRUE), digits = 2),
      median_below_p75 = round(wtd.quantile(numberArray[numberArray <= quantiles[5]], weights = weights[numberArray <= quantiles[5]], probs = 0.5, na.rm = TRUE), digits = 2),
      variance = round(wtd.var(numberArray, weights = weights, na.rm = TRUE), digits = 2),
      sd = round(sqrt(wtd.var(numberArray, weights = weights, na.rm = TRUE)), digits = 2),
      count = length(numberArray)
    ))
  }
  census_frequency_hour <- list()
  for (h in 0:23) {
    prioritisation_h <- prioritisation |> filter(hour == h)
    census <- dataCensus(prioritisation_h$frequency, prioritisation_h$length_m)
    if (!is.na(census$mean)) {
      census_frequency_hour[[as.character(h)]] <- census
    }
  }
  unified_metadata$data_census <- list(
    frequency = dataCensus(prioritisation$frequency, prioritisation$length_m),
    frequency_hour = census_frequency_hour,
    speed_avg_length = NA,
    speed_avg_frequency = NA,
    demand_frequency = NA,
    demand_length = NA,
    lanes_length = dataCensus(prioritisation_infrastructure$n_lanes_circulation_direction, prioritisation_infrastructure$length_m),
    lanes_frequency = dataCensus(prioritisation_infrastructure$n_lanes_circulation_direction, prioritisation_infrastructure$frequency),
    prioritisation_stats_length = lapply(
      GTFShift::get_prioritisation_stats(prioritisation_infrastructure, weight = "length"),
      function(x) {
        if (is.numeric(x)) {
          round(x, 2)
        } else {
          x
        }
      }
    ),
    prioritisation_stats_frequency = lapply(
      GTFShift::get_prioritisation_stats(prioritisation_infrastructure, weight = "frequency"),
      function(x) {
        if (is.numeric(x)) {
          round(x, 2)
        } else {
          x
        }
      }
    )
  )

  if ("speed_avg" %in% colnames(prioritisation_infrastructure) && !all(is.na(prioritisation_infrastructure$speed_avg))) {
    unified_metadata$data_census$speed_avg_length <- dataCensus(prioritisation_infrastructure$speed_avg, prioritisation_infrastructure$length_m)
    unified_metadata$data_census$speed_avg_frequency <- dataCensus(prioritisation_infrastructure$speed_avg, prioritisation_infrastructure$frequency)
  }
  if ("demand" %in% colnames(prioritisation_infrastructure) && !all(is.na(prioritisation_infrastructure$demand))) {
    unified_metadata$data_census$demand_frequency <- dataCensus(prioritisation_infrastructure$demand, prioritisation_infrastructure$frequency)
    unified_metadata$data_census$demand_length <- dataCensus(prioritisation_infrastructure$demand, prioritisation_infrastructure$length_m)
  }


  if (!is.null(metadata_list[[1]]$prioritisation)) {
    unified_metadata$prioritisation <- list(
      shapes_missing = unique(unlist(lapply(metadata_list, function(x) x$prioritisation$shapes_missing))),
      routes_missing = do.call(c, lapply(metadata_list, function(x) x$prioritisation$routes_missing)),
      shapes_total = sum(sapply(metadata_list, function(x) x$prioritisation$shapes_total)),
      shapes_found_n = sum(sapply(metadata_list, function(x) x$prioritisation$shapes_found_n)),
      shapes_missing_n = sum(sapply(metadata_list, function(x) x$prioritisation$shapes_missing_n)),
      shapes_total_frequency = sum(sapply(metadata_list, function(x) x$prioritisation$shapes_total_frequency)),
      shapes_found_frequency = sum(sapply(metadata_list, function(x) x$prioritisation$shapes_found_frequency)),
      shapes_missing_frequency = sum(sapply(metadata_list, function(x) x$prioritisation$shapes_missing_frequency)),
      routes_total = sum(sapply(metadata_list, function(x) x$prioritisation$routes_total)),
      routes_missing_n = sum(sapply(metadata_list, function(x) x$prioritisation$routes_missing_n)),
      routes_found_n = sum(sapply(metadata_list, function(x) x$prioritisation$routes_found_n))
    )
  }

  if (!is.null(metadata_list[[1]]$prioritisation_hour)) {
    prioritisation_hour <- lapply(0:23, function(i) {
      hour_str <- as.character(i)
      hour_data <- lapply(metadata_list, function(x) x$prioritisation_hour[[hour_str]])
      hour_data <- hour_data[!sapply(hour_data, is.null)]
      if (length(hour_data) == 0) {
        return(NULL)
      }
      list(
        shapes_missing = unique(unlist(lapply(hour_data, function(x) x$shapes_missing))),
        routes_missing = do.call(c, lapply(hour_data, function(x) x$routes_missing)),
        shapes_total = sum(sapply(hour_data, function(x) x$shapes_total)),
        shapes_found_n = sum(sapply(hour_data, function(x) x$shapes_found_n)),
        shapes_missing_n = sum(sapply(hour_data, function(x) x$shapes_missing_n)),
        shapes_total_frequency = sum(sapply(hour_data, function(x) x$shapes_total_frequency)),
        shapes_found_frequency = sum(sapply(hour_data, function(x) x$shapes_found_frequency)),
        shapes_missing_frequency = sum(sapply(hour_data, function(x) x$shapes_missing_frequency)),
        routes_total = sum(sapply(hour_data, function(x) x$routes_total)),
        routes_missing_n = sum(sapply(hour_data, function(x) x$routes_missing_n)),
        routes_found_n = sum(sapply(hour_data, function(x) x$routes_found_n))
      )
    }) |> setNames(as.character(0:23))
    unified_metadata$prioritisation_hour <- prioritisation_hour[!sapply(prioritisation_hour, is.null)]
  }

  if (!is.null(metadata_list[[1]]$rt) && !is.na(metadata_list[[1]]$rt)[1]) {
    unified_metadata$rt <- list(
      url = paste(setdiff(unlist(lapply(metadata_list, function(x) if (!is.null(x$rt) && !is.logical(x$rt)) x$rt$url else NULL)), c("", "NULL", NA)), collapse = "; "),
      period = paste(setdiff(unlist(lapply(metadata_list, function(x) if (!is.null(x$rt) && !is.logical(x$rt)) x$rt$period else NULL)), c("", "NULL", NA)), collapse = "; "),
      notes = paste(setdiff(unlist(lapply(metadata_list, function(x) if (!is.null(x$rt) && !is.logical(x$rt)) x$rt$notes else NULL)), c("", "NULL", NA)), collapse = "; "),
      thresholds = list(
        min_updates_per_road_segment_for_speed = max(sapply(metadata_list, function(x) if (!is.null(x$rt) && !is.logical(x$rt)) x$rt$thresholds$min_updates_per_road_segment_for_speed else 0), na.rm = TRUE),
        max_time_between_updates = max(sapply(metadata_list, function(x) if (!is.null(x$rt) && !is.logical(x$rt)) x$rt$thresholds$max_time_between_updates else 0), na.rm = TRUE),
        min_updates_per_trip_margin = max(sapply(metadata_list, function(x) if (!is.null(x$rt) && !is.logical(x$rt)) x$rt$thresholds$min_updates_per_trip_margin else 0), na.rm = TRUE),
        max_distance_to_geometry = max(sapply(metadata_list, function(x) if (!is.null(x$rt) && !is.logical(x$rt)) x$rt$thresholds$max_distance_to_geometry else 0), na.rm = TRUE),
        edge_distance_discard = max(sapply(metadata_list, function(x) if (!is.null(x$rt) && !is.logical(x$rt)) x$rt$thresholds$edge_distance_discard else 0), na.rm = TRUE),
        max_speed = max(sapply(metadata_list, function(x) if (!is.null(x$rt) && !is.logical(x$rt)) x$rt$thresholds$max_speed else 0), na.rm = TRUE)
      )
    )
  } else {
    unified_metadata$rt <- NA
  }

  if (!is.null(metadata_list[[1]]$demand) && !is.na(metadata_list[[1]]$demand)[1]) {
    unified_metadata$demand <- list(
      notes = paste(setdiff(unlist(lapply(metadata_list, function(x) if (!is.null(x$demand) && !is.logical(x$demand)) x$demand$notes else NULL)), c("", "NULL", NA)), collapse = "; ")
    )
  } else {
    unified_metadata$demand <- NA
  }

  write_json(
    unified_metadata,
    sprintf("%s/metadata_%s.json", output_dir, output_name),
    auto_unbox = TRUE,
    digits = NA
  )
}

message("Done!")
