# Script to generate pre-processed data for GTFShift web dashboard

library(GTFShift)
library(dplyr)
library(stringr)
library(sf)
library(mapview)
library(jsonlite)
library(osmdata)
get_overpass_url()
set_overpass_url("https://maps.mail.ru/osm/tools/overpass/api/interpreter") # Crashes less and responds quicker than default one
set_overpass_url("https://overpass.private.coffee/api/interpreter") # 4 servers with 20 cores, 256GB RAM, SSD each 
get_overpass_url()
# set_overpass_url("https://overpass-api.de/api/interpreter")

# Refer to prioritize_parameters.R to define parameters before running this script!

# main()
stop_buffer_size = 15 # meters

if (!dir.exists(output)) {
  dir.create(output, recursive = TRUE)
}

for(i in 1:nrow(regions)) {
  # 1. Load data for region
  region <- regions[i, ]
  message(sprintf("\n\nRunning for %s (%s)...", region$name, region$gtfs_day))

  output_region = sprintf("%s/%s/%s", output, region$name, region$gtfs_day)
  if (!dir.exists(output_region)) {
    dir.create(output_region, recursive = TRUE)
  }

  gtfs = GTFShift::load_feed(region$gtfs_url)
  # assign(sprintf("gtfs_%s_%s", region$name, region$gtfs_day), gtfs)
  # tidytransit::write_gtfs(gtfs, sprintf("%s/gtfs_%s_%s.zip", output_region, region$name, region$gtfs_day))

  gtfs_shapes = tidytransit::shapes_as_sf(gtfs$shapes)
  bbox = sf::st_bbox(gtfs_shapes)

  if (!is.null(region$gtfs_manipulate)) {
    message("Manipulating GTFS with function: ", region$gtfs_manipulate)
    gtfs = get(region$gtfs_manipulate)(gtfs)
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
  prioritization = GTFShift::prioritize_lanes(gtfs, q, date=region$gtfs_day, keep_osm_attributes = TRUE)
  # assign(sprintf("prioritization_%s_gtfs%s", region$name, region$gtfs_day), prioritization)
  
  prioritization = prioritization |>
    select(way_osm_id, hour, frequency, is_bus_lane, n_lanes_parking, n_lanes_circulation, n_lanes, n_directions, n_lanes_circulation_direction, n_lanes_direction, routes, shapes, name, geometry)

  write.csv(
    prioritization |> 
      sf::st_drop_geometry() |> 
      mutate(
        # Convert vector of strings to single string with ";" separator
        routes = sapply(routes, function(x) paste(x, collapse = ";"), USE.NAMES = FALSE),
        shapes = sapply(shapes, function(x) paste(x, collapse = ";"), USE.NAMES = FALSE)
      )
    , 
    sprintf("%s/prioritization_%s_gtfs%s_run%s.csv", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), 
    row.names = FALSE
  )

  # 3. Extend with real-time data if available
  if (!is.null(region$rt_collection) && !is.na(region$rt_collection)) {
    rt_collection = region$rt_collection[[1]]
    # Filter updates, to remove those close to bus stops
    gtfs_stops = tidytransit::stops_as_sf(gtfs$stops, crs=4326)

    within_distance <- st_is_within_distance(rt_collection |> st_transform(crs=3857), gtfs_stops |> st_transform(crs=3857), dist = stop_buffer_size)

    rt_collection_filtered = rt_collection[lengths(within_distance) == 0, ]

    # Extend prioritization with real-time data
    prioritization = rt_extend_prioritization(
      lane_prioritization = prioritization,
      rt_collection = rt_collection_filtered
    ) |> mutate(
      # Round all columns that start with speed_ to 2 decimals
      across(starts_with("speed_"), ~ round(., 2))
    )
  }

  # 4. Build data for dashboard 
  # > 4.1. Store ways geometries
  ways = prioritization |> 
    distinct(way_osm_id, geometry)
  st_write(ways, sprintf("%s/ways_%s_gtfs%s_run%s.gpkg", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), append=FALSE)
  st_write(ways, sprintf("%s/ways_%s_gtfs%s_run%s.geojson", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), append=FALSE)
  
  ways_length = ways |> # Convert to 3857 crs
    st_transform(crs=3857) |>
    # Calculate lenght in meters
    mutate(length_m = st_length(geometry)) |>
    # Drop units
    mutate(length_m = round(as.numeric(length_m), digits=2))
  
  # > 4.2. Store prioritization as json, grouping by way_osm_id, each grouped by hour
  nested_data <- lapply(split(prioritization |> 
                                st_drop_geometry() |> 
                                left_join(ways_length |> select(way_osm_id, length_m) |> st_drop_geometry()), 
                              prioritization$way_osm_id), function(df) {
    
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
  gtfs_date = tidytransit::filter_feed_by_date(gtfs, extract_date=region$gtfs_day)
  routes = GTFShift::get_route_frequency_hourly(gtfs_date, date=region$gtfs_day) |>
    st_drop_geometry() |>
    left_join(gtfs_date$routes |> select(route_id, route_long_name)) |>
    left_join(gtfs$routes |> select(route_id, route_color, route_text_color), by="route_id")
  nested_shapes <- lapply(split(routes, routes$shape_id), function(df) {
    
    # Extract static metadata associated with this shape
    shape_metadata <- df[1, ] %>% 
      select(route_id, route_short_name, route_long_name, direction_id, route_color, route_text_color) %>% 
      as.list()
    
    # Create the hourly frequency mapping
    hourly_frequencies <- setNames(as.list(df$frequency), df$hour)
    
    # Combine metadata with the hourly 'schedule'
    c(shape_metadata, list(schedule = hourly_frequencies))
  })
  write_json(
    nested_shapes,
    sprintf("%s/shape_data_%s_gtfs%s_run%s.json", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())),
    auto_unbox = TRUE,
    digits=NA # To avoid precision loss in coordinates
  )
  
  nested_routes = lapply(split(gtfs_date$routes |> select(route_id, route_short_name, route_long_name,route_color,route_text_color), gtfs_date$routes$route_id), function(df) {
    route_metadata <- df[1, ] %>% 
      as.list()
    
    c(route_metadata)
  })
  write_json(
    nested_routes,
    sprintf("%s/route_data_%s_gtfs%s_run%s.json", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())),
    auto_unbox = TRUE,
    digits=NA # To avoid precision loss in coordinates
  )
  
  # > 4.4. Store metadata about execution details
  shapes_found = unique(unlist(prioritization$shapes))
  shapes_missing = unique(gtfs$shapes$shape_id) %>% setdiff(shapes_found)
  
  routes_missing = routes |> 
    group_by(route_id) |>
    summarise(
      shapes = list(unique(shape_id)),
      n_shapes = length(unique(shape_id))
    ) |>
    mutate(
      n_shapes_missing = sapply(shapes, function(s_list) sum(s_list %in% shapes_missing))
    ) |>
    filter(n_shapes_missing>0) |>
    select(-shapes)
  routes_missing_nested <- lapply(split(routes_missing, routes_missing$route_id), function(df) {
    df %>% 
      select(n_shapes, n_shapes_missing) %>% 
      as.list()
  })
  
  dataCensus = function (numberArray) {
    return(list(
      min = round(min(numberArray, na.rm=TRUE), digits=2),
      max = round(max(numberArray, na.rm=TRUE), digits=2),
      p5 = round(as.numeric(quantile(numberArray, 0.05, na.rm=TRUE)), digits=2),
      p25 = round(as.numeric(quantile(numberArray, 0.25, na.rm=TRUE)), digits=2),
      p75 = round(as.numeric(quantile(numberArray, 0.75, na.rm=TRUE)), digits=2),
      p95 = round(as.numeric(quantile(numberArray, 0.95, na.rm=TRUE)), digits=2),
      mean = round(mean(numberArray, na.rm=TRUE), digits=2),
      median = round(as.numeric(median(numberArray, na.rm=TRUE)), digits=2),
      variance = round(var(numberArray, na.rm=TRUE), digits=2),
      sd = round(sd(numberArray, na.rm=TRUE), digits=2)
    ))
  }

  rt_list = NA
  if(!is.null(region$rt_collection) && !is.na(region$rt_collection)) {
    rt_list = list(
      url = "", # To be edited manually
      period = region$rt_interval,
      stop_buffer_size = stop_buffer_size
    )
  }
  census_frequency_hour = list()
  for(h in 0:23) {
    prioritization_hour = prioritization |> filter(hour == h)
    census = dataCensus(prioritization_hour$frequency)
    if (!is.na(census$mean)) {
      census_frequency_hour[[as.character(h)]] = census
    }
  }

  metadata = list(
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
      shapes_total = length(unique(gtfs$shapes$shape_id))
    ),
    data_census = list(
      frequency = dataCensus(prioritization$frequency),
      frequency_hour = census_frequency_hour,
      speed_avg = NA,
      lanes = dataCensus(prioritization$n_lanes_direction)
    ),
    rt = rt_list,
    execution = list(
      moment = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      script = "dev/web_version.R",
      git_commit = system("git rev-parse HEAD", intern=TRUE)
    ),
    environment = list(
      r = R.version.string,
      GTFShift = as.character(packageVersion("GTFShift")),
      os = Sys.info()[["sysname"]],
      os_release = Sys.info()[["release"]]
    )
  )
  if ("speed_avg" %in% colnames(prioritization)) {
    metadata$data_census$speed_avg = dataCensus(prioritization$speed_avg)
  }
  write_json(
    metadata,
    sprintf("%s/metadata_%s_gtfs%s_run%s.json", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())),
    auto_unbox = TRUE,
    digits=NA
  )
}

