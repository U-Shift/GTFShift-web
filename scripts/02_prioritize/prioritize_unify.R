# Aggregate prioritization results for multiple agencies
## Run with: $ Rscript 02_prioritize/prioritize_unify.R

library(sf)
library(dplyr)
library(jsonlite)
library(purrr)
library(Hmisc)

# Define input regions and output directory
# You can customize these variables as needed
regions <- c("aml_rt_area_1", "aml_rt_area_2", "aml_rt_area_3", "aml_rt_area_4", "lisboa_rt", "cascais", "barreiro")
regions_name <- "Lisboa Metro Area, Portugal"
runs <- list(
  "aml_rt_area_1" = list(run = "20260518_190844", gtfs_day = "2026-05-20"),
  "aml_rt_area_2" = list(run = "20260518_194948", gtfs_day = "2026-05-20"),
  "aml_rt_area_3" = list(run = "20260518_203125", gtfs_day = "2026-05-20"),
  "aml_rt_area_4" = list(run = "20260518_205250", gtfs_day = "2026-05-20"),
  "lisboa_rt" = list(run = "20260518_185258", gtfs_day = "2026-05-20"),
  "cascais" = list(run = "20260519_071746", gtfs_day = "2026-05-20"),
  "barreiro" = list(run = "20260519_110700", gtfs_day = "2026-05-20")
)
output_name <- sprintf(
  "aml_all_gtfs%s_run%s",
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
        # message(sprintf("Combining data for way %s...", way_id))
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
        # Compute speed_avg considering speed_count weight
        merged_ways_json[[way_id]]$speed_avg <- wtd.mean(c(merged_ways_json[[way_id]]$speed_avg, way$speed_avg), weights = c(merged_ways_json[[way_id]]$speed_count, way$speed_count), na.rm = TRUE)
        merged_ways_json[[way_id]]$speed_count <- merged_ways_json[[way_id]]$speed_count + way$speed_count
        # speed_median, speed_p25, speed_p75 -> discarded because it would require the original distributions
        merged_ways_json[[way_id]]$speed_p25 <- NULL
        merged_ways_json[[way_id]]$speed_p75 <- NULL
        merged_ways_json[[way_id]]$speed_median <- NULL

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

message("Merging regional prioritization datasets for data census...")
prioritization <- data.frame()
for (region in regions) {
  message(sprintf("  Reading prioritization GPKG for region: %s...", region))
  gpkg_path <- get_file_path(region, runs[[region]]$gtfs_day, runs[[region]]$run, "prioritization", "gpkg")
  if (file.exists(gpkg_path)) {
    prioritization <- bind_rows(prioritization, st_read(gpkg_path, quiet = TRUE))
  }
}
message("  Grouping prioritization data by way and hour...")
prioritization <- prioritization |>
  left_join(ways_df, by = "way_osm_id") |>
  group_by(way_osm_id, hour) |>
  summarise(
    frequency = sum(frequency, na.rm = TRUE),
    is_bus_lane = any(is_bus_lane),
    n_lanes_parking = first(n_lanes_parking),
    n_lanes_circulation = first(n_lanes_circulation),
    n_lanes = first(n_lanes),
    n_directions = first(n_directions),
    n_lanes_circulation_direction = first(n_lanes_circulation_direction),
    n_lanes_direction = first(n_lanes_direction),
    routes = paste(unique(unlist(lapply(routes, function(x) x))), collapse = "; "),
    shapes = paste(unique(unlist(lapply(shapes, function(x) x))), collapse = "; "),
    name = first(name),
    speed_avg = wtd.mean(speed_avg, weights = speed_count, na.rm = TRUE),
    speed_p25 = wtd.mean(speed_p25, weights = speed_count, na.rm = TRUE),
    speed_p75 = wtd.mean(speed_p75, weights = speed_count, na.rm = TRUE),
    speed_median = wtd.mean(speed_median, weights = speed_count, na.rm = TRUE),
    speed_count = sum(speed_count, na.rm = TRUE),
    length_m = first(length_m),
    geom = first(geom)
  ) |>
  ungroup() |>
  st_as_sf()

# nrow(prioritization)
prioritization_infrastructure <- prioritization |>
  distinct(way_osm_id, .keep_all = TRUE)

# nrow(prioritization_infrastructure)

# 2. Merge Prioritization Area Polygons
message("Merging prioritization area polygons...")
prioritization_area_polygon <- prioritization |>
  st_union() |>
  st_convex_hull()

st_write(
  prioritization_area_polygon,
  sprintf("%s/prioritization_area_polygon_%s.geojson", output_dir, output_name),
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
      script = "prioritize_unify.R",
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
    quantiles <- wtd.quantile(numberArray, weights = weights, probs = c(0.05, 0.25, 0.5, 0.75, 0.95))
    return(list(
      min = round(min(numberArray, na.rm = TRUE), digits = 2),
      max = round(max(numberArray, na.rm = TRUE), digits = 2),
      p5 = round(as.numeric(quantiles[1]), digits = 2),
      p25 = round(as.numeric(quantiles[2]), digits = 2),
      p75 = round(as.numeric(quantiles[4]), digits = 2),
      p95 = round(as.numeric(quantiles[5]), digits = 2),
      mean = round(wtd.mean(numberArray, weights = weights, na.rm = TRUE), digits = 2),
      median = round(as.numeric(quantiles[3]), digits = 2),
      variance = round(wtd.var(numberArray, weights = weights, na.rm = TRUE), digits = 2),
      sd = round(sqrt(wtd.var(numberArray, weights = weights, na.rm = TRUE)), digits = 2),
      count = length(numberArray)
    ))
  }
  census_frequency_hour <- list()
  for (h in 0:23) {
    prioritization_h <- prioritization |> filter(hour == h)
    census <- dataCensus(prioritization_h$frequency, prioritization_h$length_m)
    if (!is.na(census$mean)) {
      census_frequency_hour[[as.character(h)]] <- census
    }
  }
  unified_metadata$data_census <- list(
    frequency = dataCensus(prioritization$frequency, prioritization$length_m),
    frequency_hour = census_frequency_hour,
    speed_avg_length = NA,
    speed_avg_frequency = NA,
    lanes_length = dataCensus(prioritization_infrastructure$n_lanes_direction, prioritization_infrastructure$length_m),
    lanes_frequency = dataCensus(prioritization_infrastructure$n_lanes_direction, prioritization_infrastructure$frequency),
    prioritization_stats_length = lapply(
      GTFShift::get_prioritization_stats(prioritization_infrastructure, weight = "length"),
      function(x) {
        if (is.numeric(x)) {
          round(x, 2)
        } else {
          x
        }
      }
    ),
    prioritization_stats_frequency = lapply(
      GTFShift::get_prioritization_stats(prioritization_infrastructure, weight = "frequency"),
      function(x) {
        if (is.numeric(x)) {
          round(x, 2)
        } else {
          x
        }
      }
    )
  )

  if ("speed_avg" %in% colnames(prioritization_infrastructure)) {
    unified_metadata$data_census$speed_avg_length <- dataCensus(prioritization_infrastructure$speed_avg, prioritization_infrastructure$length_m)
    unified_metadata$data_census$speed_avg_frequency <- dataCensus(prioritization_infrastructure$speed_avg, prioritization_infrastructure$frequency)
  }


  if (!is.null(metadata_list[[1]]$prioritization)) {
    unified_metadata$prioritization <- list(
      shapes_missing = unique(unlist(lapply(metadata_list, function(x) x$prioritization$shapes_missing))),
      routes_missing = do.call(c, lapply(metadata_list, function(x) x$prioritization$routes_missing)),
      shapes_total = sum(sapply(metadata_list, function(x) x$prioritization$shapes_total)),
      shapes_found_n = sum(sapply(metadata_list, function(x) x$prioritization$shapes_found_n)),
      shapes_missing_n = sum(sapply(metadata_list, function(x) x$prioritization$shapes_missing_n)),
      shapes_total_frequency = sum(sapply(metadata_list, function(x) x$prioritization$shapes_total_frequency)),
      shapes_found_frequency = sum(sapply(metadata_list, function(x) x$prioritization$shapes_found_frequency)),
      shapes_missing_frequency = sum(sapply(metadata_list, function(x) x$prioritization$shapes_missing_frequency)),
      routes_total = sum(sapply(metadata_list, function(x) x$prioritization$routes_total)),
      routes_missing_n = sum(sapply(metadata_list, function(x) x$prioritization$routes_missing_n)),
      routes_found_n = sum(sapply(metadata_list, function(x) x$prioritization$routes_found_n))
    )
  }

  if (!is.null(metadata_list[[1]]$prioritization_hour)) {
    prioritization_hour <- lapply(0:23, function(i) {
      hour_str <- as.character(i)
      hour_data <- lapply(metadata_list, function(x) x$prioritization_hour[[hour_str]])
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
    unified_metadata$prioritization_hour <- prioritization_hour[!sapply(prioritization_hour, is.null)]
  }

  if (!is.null(metadata_list[[1]]$rt) && !is.na(metadata_list[[1]]$rt)[1]) {
    unified_metadata$rt <- list(
      url = paste(unique(sapply(metadata_list, function(x) if (!is.null(x$rt) && !is.logical(x$rt)) x$rt$url else "")), collapse = "; "),
      period = paste(unique(sapply(metadata_list, function(x) if (!is.null(x$rt) && !is.logical(x$rt)) x$rt$period else "")), collapse = "; "),
      stop_buffer_size = max(sapply(metadata_list, function(x) if (!is.null(x$rt) && !is.logical(x$rt)) x$rt$stop_buffer_size else 0), na.rm = TRUE)
    )
  } else {
    unified_metadata$rt <- NA
  }

  write_json(
    unified_metadata,
    sprintf("%s/metadata_%s.json", output_dir, output_name),
    auto_unbox = TRUE,
    digits = NA
  )
}

message("Done!")
