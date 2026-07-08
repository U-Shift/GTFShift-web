# Initialization -------------------------------------------------------
output <- "web_data"
stop_buffer_size <- 15 # meters
GTFShiftVersion <- "0.10 (dev version)" # as.character(packageVersion("GTFShift"))

# GTFS-RT commercial speed computation parameters
THRESHOLD_MIN_UPDATES_PER_ROAD_SEGMENT_FOR_SPEED = 3  # number of updates per road segment to compute speed
THRESHOLD_TIME_BETWEEN_UPDATES_MAX = 90 # seconds, maximum time between updates to consider them valid for speed computation
THRESHOLD_UPDATES_PER_TRIP_MIN_MARGIN = 0.7 # minimum ratio of updates per trip (against planned updates) to consider the trip valid for speed computation 
THRESHOLD_DISTANCE_TO_GEOMETRY_MAX = 100 # meters, maximum distance to closest shape point to consider the update valid for speed computation

# Define regions to analyse
regions <- data.frame(
  name = character(),
  name_long = character(),
  gtfs = character(),
  query = I(list()),
  rt_interval = character(),
  rt_collection = I(list()),
  rt_collection_manipulate = I(list())
)
data <- read.csv(system.file("extdata", "gtfs_sources_pt.csv", package = "GTFShift"))


