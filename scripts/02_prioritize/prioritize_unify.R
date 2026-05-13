# Aggregate prioritization results for multiple agencies

library(sf)
library(dplyr)
library(jsonlite)
library(purrr)
library(Hmisc)

# Define input regions and output directory
# You can customize these variables as needed
regions <- c("aml_rt_area_1", "aml_rt_area_2")
output_name <- sprintf("aml_areas_1_2_run%s", format(Sys.time(), "%Y%m%d_%H%M%S"))

# Note: specify your run configurations per region here
runs <- list(
  "aml_rt_area_1" = list(run = "20260512_150158", gtfs_day = "2026-05-13"),
  "aml_rt_area_2" = list(run = "20260512_150630", gtfs_day = "2026-05-13")
)

input_base_dir <- "web_data"
output_dir <- sprintf("web_data/unified/%s", output_name)

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

# Helper to construct path for the new folder structure:
# Directory: web_data/[region]/gtfs_[gtfs_day_nodash]/run_[run_timestamp]
# File: [prefix]_[region]_gtfs[gtfs_day]_run[run_date_file].[ext]
get_file_path <- function(region, gtfs_day, run_timestamp, prefix, ext) {
  run_date_file <- substr(run_timestamp, 1, 8)
  dir_path <- sprintf("%s/%s/gtfs_%s/run_%s", input_base_dir, region, gsub("-", "", gtfs_day), run_timestamp)
  sprintf("%s/%s_%s_gtfs%s_run%s.%s", dir_path, prefix, region, gtfs_day, run_date_file, ext)
}

dataCensus <- function(numberArray, weights) {
  if (length(numberArray) == 0) {
    return(list(mean = NA))
  }
  quantiles <- Hmisc::wtd.quantile(numberArray, weights = weights, probs = c(0.05, 0.25, 0.5, 0.75, 0.95))
  return(list(
    min = round(min(numberArray, na.rm = TRUE), digits = 2),
    max = round(max(numberArray, na.rm = TRUE), digits = 2),
    p5 = round(as.numeric(quantiles[1]), digits = 2),
    p25 = round(as.numeric(quantiles[2]), digits = 2),
    p75 = round(as.numeric(quantiles[4]), digits = 2),
    p95 = round(as.numeric(quantiles[5]), digits = 2),
    mean = round(Hmisc::wtd.mean(numberArray, weights = weights, na.rm = TRUE), digits = 2),
    median = round(as.numeric(quantiles[3]), digits = 2),
    variance = round(Hmisc::wtd.var(numberArray, weights = weights, na.rm = TRUE), digits = 2),
    sd = round(sqrt(Hmisc::wtd.var(numberArray, weights = weights, na.rm = TRUE)), digits = 2)
  ))
}

# 1. Merge Ways (Geometries)
message("Merging ways (geometries)...")
ways_list <- list()
for (region in regions) {
  gpkg_path <- get_file_path(region, runs[[region]]$gtfs_day, runs[[region]]$run, "ways", "gpkg")
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

  st_write(unified_ways, sprintf("%s/ways_unified_%s.gpkg", output_dir, output_name), append = FALSE, delete_dsn = TRUE)
  st_write(unified_ways, sprintf("%s/ways_unified_%s.geojson", output_dir, output_name), append = FALSE, delete_dsn = TRUE)
}

# 2. Merge Prioritization (CSV & GPKG)
message("Merging prioritization data...")
prioritization_list <- list()
for (region in regions) {
  gpkg_path <- get_file_path(region, runs[[region]]$gtfs_day, runs[[region]]$run, "prioritization", "gpkg")
  if (file.exists(gpkg_path)) {
    prioritization_list[[region]] <- st_read(gpkg_path, quiet = TRUE)
  }
}

