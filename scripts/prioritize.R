# Script to generate pre-processed data for GTFShift web dashboard

library(GTFShift)
library(dplyr)
library(stringr)
library(sf)
library(mapview)
library(jsonlite)
library(osmdata)
library(Hmisc) # For  Weighted Statistical Estimates
get_overpass_url()
set_overpass_url("https://overpass-api.de/api/interpreter/")
set_overpass_url("https://maps.mail.ru/osm/tools/overpass/api/interpreter") # Crashes less and responds quicker than default one
set_overpass_url("https://overpass.private.coffee/api/interpreter") # 4 servers with 20 cores, 256GB RAM, SSD each
set_overpass_url("https://overpass.kumi.systems/api/interpreter")
get_overpass_url()
# set_overpass_url("https://overpass-api.de/api/interpreter")

# Refer to prioritize_parameters.R to define parameters before running this script!

# main()
stop_buffer_size <- 15 # meters

if (!dir.exists(output)) {
  dir.create(output, recursive = TRUE)
}

for (i in 1:nrow(regions)) {
  # 1. Load data for region
  region <- regions[i, ]
  message(sprintf("\n\nRunning for %s (%s)...", region$name, region$gtfs_day))

  output_region <- sprintf("%s/%s/%s", output, region$name, region$gtfs_day)
  if (!dir.exists(output_region)) {
    dir.create(output_region, recursive = TRUE)
  }

  gtfs <- GTFShift::load_feed(region$gtfs_url)
  # assign(sprintf("gtfs_%s_%s", region$name, region$gtfs_day), gtfs)
  # tidytransit::write_gtfs(gtfs, sprintf("%s/gtfs_%s_%s.zip", output_region, region$name, region$gtfs_day))

  gtfs_shapes <- tidytransit::shapes_as_sf(gtfs$shapes)
  bbox <- sf::st_bbox(gtfs_shapes)

  if (!is.null(region$gtfs_manipulate)) {
    message("Manipulating GTFS with function: ", region$gtfs_manipulate)
    gtfs <- get(region$gtfs_manipulate)(gtfs)
    message("GTFS manipulation completed.")
  }

  # Build OSM query
  q <- opq(bbox = bbox)
  for (feat in region$query[[1]]) {
    q <- add_osm_feature(
      q,
      key = feat$key,
      value = feat$value,
      key_exact = if (!is.null(feat$key_exact)) feat$key_exact else FALSE
    )
  }
  # assign(sprintf("q_%s_gtfs%s", region$name, region$gtfs_day), q)

  # 2. Prioritize based on planned operation and infrastructure characteristics
  prioritization <- GTFShift::prioritize_lanes(gtfs, q, date = region$gtfs_day, keep_osm_attributes = TRUE)
  # assign(sprintf("prioritization_%s_gtfs%s", region$name, region$gtfs_day), prioritization)

  prioritization <- prioritization |>
    select(way_osm_id, hour, frequency, is_bus_lane, n_lanes_parking, n_lanes_circulation, n_lanes, n_directions, n_lanes_circulation_direction, n_lanes_direction, routes, shapes, name, geometry)

  write.csv(
    prioritization |>
      sf::st_drop_geometry() |>
      mutate(
        # Convert vector of strings to single string with ";" separator
        routes = sapply(routes, function(x) paste(x, collapse = ";"), USE.NAMES = FALSE),
        shapes = sapply(shapes, function(x) paste(x, collapse = ";"), USE.NAMES = FALSE)
      ),
    sprintf("%s/prioritization_%s_gtfs%s_run%s.csv", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())),
    row.names = FALSE
  )

  # 3. Extend with real-time data if available
  if (!is.null(region$rt_collection) && !is.na(region$rt_collection)) {
    rt_collection <- region$rt_collection[[1]]
    # Filter updates, to remove those close to bus stops
    gtfs_stops <- tidytransit::stops_as_sf(gtfs$stops, crs = 4326)

    within_distance <- st_is_within_distance(rt_collection |> st_transform(crs = 3857), gtfs_stops |> st_transform(crs = 3857), dist = stop_buffer_size)

    rt_collection_filtered <- rt_collection[lengths(within_distance) == 0, ]

    # Extend prioritization with real-time data
    prioritization <- rt_extend_prioritization(
      lane_prioritization = prioritization,
      rt_collection = rt_collection_filtered
    ) |> mutate(
      # Round all columns that start with speed_ to 2 decimals
      across(starts_with("speed_"), ~ round(., 2))
    )
  }
  st_write(prioritization |> mutate(
    routes = sapply(routes, function(x) paste(x, collapse = ";"), USE.NAMES = FALSE),
    shapes = sapply(shapes, function(x) paste(x, collapse = ";"), USE.NAMES = FALSE)
  ), sprintf("%s/prioritization_%s_gtfs%s_run%s.gpkg", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), append = FALSE)

  # 4. Build data for dashboard
  # > 4.1. Store ways geometries
  ways <- prioritization |>
    distinct(way_osm_id, geometry)
  st_write(ways, sprintf("%s/ways_%s_gtfs%s_run%s.gpkg", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), append = FALSE)
  st_write(ways, sprintf("%s/ways_%s_gtfs%s_run%s.geojson", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), append = FALSE)

  ways_length <- ways |> # Convert to 3857 crs
    st_transform(crs = 3857) |>
    # Calculate lenght in meters
    mutate(length_m = st_length(geometry)) |>
    # Drop units
    mutate(length_m = round(as.numeric(length_m), digits = 2))

  # > 4.2. Store prioritization as json, grouping by way_osm_id, each grouped by hour
  nested_data <- lapply(split(
    prioritization |>
      st_drop_geometry() |>
      left_join(ways_length |> select(way_osm_id, length_m) |> st_drop_geometry()),
    prioritization$way_osm_id
  ), function(df) {
    # 1. Extract first row and convert to list
    static_df <- df[1, ] %>% select(-way_osm_id, -hour, -frequency)
    static_info <- as.list(static_df)

    # 2. Extract values from list-columns and wrap routes/shapes in I()
    # This ensures they remain arrays even with length 1
    for (col in names(static_info)) {
      if (col == "routes") {
        static_info[[col]] <- unique(unlist(df$routes))
      } else if (col == "shapes") {
        static_info[[col]] <- unique(unlist(df$shapes))
      } else if (is.list(static_info[[col]])) {
        # If it's a list-column (common in sf/dplyr), grab the vector inside
        static_info[[col]] <- static_info[[col]][[1]]
      }

      # Protect specific columns from unboxing
      if (col %in% c("routes", "shapes")) {
        static_info[[col]] <- I(as.character(na.omit(static_info[[col]])))
      }
    }

    # 3. Hourly frequencies (auto_unbox will handle these as single numbers)
    hourly_freqs <- setNames(as.list(df$frequency), df$hour)

    # Combine
    c(static_info, list(hour_frequency = hourly_freqs))
  })
  json_string <- toJSON(
    nested_data,
    na = "null", # To avoid NAs being converted to strings in JSON
    auto_unbox = TRUE,
    pretty = TRUE
  )
  write(
    json_string,
    sprintf("%s/way_data_%s_gtfs%s_run%s.json", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date()))
  )

  # > 4.3. Store route data
  gtfs_date <- tidytransit::filter_feed_by_date(gtfs, extract_date = region$gtfs_day)
  routes <- GTFShift::get_route_frequency_hourly(gtfs_date, date = region$gtfs_day) |>
    st_drop_geometry() |>
    select(-route_short_name) |>
    left_join(gtfs$routes |> select(route_id, route_short_name, route_long_name), by = "route_id") |>
    left_join(gtfs_date$routes |> select(route_id, route_color, route_text_color), by = "route_id")
  # If route_color does not start with "#", add suffix
  routes <- routes |> mutate(
    route_color = ifelse(!str_starts(route_color, "#"), paste0("#", route_color), route_color),
    route_text_color = ifelse(!str_starts(route_text_color, "#"), paste0("#", route_text_color), route_text_color)
  )

  nested_shapes <- lapply(split(routes, routes$shape_id), function(df) {
    # Extract static metadata associated with this shape
    shape_metadata <- df[1, ] %>%
      select(route_id, shape_id, route_short_name, route_long_name, direction_id, route_color, route_text_color) %>%
      as.list()

    # Create the hourly frequency mapping
    hourly_frequencies <- setNames(as.list(df$frequency), df$hour)

    # Get stats for shape
    prioritization_shape <- prioritization |>
      rowwise() |>
      filter(shape_metadata$shape_id %in% shapes) |>
      ungroup()
    # > If no stats, ignore shape
    if (nrow(prioritization_shape) == 0) {
      return(NULL)
    }
    shape_metadata$stats <- GTFShift::get_prioritization_stats(
      prioritization_shape |> distinct(way_osm_id, .keep_all = TRUE) |> rename(geom = geometry),
      weight = "length"
    )
    # Round all numeric values to 2 decimals
    shape_metadata$stats <- lapply(shape_metadata$stats, function(x) {
      if (is.numeric(x)) {
        round(x, 2)
      } else {
        x
      }
    })

    # Combine metadata with the hourly 'schedule'
    c(shape_metadata, list(schedule = hourly_frequencies))
  })
  nested_shapes <- nested_shapes[!sapply(nested_shapes, is.null)]
  nested_shapes_df <- bind_rows(lapply(nested_shapes, function(x) {
    # Prepend prefixes to sub-list names before flattening
    names(x$stats) <- paste0("stats.", names(x$stats))
    names(x$schedule) <- paste0("schedule.", names(x$schedule))

    # Flatten everything into one list and convert to tibble
    as_tibble(c(x[!(names(x) %in% c("stats", "schedule"))], x$stats, x$schedule))
  }))

  write_json(
    nested_shapes,
    sprintf("%s/shape_data_%s_gtfs%s_run%s.json", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())),
    auto_unbox = TRUE,
    digits = NA # To avoid precision loss in coordinates
  )
  write.csv(nested_shapes_df, sprintf("%s/shape_data_%s_gtfs%s_run%s.csv", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())))

  nested_routes <- lapply(split(gtfs_date$routes |> select(route_id, route_short_name, route_long_name, route_color, route_text_color), gtfs_date$routes$route_id), function(df) {
    route_metadata <- df[1, ] %>%
      as.list()

    c(route_metadata)
  })
  write_json(
    nested_routes,
    sprintf("%s/route_data_%s_gtfs%s_run%s.json", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())),
    auto_unbox = TRUE,
    digits = NA # To avoid precision loss in coordinates
  )

  # > 4.4. Store metadata about execution details
  prioritization <- prioritization |>
    left_join(ways_length |> select(way_osm_id, length_m) |> st_drop_geometry(), by = "way_osm_id")
  prioritization_infrastructure <- prioritization |>
    distinct(way_osm_id, .keep_all = TRUE) |>
    rename(geom = geometry)

  shapes_found <- unique(unlist(prioritization$shapes))
  shapes_missing <- unique(gtfs_date$shapes$shape_id) %>% setdiff(shapes_found)
  shapes_found_frequency <- sum((routes |> filter(shape_id %in% shapes_found))$frequency)
  shapes_missing_frequency <- sum((routes |> filter(shape_id %in% shapes_missing))$frequency)

  routes_missing <- routes |>
    group_by(route_id) |>
    summarise(
      shapes = list(unique(shape_id)),
      n_shapes = length(unique(shape_id))
    ) |>
    mutate(
      n_shapes_missing = sapply(shapes, function(s_list) sum(s_list %in% shapes_missing))
    ) |>
    filter(n_shapes_missing > 0) |>
    select(-shapes)
  routes_missing_nested <- lapply(split(routes_missing, routes_missing$route_id), function(df) {
    df %>%
      select(n_shapes, n_shapes_missing) %>%
      as.list()
  })

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
      sd = round(sqrt(wtd.var(numberArray, weights = weights, na.rm = TRUE)), digits = 2)
    ))
  }

  rt_list <- NA
  if (!is.null(region$rt_collection) && !is.na(region$rt_collection)) {
    rt_list <- list(
      url = "", # To be edited manually
      period = region$rt_interval,
      stop_buffer_size = stop_buffer_size
    )
  }
  census_frequency_hour <- list()
  for (h in 0:23) {
    prioritization_hour <- prioritization |> filter(hour == h)
    census <- dataCensus(prioritization_hour$frequency, prioritization_hour$length_m)
    if (!is.na(census$mean)) {
      census_frequency_hour[[as.character(h)]] <- census
    }
  }

  metadata <- list(
    region = region$name_long,
    gtfs = list(
      date = region$gtfs_day,
      url = region$gtfs_url
    ),
    osm_query = lapply(region$query[[1]], function(feat) {
      list(
        key = feat$key,
        value = feat$value,
        key_exact = if (!is.null(feat$key_exact)) feat$key_exact else FALSE
      )
    }),
    prioritization = list(
      shapes_missing = shapes_missing,
      routes_missing = routes_missing_nested,
      shapes_total = length(unique(gtfs$shapes$shape_id)),
      shapes_found_n = length(shapes_found),
      shapes_missing_n = length(shapes_missing),
      shapes_total_frequency = sum(routes$frequency),
      shapes_found_frequency = shapes_found_frequency,
      shapes_missing_frequency = shapes_missing_frequency,
      rountes_missing_n = nrow(routes_missing),
      routes_found_n = nrow(routes) - nrow(routes_missing)
    ),
    data_census = list(
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
    ),
    rt = rt_list,
    execution = list(
      moment = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      script = "dev/web_version.R",
      git_commit = system("git rev-parse HEAD", intern = TRUE)
    ),
    environment = list(
      r = R.version.string,
      GTFShift = as.character(packageVersion("GTFShift")),
      os = Sys.info()[["sysname"]],
      os_release = Sys.info()[["release"]]
    )
  )
  if ("speed_avg" %in% colnames(prioritization_infrastructure)) {
    metadata$data_census$speed_avg_length <- dataCensus(prioritization_infrastructure$speed_avg, prioritization_infrastructure$length_m)
    metadata$data_census$speed_avg_frequency <- dataCensus(prioritization_infrastructure$speed_avg, prioritization_infrastructure$frequency)
  }
  write_json(
    metadata,
    sprintf("%s/metadata_%s_gtfs%s_run%s.json", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())),
    auto_unbox = TRUE,
    digits = NA
  )
}

