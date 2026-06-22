library(GTFShift)
library(dplyr)
library(stringr)
library(mapview)
library(osmdata)

# Run with: $ Rscript 01_osm_match/osm_match.R

# get_overpass_url()
# set_overpass_url("https://maps.mail.ru/osm/tools/overpass/api/interpreter")
# set_overpass_url("https://overpass.private.coffee/api/interpreter") # 4 servers with 20 cores, 256GB RAM, SSD each
# set_overpass_url("https://overpass-api.de/api/interpreter")
# get_overpass_url()

# Refer to osm_match_parameters.R to define parameters before running this script!
output_root <- "osm_match"

# Define regions to analyse
regions <- data.frame(
  name = character(),
  gtfs_url = character(),
  query = I(list())
)
data <- read.csv(system.file("extdata", "gtfs_sources_pt.csv", package = "GTFShift"))

regions <- bind_rows( # Lisboa, Trams
  regions,
  data.frame(
    name = "lisboa",
    gtfs_url = "~/Downloads/gtfs_2026-06-18(1).zip",
    gtfs_day = GTFShift::calendar_nextBusinessWednesday(),
    gtfs_day_filter = TRUE,
    query = I(list(list(
      list(key = "route", value = c("tram"), key_exact = TRUE),
      list(key = "network", value = "Carris", key_exact = TRUE)
    ))),
    geofabrik_region = "europe/portugal",
    osm_stop_order_relaxed = TRUE,
    osm_route_type = "tram",
    gtfs_manipulate = "manipulate_carris_trams"
  )
)
regions <- bind_rows( # Lisboa, Funiculars
  regions,
  data.frame(
    name = "lisboa",
    gtfs_url = "~/Downloads/gtfs_2026-06-18(1).zip",
    gtfs_day = GTFShift::calendar_nextBusinessWednesday(),
    gtfs_day_filter = TRUE,
    query = I(list(list(
      list(key = "route", value = c("funicular"), key_exact = TRUE),
      list(key = "network", value = "Carris", key_exact = TRUE)
    ))),
    geofabrik_region = "europe/portugal",
    osm_stop_order_relaxed = TRUE,
    osm_route_type = "funicular",
    gtfs_manipulate = "manipulate_carris_funiculars"
  )
)

manipulate_carris_trams <- function(gtfs) {
  # Filter tram routes (route_short_name contains "E")
  routes_bus <- gtfs$routes |>
    filter(
      stringr::str_detect(route_short_name, "E") &
      # Does not start with 5
      !stringr::str_detect(route_short_name, "^5")
    )
  trips_routes_bus <- gtfs$trips |>
    filter(route_id %in% routes_bus$route_id)
  gtfs <- tidytransit::filter_feed_by_trips(gtfs, trips_routes_bus$trip_id)

  return(gtfs)
}
manipulate_carris_funiculars <- function(gtfs) {
  # Filter funicular routes (route_short_name starts with "5")
  routes_filter <- gtfs$routes |>
    filter(
      # Starts with 5
      stringr::str_detect(route_short_name, "^5")
    )
  trips_routes_filter <- gtfs$trips |>
    filter(route_id %in% routes_filter$route_id)
  gtfs <- tidytransit::filter_feed_by_trips(gtfs, trips_routes_filter$trip_id)

  return(gtfs)
}