unified_prioritization_sf <- NULL
if (length(prioritization_list) > 0) {
  unified_prioritization <- bind_rows(prioritization_list)

  unified_prioritization_agg <- unified_prioritization |>
    st_drop_geometry() |>
    group_by(way_osm_id, hour) |>
    summarise(
      frequency = sum(frequency, na.rm = TRUE),
      routes = paste(unique(unlist(strsplit(paste(routes, collapse = ";"), ";"))), collapse = ";"),
      shapes = paste(unique(unlist(strsplit(paste(shapes, collapse = ";"), ";"))), collapse = ";"),
      across(c(any_of(c("is_bus_lane", "n_lanes_parking", "n_lanes_circulation", "n_lanes", "n_directions", "n_lanes_circulation_direction", "n_lanes_direction", "name")), starts_with("speed_")), first),
      .groups = "drop"
    )

  unified_prioritization_sf <- unified_prioritization_agg |>
    left_join(unified_ways |> select(way_osm_id, geometry), by = "way_osm_id") |>
    st_as_sf()

  st_write(unified_prioritization_sf, sprintf("%s/prioritization_unified_%s_run%s.gpkg", output_dir, output_name, gsub("-", "", Sys.Date())), append = FALSE, delete_dsn = TRUE)
  write.csv(unified_prioritization_agg, sprintf("%s/prioritization_unified_%s_run%s.csv", output_dir, output_name, gsub("-", "", Sys.Date())), row.names = FALSE)
}

# 2.5 Merge Prioritization Area Polygons
message("Merging prioritization area polygons...")
polygon_list <- list()
for (region in regions) {
  gpkg_path <- get_file_path(region, runs[[region]]$gtfs_day, runs[[region]]$run, "prioritization_area_polygon", "gpkg")
  if (file.exists(gpkg_path)) {
    polygon_list[[region]] <- st_read(gpkg_path, quiet = TRUE)
  }
}

if (length(polygon_list) > 0) {
  unified_polygon <- bind_rows(polygon_list) |>
    st_union() |>
    st_convex_hull()
  st_write(unified_polygon, sprintf("%s/prioritization_area_polygon_unified_%s_run%s.gpkg", output_dir, output_name, gsub("-", "", Sys.Date())), append = FALSE, delete_dsn = TRUE)
  st_write(unified_polygon, sprintf("%s/prioritization_area_polygon_unified_%s_run%s.geojson", output_dir, output_name, gsub("-", "", Sys.Date())), append = FALSE, delete_dsn = TRUE)
}