# Lisbon Metro Area -------------------------------------------------------
## Carris, Lisboa -----------------------------------
regions <- bind_rows(
  regions,
  data.frame(
    name = "lisboa_rt",
    name_long = "Lisboa, Portugal",
    gtfs_url = "web_data/lisboa_rt/gtfs_20260520/run_20260520_082954/gtfs_lisboa_rt_2026-05-20.zip", # data[data$ID == "lisboa", ]$URL,
    gtfs_day = "2026-05-20", # as.character(GTFShift::calendar_nextBusinessWednesday()),
    gtfs_manipulate = "manipulate_carris_lx",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Carris", key_exact = TRUE)
    ))),
    metric_crs = 3763,
    rt_interval = "13-30/04/2026 (Business Days)",
    rt_collection = I(list(as.character(list.files(
      "data/cm_20260413_220260430_business/processing_speed_shape_distance_osm_thresholds_circular_fix",
      pattern = "^updates_with_speed_.*\\.csv$",
      full.names = TRUE
    )))),
    rt_collection_manipulate = I(list(function(df, gtfs_trip_duration) {
      # Remove trips from trams, ascensors (end with "E") and neighbourhood buses (end with "B")
      message("Filtering out tram and neighbourhood bus trips from GTFS trip duration data...")
      gtfs_trip_duration <- gtfs_trip_duration |> filter(!stringr::str_detect(route_short_name, "E$|B$"))
      message(sprintf("> Manipulating RT collection, with %d records", nrow(df)))
      # Remove column closest_on_shape, if exists
      df <- df |> select(-any_of("closest_on_shape"))
      # 1st validation: time between and distance to geometry
      message(sprintf("> Validating updates, with %d records", nrow(df)))
      message("> 1st validation: time between updates and distance to geometry")
      df = df |>
        mutate(
          valid_time = ifelse(time_since_prev_sec < THRESHOLD_TIME_BETWEEN_UPDATES_MAX, TRUE, FALSE),
          valid_distance_to_geometry = ifelse(!is.na(distance_to_closest_on_geometry) & distance_to_closest_on_geometry <= THRESHOLD_DISTANCE_TO_GEOMETRY_MAX, TRUE, FALSE),
          valid_trip = valid_time & valid_distance_to_geometry
        )
      message(sprintf("> After 1st validation, %d (%.2f%%) records are valid for speed computation", nrow(df |> filter(valid_trip)), nrow(df |> filter(valid_trip)) / nrow(df) * 100))
      message(sprintf("> %d (%.2f%%) records are invalid due to time between updates > %d seconds", nrow(df |> filter(!valid_time)), nrow(df |> filter(!valid_time)) / nrow(df) * 100, THRESHOLD_TIME_BETWEEN_UPDATES_MAX))
      message(sprintf("> %d (%.2f%%) records are invalid due to distance to geometry > %d meters", nrow(df |> filter(!valid_distance_to_geometry)), nrow(df |> filter(!valid_distance_to_geometry)) / nrow(df) * 100, THRESHOLD_DISTANCE_TO_GEOMETRY_MAX))
      # 2nd validation: valid updates ratio
      message("> 2nd validation: valid updates ratio per trip")
      trips_per_day = df |> 
        filter(valid_trip) |>
        group_by(trip_id, day) |> 
        summarise(updates_count = n(), .groups = "drop") |>
        left_join(
          gtfs_trip_duration |> select(trip_id, trip_duration),
          by = c("trip_id" = "trip_id"), multiple="first"
        ) |>
        mutate(
          planned_updates_count = round(trip_duration / THRESHOLD_TIME_BETWEEN_UPDATES_MAX), 
          updates_ratio = updates_count / planned_updates_count
        )
      message(sprintf("> Found %d valid trips", nrow(trips_per_day)))
      n_at_least_ratio <- nrow(trips_per_day |> filter(updates_ratio >= THRESHOLD_UPDATES_PER_TRIP_MIN_MARGIN))
      message(sprintf("> %d (%.2f%%) have at least %.2f%% of updates ratio (updates_count / planned_updates_count)", n_at_least_ratio, n_at_least_ratio / nrow(trips_per_day) * 100, THRESHOLD_UPDATES_PER_TRIP_MIN_MARGIN * 100))
      df = df |>
        left_join(
          trips_per_day |> select(trip_id, day, updates_count, planned_updates_count, updates_ratio),
          by = c("trip_id" = "trip_id", "day" = "day")
        ) |>
        mutate(
          valid_updates_ratio = ifelse(updates_ratio >= THRESHOLD_UPDATES_PER_TRIP_MIN_MARGIN, TRUE, FALSE),
          valid_trip = valid_time & valid_distance_to_geometry & valid_updates_ratio
        )
      message(sprintf("> After 2nd validation, %d (%.2f%%) records are valid for speed computation", nrow(df |> filter(valid_trip)), nrow(df |> filter(valid_trip)) / nrow(df) * 100))
      message(sprintf("> %d (%.2f%%) records do not have a GTFS match (no planned_updates_count)", nrow(df |> filter(is.na(planned_updates_count))), nrow(df |> filter(is.na(planned_updates_count))) / nrow(df) * 100))
      message(sprintf("> %d (%.2f%%) records are invalid due to updates_ratio < %.2f%%", nrow(df |> filter(!valid_updates_ratio)), nrow(df |> filter(!valid_updates_ratio)) / nrow(df) * 100, THRESHOLD_UPDATES_PER_TRIP_MIN_MARGIN * 100))
      return(
        df |>
          filter(valid_trip) |>
          mutate(
            speed = as.numeric(speed_kmh),
            # Extract HH from epoch, in local time (Europe/Lisbon)
            # For instance, 1778737681, which is 2026-05-14 05:48:01 UTC, should return 6, as in 06:48:01 in Europe/Lisbon timezone
            hh = as.integer(format(as.POSIXct(timestamp, origin = "1970-01-01", tz = "Europe/Lisbon"), "%H"))
          ) |>
          st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
      )
    })),
    rt_collection_per_hour = TRUE,
    rt_notes = "Due to the fact that Carris GTFS-RT does not disclose vehicles' momentary speed, a proxy was computed for each trip update considering the time and route distance between each update and the previous one. Refer to the <a href=\"https://github.com/U-Shift/GTFShift-web/blob/dev/scripts/00_fetch_rt/4_compute_speed/gtfs_rt_commercial_speed.R\" target=\"_blank\">script</a> for more details.",
    geofabrik_region = "europe/portugal"
  )
)