regions <- bind_rows( # CP Portugal
  regions,
  data.frame(
    name = "cp_pt",
    gtfs_url = "https://publico.cp.pt/gtfs/gtfs.zip",
    gtfs_day = GTFShift::calendar_nextBusinessWednesday(),
    gtfs_day_filter = TRUE,
    query = I(list(list(
      list(key = "route", value = c("train"), key_exact = TRUE),
      list(key = "operator", value = "Comboios de Portugal", key_exact = TRUE)
    ))),
    gtfs_match = "route_short_name",
    osm_match = "name",
    gtfs_manipulate = "manipulate_gtfs_cp",
    gtfs_osm_match_exact = FALSE,
    geofabrik_region = "europe/portugal"
  )
)
regions <- bind_rows( # CP Lisboa
  regions,
  data.frame(
    name = "cp_lisboa",
    gtfs_url = "https://publico.cp.pt/gtfs/gtfs.zip",
    gtfs_day = GTFShift::calendar_nextBusinessWednesday(),
    gtfs_day_filter = TRUE,
    query = I(list(list(
      list(key = "route", value = c("train"), key_exact = TRUE),
      list(key = "operator", value = "Comboios de Portugal", key_exact = TRUE)
    ))),
    gtfs_match = "route_short_name",
    osm_match = "name",
    gtfs_manipulate = "manipulate_gtfs_cp_lisbon",
    gtfs_osm_match_exact = FALSE,
    geofabrik_region = "europe/portugal"
  )
)
manipulate_gtfs_cp <- function(gtfs) {
  # Method to manipulate GTFS routes names, to enable match with OSM names
  # See https://github.com/U-Shift/GTFShift/issues/35 for more details

  # String replace service acronym in gtfs$routes$route_short_name by extended name
  # Example: "AP" by "Alfa Pendular",  "IC" by "Intercidades"
  gtfs$routes$route_short_name <- gsub("AP", "Alfa Pendular", gtfs$routes$route_short_name)
  gtfs$routes$route_short_name <- gsub("IC", "Intercidades", gtfs$routes$route_short_name)
  gtfs$routes$route_short_name <- gsub("IR", "InterR", gtfs$routes$route_short_name)
  gtfs$routes$route_short_name <- gsub("R", "Regional", gtfs$routes$route_short_name)
  gtfs$routes$route_short_name <- gsub("U", "Urbano", gtfs$routes$route_short_name)

  # Extend gtfs$routes$route_short_name with origin/destination station names
  gtfs$routes <- gtfs$routes |>
    mutate(
      from = str_split_fixed(route_id, "-", 3)[, 2],
      to = str_split_fixed(route_id, "-", 3)[, 3]
    ) |>
    left_join(gtfs$stops |> select(stop_id, stop_name) |> rename(from_name = stop_name), by = c("from" = "stop_id")) |>
    left_join(gtfs$stops |> select(stop_id, stop_name) |> rename(to_name = stop_name), by = c("to" = "stop_id")) |>
    mutate(route_short_name = sprintf("%s %s %s", route_short_name, from_name, to_name))

  return(gtfs)
}
manipulate_gtfs_cp_lisbon <- function(gtfs) {
  gtfs <- manipulate_gtfs_cp(gtfs)
  stations_lisbon_u = c(
    "94_61101", # Sintra
    "94_62042", # Meleças
    "94_59006", # Rossio
    "94_31039", # Lisboa Oriente
    "94_33001", # Azambuja
    "94_30007", # Lisboa SA
    "94_31310", # Castanheira Ribatejo
    "94_67025", # Alcântara-terra
    "94_69260", # Cascais
    "94_69179", # Oeiras
    "94_69005", # Cais do Sodré
    "94_95000", # Barreiro
    "94_91058" # Praias do Sado A
  )
  stations_lisbon_r = c(
    "94_40154" # Tomar
  )
  routes_lisbon = gtfs$routes %>%
    filter(
      grepl(paste(stations_lisbon_u, collapse = "|"), route_id) & (route_short_name == "U" | grepl("^Linha", route_short_name))
      | grepl(paste(stations_lisbon_r, collapse = "|"), route_id) & (route_short_name %in% c("R", "IR"))
    )
  trips_lisbon = gtfs$trips %>%
    filter(route_id %in% routes_lisbon$route_id)
  gtfs = tidytransit::filter_feed_by_trips(gtfs, trip_ids = trips_lisbon$trip_id) 

  return(gtfs)
}