# 3. Merge Way Data (JSON)
message("Merging way data...")
merged_ways_json <- list()
for (region in regions) {
  json_path <- get_file_path(region, runs[[region]]$gtfs_day, runs[[region]]$run, "way_data", "json")
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
write(json_string, sprintf("%s/way_data_unified_%s_run%s.json", output_dir, output_name, gsub("-", "", Sys.Date())))

# 4. Merge Route Data (JSON)
message("Merging route data...")
merged_routes_json <- list()
for (region in regions) {
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
  sprintf("%s/route_data_unified_%s_run%s.json", output_dir, output_name, gsub("-", "", Sys.Date())),
  auto_unbox = TRUE,
  digits = NA
)

# 5. Merge Shape Data (JSON & CSV)
message("Merging shape data...")
merged_shapes_json <- list()
for (region in regions) {
  json_path <- get_file_path(region, runs[[region]]$gtfs_day, runs[[region]]$run, "shape_data", "json")
  if (file.exists(json_path)) {
    shape_data <- read_json(json_path)
    for (shape_id in names(shape_data)) {
      shape <- shape_data[[shape_id]]
      if (is.null(merged_shapes_json[[shape_id]])) {
        merged_shapes_json[[shape_id]] <- shape
      } else {
        # Combine schedules if shape exists in multiple regions
        for (hour in names(shape$schedule)) {
          if (is.null(merged_shapes_json[[shape_id]]$schedule[[hour]])) {
            merged_shapes_json[[shape_id]]$schedule[[hour]] <- shape$schedule[[hour]]
          } else {
            merged_shapes_json[[shape_id]]$schedule[[hour]] <- merged_shapes_json[[shape_id]]$schedule[[hour]] + shape$schedule[[hour]]
          }
        }
      }
    }
  }
}
write_json(
  merged_shapes_json,
  sprintf("%s/shape_data_unified_%s_run%s.json", output_dir, output_name, gsub("-", "", Sys.Date())),
  auto_unbox = TRUE,
  digits = NA
)

shape_csv_list <- list()
for (region in regions) {
  csv_path <- get_file_path(region, runs[[region]]$gtfs_day, runs[[region]]$run, "shape_data", "csv")
  if (file.exists(csv_path)) {
    shape_csv_list[[region]] <- read.csv(csv_path)
  }
}
if (length(shape_csv_list) > 0) {
  unified_shape_csv <- bind_rows(shape_csv_list)
  unified_shape_csv <- unified_shape_csv |>
    group_by(shape_id) |>
    summarise(
      across(starts_with("schedule."), ~ sum(.x, na.rm = TRUE)),
      across(-starts_with("schedule."), first),
      .groups = "drop"
    )
  write.csv(unified_shape_csv, sprintf("%s/shape_data_unified_%s_run%s.csv", output_dir, output_name, gsub("-", "", Sys.Date())), row.names = FALSE)
}


# 6. Build Unified Metadata
message("Building unified metadata...")
metadata_list <- list()
for (region in regions) {
  json_path <- get_file_path(region, runs[[region]]$gtfs_day, runs[[region]]$run, "metadata", "json")
  if (file.exists(json_path)) {
    metadata_list[[region]] <- read_json(json_path)
  }
}

if (length(metadata_list) > 0) {
  unified_metadata <- list(
    region = "Unified Metro Area",
    gtfs = list(
      date = output_name,
      url = paste(sapply(metadata_list, function(x) x$gtfs$url), collapse = "; ")
    ),
    osm_query = metadata_list[[1]]$osm_query,
    execution = list(
      moment = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      script = "prioritize_unify.R",
      git_commit = system("git rev-parse HEAD", intern = TRUE)
    ),
    environment = metadata_list[[1]]$environment,
    source_regions = regions
  )

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
      stop_buffer_size = metadata_list[[1]]$rt$stop_buffer_size
    )
  } else {
    unified_metadata$rt <- NA
  }

  if (!is.null(unified_prioritization_sf) && nrow(unified_prioritization_sf) > 0) {
    ways_length <- unified_ways |>
      st_transform(crs = 3857) |>
      mutate(length_m = round(as.numeric(st_length(geometry)), digits = 2)) |>
      st_drop_geometry()

    prioritization_df <- unified_prioritization_sf |>
      st_drop_geometry() |>
      left_join(ways_length |> select(way_osm_id, length_m), by = "way_osm_id")

    prioritization_infrastructure <- prioritization_df |>
      distinct(way_osm_id, .keep_all = TRUE)

    census_frequency_hour <- list()
    for (h in 0:23) {
      prioritization_h <- prioritization_df |> filter(hour == h)
      census <- dataCensus(prioritization_h$frequency, prioritization_h$length_m)
      if (!is.na(census$mean)) {
        census_frequency_hour[[as.character(h)]] <- census
      }
    }

    unified_metadata$data_census <- list(
      frequency = dataCensus(prioritization_df$frequency, prioritization_df$length_m),
      frequency_hour = census_frequency_hour,
      speed_avg_length = NA,
      speed_avg_frequency = NA,
      lanes_length = dataCensus(prioritization_infrastructure$n_lanes_direction, prioritization_infrastructure$length_m),
      lanes_frequency = dataCensus(prioritization_infrastructure$n_lanes_direction, prioritization_infrastructure$frequency),
      prioritization_stats_length = lapply(
        GTFShift::get_prioritization_stats(prioritization_infrastructure, weight = "length"),
        function(x) if (is.numeric(x)) round(x, 2) else x
      ),
      prioritization_stats_frequency = lapply(
        GTFShift::get_prioritization_stats(prioritization_infrastructure, weight = "frequency"),
        function(x) if (is.numeric(x)) round(x, 2) else x
      )
    )
    if ("speed_avg" %in% colnames(prioritization_infrastructure)) {
      unified_metadata$data_census$speed_avg_length <- dataCensus(prioritization_infrastructure$speed_avg, prioritization_infrastructure$length_m)
      unified_metadata$data_census$speed_avg_frequency <- dataCensus(prioritization_infrastructure$speed_avg, prioritization_infrastructure$frequency)
    }
  }

  write_json(
    unified_metadata,
    sprintf("%s/metadata_unified_%s_run%s.json", output_dir, output_name, gsub("-", "", Sys.Date())),
    auto_unbox = TRUE,
    digits = NA
  )
}

message("Done!")