## Carris Metropolitana -----------------------------------
regions <- bind_rows(
  regions,
  data.frame(
    name = "aml_rt",
    name_long = "Lisboa Metro Area, Portugal",
    gtfs_url = data[data$ID == "AML", ]$URL,
    gtfs_day = as.character(GTFShift::calendar_nextBusinessWednesday()),
    gtfs_manipulate = "manipulate_carris_met",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Carris Metropolitana", key_exact = TRUE)
    ))),
    rt_interval = "13-30/04/2026 (Business Days)",
    rt_collection = I(list("data/cmet_20260413_220260430_business/updates.csv")),
    rt_collection_manipulate = I(list(function(df) {
      df |>
        mutate(
          speed = as.numeric(speed)
        ) |>
        st_as_sf(coords = c("lon", "lat"), crs = 4326)
    })),
    geofabrik_region = "europe/portugal"
  )
)

### Area 1 -----------------------------------
regions <- bind_rows(
  regions,
  data.frame(
    name = "aml_rt_area_1",
    name_long = "Lisboa Metro Area, Portugal (Area 1)",
    gtfs_url = data[data$ID == "AML", ]$URL,
    gtfs_day = as.character(GTFShift::calendar_nextBusinessWednesday()),
    gtfs_manipulate = "manipulate_carris_met_area_1",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Carris Metropolitana", key_exact = TRUE)
    ))),
    rt_interval = "13-30/04/2026 (Business Days)",
    rt_collection = I(list("data/cmet_20260413_220260430_business_a1/updates.csv")),
    rt_collection_manipulate = I(list(function(df) {
      df |>
        mutate(
          speed = as.numeric(speed)
        ) |>
        st_as_sf(coords = c("lon", "lat"), crs = 4326)
    })),
    geofabrik_region = "europe/portugal"
  )
)

### Area 2 -----------------------------------
regions <- bind_rows(
  regions,
  data.frame(
    name = "aml_rt_area_2",
    name_long = "Lisboa Metro Area, Portugal (Area 2)",
    gtfs_url = data[data$ID == "AML", ]$URL,
    gtfs_day = as.character(GTFShift::calendar_nextBusinessWednesday()),
    gtfs_manipulate = "manipulate_carris_met_area_2",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Carris Metropolitana", key_exact = TRUE)
    ))),
    rt_interval = "13-30/04/2026 (Business Days)",
    rt_collection = I(list("data/cmet_20260413_220260430_business_a2/updates.csv")),
    rt_collection_manipulate = I(list(function(df) {
      df |>
        mutate(
          speed = as.numeric(speed)
        ) |>
        st_as_sf(coords = c("lon", "lat"), crs = 4326)
    })),
    geofabrik_region = "europe/portugal"
  )
)

### Area 3 -----------------------------------
regions <- bind_rows(
  regions,
  data.frame(
    name = "aml_rt_area_3",
    name_long = "Lisboa Metro Area, Portugal (Area 3)",
    gtfs_url = "web_data/aml_rt_area_3/gtfs_20260520/run_20260518_203125/gtfs_aml_rt_area_3_2026-05-20.zip", # data[data$ID == "AML", ]$URL,
    gtfs_day = "2026-05-20", # as.character(GTFShift::calendar_nextBusinessWednesday()),
    gtfs_manipulate = "manipulate_carris_met_area_3",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Carris Metropolitana", key_exact = TRUE)
    ))),
    rt_interval = "13-30/04/2026 (Business Days)",
    # rt_collection = I(list("data/cmet_20260413_220260430_business_a3/updates_instantSpeeds.csv")),
    # rt_collection_manipulate = I(list(function(df) {
    #  df |>
    #    filter(current_status == "IN_TRANSIT_TO") |>
    #    mutate(
    #      speed = as.numeric(speed)
    #    ) |>
    #    st_as_sf(coords = c("lon", "lat"), crs = 4326)
    # })),
    rt_collection = I(list(as.character(list.files(
      "data/cmet_20260413_220260430_business_a3",
      pattern = "^updates_with_speed_.*\\.csv$",
      full.names = TRUE
    )))),
    rt_collection_manipulate = I(list(function(df) {
      df |>
        mutate(
          speed = as.numeric(euclidean_speed_kmh)
        ) |>
        st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
    })),
    demand_for_route = I(list("data/demand/cm_demand_20260520.csv")),
    demand_notes = "Demand by route, for same representative day as transit services analysed. Segment aggregation considers the sum of all passengers that board each route that passes through the segment for that day, regardless of the direction of travel or stop they boarded or alighted.",
    geofabrik_region = "europe/portugal",
    metric_crs = 3763
  )
)