# main()
for (i in 1:nrow(regions)) {
  region <- regions[i, ]
  output_region <- sprintf("%s/%s/gtfs_%s", output_root, tolower(region$name), gsub("-", "", region$gtfs_day))
  output <- sprintf("%s/run_%s", output_region, format(Sys.time(), "%Y%m%d_%H%M%S"))
  if (!dir.exists(output)) {
    dir.create(output, recursive = TRUE)
  }
  message(sprintf("\n\nRunning for %s (%s)...", region$name, region$gtfs_day))

  gtfs_file <- sprintf("%s/gtfs_%s_%s.zip", output_region, region$name, region$gtfs_day)
  if (file.exists(gtfs_file)) {
    message("Loading gtfs from file...")
    gtfs <- GTFShift::load_feed(gtfs_file, create_transfers = FALSE)
  } else {
    message("Downloading gtfs...")
    gtfs <- GTFShift::load_feed(region$gtfs_url, headers = if (!is.null(region$gtfs_url_headers)) unlist(region$gtfs_url_headers[[1]]) else NULL, create_transfers = FALSE)
    tidytransit::write_gtfs(gtfs, gtfs_file)
  }
  summary(gtfs)
  # assign(sprintf("gtfs_%s_%s", region$name, region$gtfs_day), gtfs)

  if (!is.null(region$gtfs_manipulate) && !is.na(region$gtfs_manipulate) || !is.na(region$gtfs_day_filter) && !is.null(region$gtfs_day_filter)) {
    if (!is.na(region$gtfs_day_filter) && !is.null(region$gtfs_day_filter)) {
      message(sprintf("Filter gtfs for %s...", region$gtfs_day))
      gtfs = tidytransit::filter_feed_by_date(gtfs, extract_date = region$gtfs_day)
    } 
    if (!is.null(region$gtfs_manipulate) && !is.na(region$gtfs_manipulate)) {
      message("Manipulating gtfs...")
      gtfs <- get(region$gtfs_manipulate)(gtfs)
    }
    gtfs_file_manipulated <- sprintf("%s/gtfs_%s_%s_manipulated.zip", output_region, region$name, region$gtfs_day)
    if (!file.exists(gtfs_file_manipulated)) {
      tidytransit::write_gtfs(gtfs, gtfs_file_manipulated)
    }
  }

  gtfs_shapes <- tidytransit::shapes_as_sf(gtfs$shapes)
  bbox <- sf::st_bbox(gtfs_shapes)

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

  # Get OSM extract to avoid API call
  # Increase timeout 
  options(timeout=1000)
  # osmextract::oe_download_directory()
  if (is.null(region$geofabrik_region)) {
    stop("Please define the geofabrik_region for this region in osm_match_parameters.R")
  }
  osm_file <- osmextract::oe_download(
    sprintf("https://download.geofabrik.de/%s-latest.osm.pbf", region$geofabrik_region),
    file_basename = sprintf("%s_%s.osm.pbf", str_replace_all(region$geofabrik_region, "/", "_"), format(Sys.Date(), "%Y%m%d"))
  )

  # Match shapes geometry
  message("Matching shapes...")
  shapes_match_routes <- GTFShift::osm_shapes_match_routes(
    gtfs, q,
    gtfs_match = if (!is.null(region$gtfs_match)) region$gtfs_match else "route_short_name",
    osm_match = if (!is.null(region$osm_match)) region$osm_match else "ref",
    gtfs_osm_match_exact = if (!is.null(region$gtfs_osm_match_exact)) region$gtfs_osm_match_exact else TRUE,
    log_file = sprintf("%s/shapes_match_%s_gtfs%s_run%s.r.log", output, region$name, region$gtfs_day, gsub("-", "", Sys.Date())),
    osm_file = osm_file,
    num_cores = max(1, floor(parallel::detectCores() / 2)),
    osm_stop_order_relaxed = if (!is.null(region$osm_stop_order_relaxed)) region$osm_stop_order_relaxed else FALSE,
    osm_route_type = if (!is.null(region$osm_route_type)) region$osm_route_type else "bus"
  )
  # assign(sprintf("shapes_match_routes_%s_gtfs%s", region$name, region$gtfs_day), shapes_match_routes)

  write.csv(shapes_match_routes |> sf::st_drop_geometry() |> mutate(
    distance_diff = round(distance_diff),
    points_diff = round(points_diff)
  ), sprintf("%s/shapes_match_%s_gtfs%s_run%s.csv", output, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), row.names = FALSE)
  sf::st_write(shapes_match_routes, sprintf("%s/shapes_match_%s_gtfs%s_run%s.gpkg", output, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), append = FALSE)
  message("Done! :)")
}