# Debug
library(sf)
# prioritization = st_read("releases/web/lisboa/2026-02-04/prioritization_lisboa_rt_gtfs2026-02-04_run20260203_extended.geojson")
loures = sf::st_read("https://github.com/U-Shift/MQAT/raw/refs/heads/main/geo/MUNICIPIOSgeo.gpkg", quiet = TRUE) |> filter(Concelho=="Loures")

prioritization = st_read("scripts/dev/web_version/aml_rt/2026-02-04/prioritization_aml_rt_gtfs2026-02-04_run20260210_extended.gpkg")

prioritization_0800 = prioritization |> filter(hour==8)
prioritization_0800 = st_intersection(prioritization_0800, loures)

p50_frequency = quantile(prioritization_0800$frequency, 0.5, na.rm=TRUE)
p50_speed = quantile(prioritization_0800$speed_avg, 0.5, na.rm=TRUE)
mapview::mapview(
  prioritization_0800 |> filter(is_bus_lane & (frequency<p50_frequency | (is.na(n_lanes) | n_lanes_direction<=1) | speed_avg<=p50_speed)),
  layer.name=sprintf("Bus lane with -%d bus/h OR -2 lane/dir OR %.2f km/h or - avg. speed", p50_frequency, p50_speed),
  color="#DAD887",
  homebutton=FALSE,
  lwd=3

) + mapview::mapview(
  prioritization_0800 |> filter(is_bus_lane & frequency>=p50_frequency & !is.na(n_lanes) & n_lanes_direction>1 & speed_avg>p50_speed),
  layer.name=sprintf("Bus lane with +%d bus/h AND +1 lane/dir AND +%.2f km/h avg.speed", p50_frequency-1, p50_speed),
  color="#3BC1A8",
  homebutton=FALSE,
  lwd=3
) + mapview::mapview(
  prioritization_0800 |> filter(!is_bus_lane & frequency>=p50_frequency & !is.na(n_lanes) & n_lanes_direction>1 & speed_avg<=p50_speed),
  layer.name=sprintf("NO bus lane with +%d bus/h AND +1 lane/dir AND %.2f km/h or - avg.speed", p50_frequency-1, p50_speed),
  color="#F63049",
  homebutton=FALSE,
  lwd=3
)


mapview::mapview(
  prioritization_0800,
  col.regions = viridis::viridis(nrow(prioritization_0800), option = "C"),
  zcol = "speed_avg",
  layer.name = "Average speed per lane"
)

mapview::mapview(
  prioritization_0800,
  col.regions = viridis::viridis(nrow(prioritization_0800), option = "C"),
  zcol = "n_lanes_direction",
  layer.name = "Lanes/direction"
)

mapview::mapview(loures)+
mapview::mapview(
  prioritization_0800 |> filter(n_lanes_direction>1),
  col.regions = viridis::viridis(nrow(prioritization_0800), option = "C"),
  zcol = "n_lanes_direction",
  layer.name = "Lanes/direction"
)