### Area 4 -----------------------------------
regions <- bind_rows(
  regions,
  data.frame(
    name = "aml_rt_area_4",
    name_long = "Lisboa Metro Area, Portugal (Area 4)",
    gtfs_url = data[data$ID == "AML", ]$URL,
    gtfs_day = as.character(GTFShift::calendar_nextBusinessWednesday()),
    gtfs_manipulate = "manipulate_carris_met_area_4",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Carris Metropolitana", key_exact = TRUE)
    ))),
    rt_interval = "13-30/04/2026 (Business Days)",
    rt_collection = I(list("data/cmet_20260413_220260430_business_a4/updates.csv")),
    rt_collection_manipulate = I(list(function(df) {
      df |>
        mutate(
          speed = as.numeric(speed)
        ) |>
        st_as_sf(coords = c("lon", "lat"), crs = 4326)
    })),
    geofabrik_region = "europe/portugal"
  )
)

## MobiCascais, Cascais -----------------------------------
regions <- bind_rows(
  regions,
  data.frame(
    name = "cascais",
    name_long = "Cascais, Portugal",
    gtfs_url = "https://drive.google.com/uc?export=download&id=13ucYiAJRtu-gXsLa02qKJrGOgDjbnUWX",
    gtfs_day = as.character(GTFShift::calendar_nextBusinessWednesday()),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "MobiCascais", key_exact = TRUE)
    ))),
    geofabrik_region = "europe/portugal"
  )
)

## TCB, Barreiro -----------------------------------
regions <- bind_rows(
  regions,
  data.frame(
    name = "barreiro",
    name_long = "Barreiro, Portugal",
    # gtfs_url = data$URL[data$ID == "barreiro"],
    gtfs_url = "web_data/barreiro/gtfs_20260520/run_20260519_110700/gtfs_barreiro_2026-05-20.zip",
    # gtfs_day = as.character(GTFShift::calendar_nextBusinessWednesday()),
    gtfs_day = "2026-05-20",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = c("TCB", "Transportes Coletivos do Barreiro", "Transportes Colectivos do Barreiro"), key_exact = TRUE)
    ))),
    rt_interval = "11-15/05/2026",
    rt_collection = I(list(as.character(list.files(
      "data/barreiro_20260511_20260515",
      pattern = "^updates_with_speed_.*\\.csv$",
      full.names = TRUE
    )))),
    rt_collection_manipulate = I(list(function(df) {
      df |>
        mutate(
          speed = as.numeric(euclidean_speed_kmh),
          # Extract HH from epoch, in local time (Europe/Lisbon)
          # For instance, 1778737681, which is 2026-05-14 05:48:01 UTC, should return 6, as in 06:48:01 in Europe/Lisbon timezone
          hh = as.integer(format(as.POSIXct(timestamp, origin = "1970-01-01", tz = "Europe/Lisbon"), "%H"))
        ) |>
        st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
    })),
    rt_collection_per_hour = TRUE,
    rt_notes = "Due to the fact that TCB GTFS-RT does not disclose vehicles' momentary speed, a proxy was computed for each TripUpdate considering the time and euclidean distance between each update and the previous one. Refer to the <a href=\"https://github.com/U-Shift/GTFShift-web/blob/main/scripts/00_fetch_rt/gtfs_rt_gather_TCBarreiro.Rmd\" target=\"_blank\">script</a> for more details.",
    geofabrik_region = "europe/portugal",
    metric_crs = 3763
  )
)

