# Parameters
output <- "web_data"

regions <- data.frame(
  name = character(),
  name_long = character(),
  gtfs = character(),
  query = I(list()),
  rt_interval = character(),
  rt_collection = I(list()) # sf object
)
data <- read.csv(system.file("extdata", "gtfs_sources_pt.csv", package = "GTFShift"))

regions <- rbind( # Lisboa
  regions,
  data.frame(
    name = "lisboa_rt",
    name_long = "Lisboa, Portugal",
    gtfs_url = data[data$ID == "lisboa", ]$URL,
    gtfs_day = GTFShift::calendar_nextBusinessWednesday(),
    gtfs_manipulate = "manipulate_carris_lx",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Carris", key_exact = TRUE)
    ))),
    rt_interval = "13-30/04/2026 (Business Days)",
    rt_collection = I(list(sf::st_read("data/cm_20260413_220260430_business/updates.csv") |>
      mutate(
        lon = stringr::str_replace(lon, "c\\(", ""),
        lat = stringr::str_replace(lat, "\\)", ""),
        speed = as.numeric(speed)
      ) |> st_as_sf(coords = c("lon", "lat"), crs = 4326))),
    geofabrik_region = "europe/portugal"
  )
)

regions <- rbind( # CarrisMetropolitana
  regions,
  data.frame(
    name = "aml_rt",
    name_long = "Lisboa Metro Area, Portugal",
    gtfs_url = data[data$ID == "AML", ]$URL,
    gtfs_day = GTFShift::calendar_nextBusinessWednesday(),
    gtfs_manipulate = "manipulate_carris_met",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Carris Metropolitana", key_exact = TRUE)
    ))),
    rt_interval = "13-30/04/2026 (Business Days)",
    rt_collection = I(list(sf::st_read("data/cmet_20260413_220260430_business/updates.csv") |>
      mutate(
        speed = as.numeric(speed)
      ) |> st_as_sf(coords = c("lon", "lat"), crs = 4326))),
    geofabrik_region = "europe/portugal"
  )
)
regions <- rbind( # CarrisMetropolitana, Area 1
  regions,
  data.frame(
    name = "aml_rt_area_1",
    name_long = "Lisboa Metro Area, Portugal (Area 1)",
    gtfs_url = data[data$ID == "AML", ]$URL,
    gtfs_day = GTFShift::calendar_nextBusinessWednesday(),
    gtfs_manipulate = "manipulate_carris_met_area_1",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Carris Metropolitana", key_exact = TRUE)
    ))),
    rt_interval = "13-30/04/2026 (Business Days)",
    rt_collection = I(list(sf::st_read("data/cmet_20260413_220260430_business_a1/updates.csv") |>
      mutate(
        speed = as.numeric(speed)
      ) |> st_as_sf(coords = c("lon", "lat"), crs = 4326))),
    geofabrik_region = "europe/portugal"
  )
)

regions <- rbind( # CarrisMetropolitana, Area 2
  regions,
  data.frame(
    name = "aml_rt_area_2",
    name_long = "Lisboa Metro Area, Portugal (Area 2)",
    gtfs_url = data[data$ID == "AML", ]$URL,
    gtfs_day = GTFShift::calendar_nextBusinessWednesday(),
    gtfs_manipulate = "manipulate_carris_met_area_2",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Carris Metropolitana", key_exact = TRUE)
    ))),
    rt_interval = "13-30/04/2026 (Business Days)",
    rt_collection = I(list(sf::st_read("data/cmet_20260413_220260430_business_a2/updates.csv") |>
      mutate(
        speed = as.numeric(speed)
      ) |> st_as_sf(coords = c("lon", "lat"), crs = 4326))),
    geofabrik_region = "europe/portugal"
  )
)

regions <- rbind( # CarrisMetropolitana, Area 3
  regions,
  data.frame(
    name = "aml_rt_area_3",
    name_long = "Lisboa Metro Area, Portugal (Area 3)",
    gtfs_url = data[data$ID == "AML", ]$URL,
    gtfs_day = GTFShift::calendar_nextBusinessWednesday(),
    gtfs_manipulate = "manipulate_carris_met_area_3",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Carris Metropolitana", key_exact = TRUE)
    ))),
    rt_interval = "13-30/04/2026 (Business Days)",
    rt_collection = I(list(sf::st_read("data/cmet_20260413_220260430_business_a3/updates.csv") |>
      mutate(
        speed = as.numeric(speed)
      ) |> st_as_sf(coords = c("lon", "lat"), crs = 4326))),
    geofabrik_region = "europe/portugal"
  )
)

