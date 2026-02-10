# Aggregate prioritization results for multiple agencies

library(sf)
library(dplyr) # For coalesce

p_lisboa = st_read("dev/web_version/lisboa_rt/2026-02-04/prioritization_lisboa_rt_gtfs2026-02-04_run20260207_extended.gpkg")
View(p_lisboa)

prioritizations = list(
  st_read("dev/web_version/lisboa_rt/2026-02-04/prioritization_lisboa_rt_gtfs2026-02-04_run20260207_extended.gpkg"),
  st_read("dev/web_version/aml_rt/2026-02-04/prioritization_aml_rt_gtfs2026-02-04_run20260210_extended.gpkg")
)


all_data <- bind_rows(prioritizations)

aggregated <- all_data %>%
  group_by(way_osm_id, hour) %>%
  summarise(
    geom = first(geom),
    is_bus_lane = any(is_bus_lane, na.rm = TRUE),
    n_lanes = max(n_lanes, na.rm = TRUE),
    n_directions = max(n_directions, na.rm = TRUE),
    n_lanes_direction = max(n_lanes_direction, na.rm = TRUE),
    
    routes = paste(na.omit(routes), collapse = ";"),
    frequency = sum(frequency, na.rm = TRUE),
    
    speed_count = sum(speed_count, na.rm = TRUE),
    
    speed_avg = if (sum(speed_count, na.rm = TRUE) > 0) {
      sum(speed_avg * speed_count, na.rm = TRUE) /
        sum(speed_count, na.rm = TRUE)
    } else {
      NA_real_
    },
    .groups = "drop"
  )

View(aggregated |> st_drop_geometry())

names(aggregated)


# Get n_lanes, n_directions and n_lanes_direction from merge with the original data
aggregated_complete = aggregated |> 
  left_join(
    all_data |> st_drop_geometry() |> select(way_osm_id, n_lanes, n_directions, n_lanes_direction, is_bus_lane), 
    by = "way_osm_id",
    multiple="first"
  )
    
# Add GTFS data
# Replace route_id with route names, considering that prioritization$routes has multiple route_ids separated by ";"
gtfs_aml = tidytransit::read_gtfs("dev/web_version/AML.zip")
gtfs_lisboa = tidytransit::read_gtfs("dev/web_version/Lisboa.zip")
route_names_aml = gtfs_aml$routes[, c("route_id", "route_short_name", "route_long_name")]
route_names_lisboa = gtfs_lisboa$routes[, c("route_id", "route_short_name", "route_long_name")]
route_names = bind_rows(route_names_aml, route_names_lisboa) |> distinct()

prioritization = aggregated_complete
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
View(prioritization|>st_drop_geometry())

st_write(prioritization, "dev/web_version/unified_rt/prioritization_aml_lisboa_rt_gtfs2026-02-04_run20260210_extended.gpkg", delete_dsn = TRUE)
geojson_file = "dev/web_version/unified_rt/prioritization_aml_lisboa_rt_gtfs2026-02-04_run20260210_extended.geojson"
st_write(prioritization, geojson_file, append=FALSE, delete_dsn = TRUE)

# Open geojson with jsonlite, to extend with technical metadata
geojson_data = jsonlite::read_json(geojson_file, digits=NA) # To avoid precision loss in coordinates

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

rt_list = list(
  url = "", # To be edited manually
  period = "02-06/02/2026 (Carris), 13-19/01/2025 (Carris Metropolitana)",
  stop_buffer_size = 15
)

census_frequency_hour = list()
for(h in 0:23) {
  prioritization_hour = prioritization |> filter(hour == h)
  census_frequency_hour[[as.character(h)]] = dataCensus(prioritization_hour$frequency)
}

metadata = list(
  region = "Lisboa Metro Area, Portugal",
  gtfs = list(
    date = "2026-02-04",
    url = "#"
  ),
  osm_query = list(
    list(
      key = "route",
      value = "bus",
      key_exact = TRUE
    ),
    list(
      key = "network",
      value = list("Carris", "Carris Metropolitana"),
      key_exact = TRUE
    )
  ),
  prioritization = list(
    routes_missing = "52E;18E;54E;28E;12E;24E;15E;25E;51E;53E;1109;1110;1125;1219;1253;1504;1622;1624;1717;1998;1999;2021;2040;2104;2105;2106;2107;2117;2123;2124;2125;2134;2143;2145;2149;2150;2212;2315;2501;2625;2627;2650;2651;2652;2653;2711;2713;2722;2736;2745;2750;2752;2753;2755;2756;2758;2765;2782;2785;2797;2821;2850;2901;2907;2912;2913;2914;3220;3223;3513;3519;3520;3522;3542;3543;3640;3650;4303;4408;4418;4464;4470;4471;4605",
    routes_covered = 791 + 151,
    routes_total = 947 + 175
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


library(mapview)
aml = sf::st_read("https://github.com/U-Shift/MQAT/raw/refs/heads/main/geo/MUNICIPIOSgeo.gpkg", quiet = TRUE)

concelho = aml |> filter(Concelho == "Seixal") |> st_bbox()
# mapview(seixal)

prioritization_0800 = prioritization |> filter(hour==8) |> st_crop(concelho)
p50_frequency = quantile(prioritization_0800$frequency, 0.75, na.rm=TRUE)
p50_speed = quantile(prioritization_0800$speed_avg, 0.75, na.rm=TRUE)

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
  # Filter inside bbox seixal
  prioritizations[[2]] |> filter(hour==8) |> st_crop(seixal),
  zcol = "speed_avg",
  layer.name = "Average speed per lane",
  maxfeatures = nrow(prioritizations[[2]])
)