# Portugal, Others -----------------------------------
## STCP, Porto -----------------------------------
regions <- bind_rows(
  regions,
  data.frame(
    name = "stcp",
    name_long = "Porto, Portugal",
    # gtfs_url = "https://api.stcp.pt:8443/v1/ficheiros/estatico/ficheirozip",
    # gtfs_url_headers = I(list(list(
    #  "X-App-Id" = Sys.getenv("GTFS_STCP_KEY"),
    #  "X-Api-Key" = Sys.getenv("GTFS_STCP_SECRET")
    # ))),
    # gtfs_day = as.character(GTFShift::calendar_nextBusinessWednesday()),
    gtfs_url = "web_data/stcp/gtfs_20260520/run_20260519_073433/gtfs_stcp_2026-05-20.zip",
    gtfs_day = "2026-05-20",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "STCP", key_exact = TRUE)
    ))),
    rt_interval = "13-30/04/2026 (Business Days)",
    rt_collection = I(list(as.character(list.files(
      "data/stcp_20260413_220260430_business",
      pattern = "^updates_with_speed_.*\\.csv$",
      full.names = TRUE
    )))),
    rt_collection_manipulate = I(list(function(df) {
      df |>
        mutate(
          speed = as.numeric(euclidean_speed_kmh)
        ) |>
        st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
    })),
    geofabrik_region = "europe/portugal",
    metric_crs = 3763
  )
)

# International -----------------------------------
## MTA, NYC, USA -----------------------------------
regions <- bind_rows(
  regions,
  data.frame(
    name = "nyc_mta",
    gtfs_url = "https://rrgtfsfeeds.s3.amazonaws.com/gtfs_busco.zip",
    gtfs_day = as.character(Sys.Date()),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "Metropolitan Transportation Authority", key_exact = TRUE)
    )))
  )
)

## Guelph, CANADA -----------------------------------
regions <- bind_rows(
  regions,
  data.frame(
    name = "guelph",
    name_long = "Guelph, CA",
    gtfs_url = "https://gismaps.guelph.ca/Pages/GTFS/google_transit.zip",
    gtfs_day = "2026-04-29",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Guelph Transit", key_exact = TRUE)
    ))),
    geofabrik_region = "north-america/canada/ontario"
  )
)

## EMT, Madrid, SPAIN -----------------------------------
regions <- bind_rows(
  regions,
  data.frame(
    name = "madrid",
    name_long = "Madrid, ES",
    gtfs_url = "https://servicios.emtmadrid.es:8443/gtfs/transitemt.zip",
    gtfs_day = as.character(GTFShift::calendar_nextBusinessWednesday()),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "Empresa Municipal de Transportes de Madrid", key_exact = TRUE)
    ))),
    geofabrik_region = "europe/spain/madrid"
  )
)

## Fuenlabrada, SPAIN -----------------------------------
regions <- bind_rows(
  regions,
  data.frame(
    name = "fuenlabrada",
    name_long = "Fuenlabrada, ES",
    gtfs_url = "https://api.control.optibus.co/opendata/v1/gtfs?uid=c-5cfcd2d1",
    gtfs_day = as.character(GTFShift::calendar_nextBusinessWednesday()),
    gtfs_manipulate = "manipulate_gtfs_fuenlabrada",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "EMT Fuenlabrada", key_exact = TRUE)
    ))),
    geofabrik_region = "europe/spain/madrid"
  )
)

## Tisseo, Toulouse, FRANCE -----------------------------------
regions <- bind_rows(
  regions,
  data.frame(
    name = "toulouse",
    name_long = "Toulouse, FR",
    gtfs_url = "https://data.toulouse-metropole.fr/explore/dataset/tisseo-gtfs/files/fc1dda89077cf37e4f7521760e0ef4e9/download/",
    gtfs_day = as.character(GTFShift::calendar_nextBusinessWednesday()),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Tisséo", key_exact = TRUE)
    ))),
    geofabrik_region = "europe/france/midi-pyrenees"
  )
)

# Helpers -----------------------------------

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

manipulate_gtfs_fuenlabrada <- function(gtfs) {
  # Append "L" suffix to route_short_name
  gtfs$routes$route_short_name <- paste0("L", gtfs$routes$route_short_name)
  return(gtfs)
}
