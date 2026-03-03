# Script to generate pre-processed data for GTFShift web dashboard

library(GTFShift)
library(dplyr)
library(stringr)
library(sf)
library(mapview)

library(osmdata)
get_overpass_url ()
set_overpass_url ("https://maps.mail.ru/osm/tools/overpass/api/interpreter") # Crashes less and responds quicker than default one
get_overpass_url ()

# Refer to prioritize_parameters.R to define parameters before running this script!

# main()
stop_buffer_size = 15 # meters

if (!dir.exists(output)) {
  dir.create(output, recursive = TRUE)
}

for(i in 1:nrow(regions)) {
  region <- regions[i, ]
  message(sprintf("\n\nRunning for %s (%s)...", region$name, region$gtfs_day))

  output_region = sprintf("%s/%s/%s", output, region$name, region$gtfs_day)
  if (!dir.exists(output_region)) {
    dir.create(output_region, recursive = TRUE)
  }

  gtfs = GTFShift::load_feed(region$gtfs_url)
  # assign(sprintf("gtfs_%s_%s", region$name, region$gtfs_day), gtfs)
  tidytransit::write_gtfs(gtfs, sprintf("%s/gtfs_%s_%s.zip", output_region, region$name, region$gtfs_day))

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

  # Prioritize based on planned operation and infrastructure characteristics
  prioritization = prioritize_lanes(gtfs, q, date=region$gtfs_day)
  # assign(sprintf("prioritization_%s_gtfs%s", region$name, region$gtfs_day), prioritization)

  write.csv(prioritization |> sf::st_drop_geometry(), sprintf("%s/prioritization_%s_gtfs%s_run%s.csv", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), row.names = FALSE)
  sf::st_write(prioritization, sprintf("%s/prioritization_%s_gtfs%s_run%s.gpkg", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), append=FALSE)

  # prioritization = st_read(sprintf("%s/prioritization_%s_gtfs%s_run%s.gpkg", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())))

  # Extend with real-time data if available
  if (!is.na(region$rt_collection)) {
    rt_collection = region$rt_collection[[1]]
    # Filter updates, to remove those close to bus stops
    gtfs_stops = tidytransit::stops_as_sf(gtfs$stops, crs=4326)

    within_distance <- st_is_within_distance(rt_collection |> st_transform(crs=3857), gtfs_stops |> st_transform(crs=3857), dist = stop_buffer_size)

    rt_collection_filtered = rt_collection[lengths(within_distance) == 0, ]

    # Extend prioritization with real-time data
    prioritization = rt_extend_prioritization(
      lane_prioritization = prioritization,
      rt_collection = rt_collection_filtered
    )
  }

  # Replace route_id with route names, considering that prioritization$routes has multiple route_ids separated by ";"
  route_names = gtfs$routes[, c("route_id", "route_short_name", "route_long_name")]
  prioritization = prioritization |>
    mutate(row_n = row_number())
  prioritization_routes = prioritization |>
    st_drop_geometry() |>
    tidyr::separate_rows(routes, sep = ";")
  routes_covered = prioritization_routes |>
    select(routes) |>
    distinct()
  routes_covered = routes_covered |>
    left_join(route_names, by = c("routes" = "route_id")) |>
    mutate(
      route_name = ifelse(!is.na(route_short_name) & route_short_name != "", route_short_name, route_long_name)
    ) |>
    select(routes, route_name)
  prioritization_routes = prioritization_routes |>
    left_join(routes_covered, by = c("routes" = "routes"))
  prioritization_routes_grouped = prioritization_routes |>
    group_by(row_n) |>
    summarise(
      route_names = paste(unique(route_name), collapse = ";"),
      .groups = "drop"
    )
  prioritization = prioritization |>
    left_join(prioritization_routes_grouped, by = c("row_n" = "row_n")) |>
    select(-row_n)

  # Save outputs
  write.csv(prioritization |> sf::st_drop_geometry(), sprintf("%s/prioritization_%s_gtfs%s_run%s_extended.csv", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), row.names = FALSE)
  sf::st_write(prioritization, sprintf("%s/prioritization_%s_gtfs%s_run%s_extended.gpkg", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), append=FALSE)
  
  
  # Web version data preparation
  
  # 1. Get base road network 
  ways = prioritization |> 
    distinct(way_osm_id, geometry)
  
  # arroios = opq("Arroios, Lisboa, Portugal") |>
  #   add_osm_feature(key = "highway", value = c("motorway", "trunk", "primary", "secondary", "tertiary", "residential", "unclassified", "living_street")) |>
  #   add_osm_feature(key = "area", value = "!yes") |>
  #   osmdata_sf() |>
  #   osm_poly2line()
  # arroios = arroios$osm_lines
  # mapview(arroios |> st_bbox() |> st_as_sfc())
  # mapview(ways |> st_filter(arroios |> st_bbox() |> st_as_sfc()))
  
  st_write(ways, sprintf("%s/ways_%s_gtfs%s_run%s.geojson", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), append=FALSE, delete_dsn = TRUE)
  st_write(ways, sprintf("%s/ways_%s_gtfs%s_run%s.gpkg", output_region, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), append=FALSE)
  
  # 2. Compute geojson with metadata
  # TODO! From hereee
  
  dataCensus = function (numberArray) {
    return(list(
      min = min(numberArray, na.rm=TRUE),
      max = max(numberArray, na.rm=TRUE),
      p25 = as.numeric(quantile(numberArray, 0.25, na.rm=TRUE)),
      p75 = as.numeric(quantile(numberArray, 0.75, na.rm=TRUE)),
      mean = mean(numberArray, na.rm=TRUE),
      median = as.numeric(median(numberArray, na.rm=TRUE)),
      variance = var(numberArray, na.rm=TRUE),
      sd = sd(numberArray, na.rm=TRUE)
    ))
  }

  rt_list = NA
  if(!is.na(region$rt_collection)) {
    rt_list = list(
      url = "", # To be edited manually
      period = region$rt_interval,
      stop_buffer_size = stop_buffer_size
    )
  }
  census_frequency_hour = list()
  for(h in 0:23) {
    prioritization_hour = prioritization |> filter(hour == h)
    census_frequency_hour[[as.character(h)]] = dataCensus(prioritization_hour$frequency)
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
      routes_missing = paste(gtfs$routes |> filter(!route_short_name %in% routes_covered$route_name) |> distinct(route_short_name) |> pull(route_short_name), collapse = ";"),
      routes_covered = nrow(routes_covered),
      routes_total = nrow(gtfs$routes)
    ),
    data_census = list(
      frequency = dataCensus(prioritization$frequency),
      frequency_hour = census_frequency_hour,
      speed_avg = dataCensus(prioritization$speed_avg),
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

  geojson_data$metadata <- metadata
  # Save at geojson_file.replace(".geojson", "_with_metadata.geojson")
  geojson_file_metadata = gsub(".geojson$", "_with_metadata.geojson", geojson_file)
  jsonlite::write_json(
    geojson_data,
    geojson_file_metadata,
    auto_unbox = TRUE,
    digits=NA # To avoid precision loss in coordinates
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