regions <- rbind( # CarrisMetropolitana, Area 4
  regions,
  data.frame(
    name = "aml_rt_area_4",
    name_long = "Lisboa Metro Area, Portugal (Area 4)",
    gtfs_url = data[data$ID == "AML", ]$URL,
    gtfs_day = GTFShift::calendar_nextBusinessWednesday(),
    gtfs_manipulate = "manipulate_carris_met_area_4",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Carris Metropolitana", key_exact = TRUE)
    ))),
    rt_interval = "13-30/04/2026 (Business Days)",
    rt_collection = I(list(sf::st_read("data/cmet_20260413_220260430_business_a4/updates.csv") |>
      mutate(
        speed = as.numeric(speed)
      ) |> st_as_sf(coords = c("lon", "lat"), crs = 4326))),
    geofabrik_region = "europe/portugal"
  )
)


regions <- rbind( # Cascais
  regions,
  data.frame(
    name = "cascais",
    name_long = "Cascais, Portugal",
    gtfs_url = "https://drive.google.com/uc?export=download&id=13ucYiAJRtu-gXsLa02qKJrGOgDjbnUWX",
    gtfs_day = GTFShift::calendar_nextBusinessWednesday(),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "MobiCascais", key_exact = TRUE)
    ))),
    geofabrik_region = "europe/portugal"
  )
)


regions <- rbind( # Barreiro
  regions,
  data.frame(
    name = "barreiro",
    name_long = "Barreiro, Portugal",
    gtfs_url = data$URL[data$ID == "barreiro"],
    gtfs_day = GTFShift::calendar_nextBusinessWednesday(),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Transportes Coletivos do Barreiro", key_exact = TRUE)
    ))),
    geofabrik_region = "europe/portugal"
  )
)

regions <- rbind( # STCP
  regions,
  data.frame(
    name = "stcp",
    name_long = "Porto, Portugal",
    gtfs_url = "https://api.stcp.pt:8443/v1/ficheiros/estatico/ficheirozip",
    gtfs_url_headers = I(list(list(
      "X-App-Id" = Sys.getenv("GTFS_STCP_KEY"),
      "X-Api-Key" = Sys.getenv("GTFS_STCP_SECRET")
    ))),
    gtfs_day = GTFShift::calendar_nextBusinessWednesday(),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "STCP", key_exact = TRUE)
    ))),
    rt_interval = "13-30/04/2026 (Business Days)",
    rt_collection = I(list(sf::st_read("data/stcp_20260413_220260430_business/updates.csv") |>
      mutate(
        speed = as.numeric(speed)
      ) |> st_as_sf(coords = c("lon", "lat"), crs = 4326))),
    geofabrik_region = "europe/portugal"
  )
)

regions <- rbind( # NYC, MTA
  regions,
  data.frame(
    name = "nyc_mta",
    gtfs_url = "https://rrgtfsfeeds.s3.amazonaws.com/gtfs_busco.zip",
    gtfs_day = Sys.Date(),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "Metropolitan Transportation Authority", key_exact = TRUE)
    )))
  )
)

# Helpers

manipulate_carris_met <- function(gtfs) {
  # Remove all text from [ to ] from gtfs$shape_ids, which are present in Carris Metropolitana feed and cause issues in matching with OSM shapes
  gtfs$shapes$shape_id <- stringr::str_replace_all(gtfs$shapes$shape_id, "\\[.*\\]", "")
  gtfs$trips$shape_id <- stringr::str_replace_all(gtfs$trips$shape_id, "\\[.*\\]", "")

  return(gtfs)
}

manipulate_carris_met_area_1 <- function(gtfs) {
  gtfs <- manipulate_carris_met(gtfs)
  gtfs <- GTFShift::filter_by_agency(gtfs, id = 41)
  return(gtfs)
}

manipulate_carris_met_area_2 <- function(gtfs) {
  gtfs <- manipulate_carris_met(gtfs)
  gtfs <- GTFShift::filter_by_agency(gtfs, id = 42)
  return(gtfs)
}

manipulate_carris_met_area_3 <- function(gtfs) {
  gtfs <- manipulate_carris_met(gtfs)
  gtfs <- GTFShift::filter_by_agency(gtfs, id = 43)
  return(gtfs)
}

manipulate_carris_met_area_4 <- function(gtfs) {
  gtfs <- manipulate_carris_met(gtfs)
  gtfs <- GTFShift::filter_by_agency(gtfs, id = 44)
  return(gtfs)
}

manipulate_carris_lx <- function(gtfs) {
  colors <- read.csv("data_useful/carris_colors.csv")

  gtfs$routes <- gtfs$routes |>
    select(-c(route_color, route_text_color)) |>
    left_join(colors, by = "route_short_name")

  # Filter tram routes (route_short_name contains "E")
  routes_bus <- gtfs$routes |>
    filter(!stringr::str_detect(route_short_name, "E"))
  trips_routes_bus <- gtfs$trips |>
    filter(route_id %in% routes_bus$route_id)
  gtfs <- tidytransit::filter_feed_by_trips(gtfs, trips_routes_bus$trip_id)

  return(gtfs)
}