# Debug
library(sf)
prioritization_debug <- prioritization |> mutate(
  routes = sapply(routes, function(x) paste(x, collapse = ";"), USE.NAMES = FALSE),
  shapes = sapply(shapes, function(x) paste(x, collapse = ";"), USE.NAMES = FALSE)
)
# prioritization <- st_read("releases/web/lisboa/2026-02-04/prioritization_lisboa_rt_gtfs2026-02-04_run20260203_extended.geojson")
loures <- sf::st_read("https://github.com/U-Shift/MQAT/raw/refs/heads/main/geo/MUNICIPIOSgeo.gpkg", quiet = TRUE) |> filter(Concelho == "Loures")

prioritization_0800 <- prioritization_debug |> filter(hour == 8)
prioritization_0800 <- st_intersection(prioritization_0800, loures)

p50_frequency <- quantile(prioritization_0800$frequency, 0.5, na.rm = TRUE)
p50_speed <- quantile(prioritization_0800$speed_avg, 0.5, na.rm = TRUE)
mapview::mapview(
  prioritization_0800 |> filter(is_bus_lane & (frequency < p50_frequency | (is.na(n_lanes) | n_lanes_direction <= 1) | speed_avg <= p50_speed)),
  layer.name = sprintf("Bus lane with -%d bus/h OR -2 lane/dir OR %.2f km/h or - avg. speed", p50_frequency, p50_speed),
  color = "#DAD887",
  homebutton = FALSE,
  lwd = 3
) + mapview::mapview(
  prioritization_0800 |> filter(is_bus_lane & frequency >= p50_frequency & !is.na(n_lanes) & n_lanes_direction > 1 & speed_avg > p50_speed),
  layer.name = sprintf("Bus lane with +%d bus/h AND +1 lane/dir AND +%.2f km/h avg.speed", p50_frequency - 1, p50_speed),
  color = "#3BC1A8",
  homebutton = FALSE,
  lwd = 3
) + mapview::mapview(
  prioritization_0800 |> filter(!is_bus_lane & frequency >= p50_frequency & !is.na(n_lanes) & n_lanes_direction > 1 & speed_avg <= p50_speed),
  layer.name = sprintf("NO bus lane with +%d bus/h AND +1 lane/dir AND %.2f km/h or - avg.speed", p50_frequency - 1, p50_speed),
  color = "#F63049",
  homebutton = FALSE,
  lwd = 3
)


mapview::mapview(
  prioritization_0800,
  color = rev(viridis::viridis(10, option = "F")),
  zcol = "speed_avg",
  layer.name = "Average speed per lane"
)

mapview::mapview(
  prioritization_0800,
  color = rev(viridis::viridis(10, option = "F")),
  zcol = "n_lanes_direction",
  layer.name = "Lanes/direction"
) + mapview::mapview(
  prioritization_0800,
  color = rev(viridis::viridis(10, option = "F")),
  zcol = "n_lanes_parking",
  layer.name = "Parking lanes",
  hide = TRUE
) + mapview::mapview(
  prioritization_0800,
  color = rev(viridis::viridis(10, option = "F")),
  zcol = "n_lanes_circulation",
  layer.name = "Circulation lanes",
  hide = TRUE
)


mapview::mapview(
  prioritization_0800 |> filter(is_bus_lane == TRUE),
  layer.name = "Bus lanes",
  color = "#3bc1a8"
)

mapview::mapview(loures) +
  mapview::mapview(
    prioritization_0800 |> filter(n_lanes_direction > 1),
    color = rev(viridis::viridis(10, option = "F")),
    zcol = "n_lanes_direction",
    layer.name = "Lanes/direction"
  )
