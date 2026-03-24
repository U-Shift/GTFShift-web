
# Parameters
output_root = "osm_match"

regions = data.frame(
  name = character(),
  gtfs = character(),
  query = I(list())
)
data = read.csv(system.file("extdata", "gtfs_sources_pt.csv", package = "GTFShift"))

regions = rbind( # AML
  regions,
  data.frame(
    name = "AML",
    # For historical versions, refer to https://mobilitydatabase.org/feeds/gtfs/mdb-2027
    gtfs_url = "dev/web_version/AML.zip",
    gtfs_day = "2025-02-04",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Carris Metropolitana", key_exact = TRUE)
    )))
  )
)
regions = rbind( # Barreiro
  regions,
  data.frame(
    name = "barreiro",
    gtfs_url = data$URL[data$ID == "barreiro"],
    gtfs_day = gsub("-", "", Sys.Date()),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Transportes Coletivos do Barreiro", key_exact = TRUE)
    )))
  )
)
regions = rbind( # Braga
  regions,
  data.frame(
    name = "braga",
    gtfs_url = data$URL[data$ID == "braga"],
    gtfs_day = gsub("-", "", Sys.Date()),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "Transportes Urbanos de Braga", key_exact = TRUE)
    )))
  )
)
regions = rbind( # Cascais
  regions,
  data.frame(
    name = "cascais",
    gtfs_url = data$URL[data$ID == "cascais"],
    gtfs_day = gsub("-", "", Sys.Date()),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "MobiCascais", key_exact = TRUE)
    )))
  )
)
regions = rbind( # Funchal
  regions,
  data.frame(
    name = "funchal",
    gtfs_url = data$URL[data$ID == "funchal"],
    gtfs_day = gsub("-", "", Sys.Date()),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "HF", key_exact = TRUE)
    )))
  )
)
regions = rbind( # Lagos
  regions,
  data.frame(
    name = "lagos",
    gtfs_url = data$URL[data$ID == "lagos"],
    gtfs_day = gsub("-", "", Sys.Date()),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "ONDA", key_exact = TRUE)
    )))
  )
)
regions = rbind( # Lisboa
  regions,
  data.frame(
    name = "lisboa",
    gtfs_url = "dev/web_version/Lisboa.zip",
    gtfs_day = "2025-02-04",
    query = I(list(list(
      list(key = "route", value = c("bus", "tram"), key_exact = TRUE),
      list(key = "network", value = "Carris", key_exact = TRUE)
    )))
  )
)
regions = rbind( # Madrid
  regions,
  data.frame(
    name = "madrid",
    gtfs_url = data$URL[data$ID == "madrid"],
    gtfs_day = gsub("-", "", Sys.Date()),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "Empresa Municipal de Transportes de Madrid", key_exact = TRUE)
    )))
  )
)
regions = rbind( # STCP
  regions,
  data.frame(
    name = "stcp",
    gtfs_url = data$URL[data$ID == "stcp"],
    gtfs_day = gsub("-", "", Sys.Date()),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "STCP", key_exact = TRUE)
    )))
  )
)
regions = rbind( # Toulouse
  regions,
  data.frame(
    name = "toulouse",
    gtfs_url = "https://data.toulouse-metropole.fr/explore/dataset/tisseo-gtfs/files/fc1dda89077cf37e4f7521760e0ef4e9/download/",
    gtfs_day = gsub("-", "", Sys.Date()),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "Tisséo", key_exact = TRUE)
    )))
  )
)

regions = rbind( # CP Portugal
  regions,
  data.frame(
    name = "cp_pt",
    gtfs_url = "https://publico.cp.pt/gtfs/gtfs.zip",
    gtfs_day = gsub("-", "", Sys.Date()),
    query = I(list(list(
      list(key = "route", value = c("train"), key_exact = TRUE),
      list(key = "operator", value = "Comboios de Portugal", key_exact = TRUE)
    ))),
    gtfs_match = "route_short_name",
    osm_match = "name",
    gtfs_manipulate = "manipulate_gtfs_cp",
    gtfs_osm_match_exact = FALSE
  )
)

regions = rbind( # NYC, Bronx
  regions,
  data.frame(
    name = "nyc_bronx",
    gtfs_url = "data/gtfs_bx.zip", # https://rrgtfsfeeds.s3.amazonaws.com/gtfs_bx.zip",
    gtfs_day = Sys.Date(),
    gtfs_manipulate = "manipulate_gtfs_bronx",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "Metropolitan Transportation Authority", key_exact = TRUE)
    )))
  )
)
regions = rbind( # NYC, Brooklyn
  regions,
  data.frame(
    name = "nyc_brooklyn",
    gtfs_url = "data/gtfs_b.zip", # https://rrgtfsfeeds.s3.amazonaws.com/gtfs_b.zip",
    gtfs_day = gsub("-", "", Sys.Date()),
    gtfs_manipulate = "manipulate_gtfs_brooklyn",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "Metropolitan Transportation Authority", key_exact = TRUE)
    )))
  )
)
regions = rbind( # NYC, Manhattan
  regions,
  data.frame(
    name = "nyc_manhattan",
    gtfs_url = "https://rrgtfsfeeds.s3.amazonaws.com/gtfs_m.zip",
    gtfs_day = gsub("-", "", Sys.Date()),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "Metropolitan Transportation Authority", key_exact = TRUE)
    )))
  )
)
regions = rbind( # NYC, Queens
  regions,
  data.frame(
    name = "nyc_queens",
    gtfs_url = "https://rrgtfsfeeds.s3.amazonaws.com/gtfs_q.zip",
    gtfs_day = gsub("-", "", Sys.Date()),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "Metropolitan Transportation Authority", key_exact = TRUE)
    )))
  )
)
regions = rbind( # NYC, Staten Island
  regions,
  data.frame(
    name = "nyc_statenisland",
    gtfs_url = "https://rrgtfsfeeds.s3.amazonaws.com/gtfs_si.zip",
    gtfs_day = gsub("-", "", Sys.Date()),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "Metropolitan Transportation Authority", key_exact = TRUE)
    )))
  )
)
regions = rbind( # NYC, MTA
  regions,
  data.frame(
    name = "nyc_mta",
    gtfs_url = "https://rrgtfsfeeds.s3.amazonaws.com/gtfs_busco.zip",
    gtfs_day = gsub("-", "", Sys.Date()),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "Metropolitan Transportation Authority", key_exact = TRUE)
    )))
  )
)

# Fuenlabrada, ES
regions = rbind(
  regions,
  data.frame(
    name = "fuenlabrada",
    gtfs_url = "https://api.control.optibus.co/opendata/v1/gtfs?uid=c-5cfcd2d1",
    gtfs_day = Sys.Date(),
    gtfs_manipulate = manipulate_gtfs_fuenlabrada,
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "operator", value = "EMT Fuenlabrada", key_exact = TRUE)
    )))
  )
)


# Helpers

manipulate_gtfs_cp = function(gtfs) {
  # Method to manipulate GTFS routes names, to enable match with OSM names
  # See https://github.com/U-Shift/GTFShift/issues/35 for more details

  # String replace service acronym in gtfs$routes$route_short_name by extended name
  # Example: "AP" by "Alfa Pendular",  "IC" by "Intercidades"
  gtfs$routes$route_short_name = gsub("AP", "Alfa Pendular", gtfs$routes$route_short_name)
  gtfs$routes$route_short_name = gsub("IC", "Intercidades", gtfs$routes$route_short_name)
  gtfs$routes$route_short_name = gsub("IR", "InterR", gtfs$routes$route_short_name)
  gtfs$routes$route_short_name = gsub("R", "Regional", gtfs$routes$route_short_name)
  gtfs$routes$route_short_name = gsub("U", "Urbano", gtfs$routes$route_short_name)

  # Extend gtfs$routes$route_short_name with origin/destination station names
  gtfs$routes = gtfs$routes |> mutate(
    from = str_split_fixed(route_id, "-", 3)[, 2],
    to = str_split_fixed(route_id, "-", 3)[, 3]
  ) |>
    left_join(gtfs$stops |> select(stop_id, stop_name) |> rename(from_name = stop_name), by = c("from" = "stop_id")) |>
    left_join(gtfs$stops |> select(stop_id, stop_name) |> rename(to_name = stop_name), by = c("to" = "stop_id")) |>
    mutate(route_short_name = sprintf("%s %s %s", route_short_name, from_name, to_name))

  return(gtfs)
}


manipulate_gtfs_bronx = function(gtfs) { # https://en.wikipedia.org/wiki/List_of_bus_routes_in_the_Bronx
  # Filter routes by region (route_id start characters)
  routes_bronx = gtfs$routes |>
    filter(str_detect(route_short_name, "^Bx"))
  trips_routes_bronx = gtfs$trips |>
    filter(route_id %in% routes_bronx$route_id)
  gtfs = tidytransit::filter_feed_by_trips(gtfs, trips_routes_bronx$trip_id)
  
  return(gtfs)
}

manipulate_gtfs_brooklyn = function(gtfs) { # https://en.wikipedia.org/wiki/List_of_bus_routes_in_Brooklyn
  # Filter routes by region (route_id start characters)
  routes_brooklyn = gtfs$routes |>
    # MUst start with B followed by number (Bx should be ignored)
    filter(str_detect(route_short_name, "^B[0-9]"))
  trips_routes_brooklyn = gtfs$trips |>
    filter(route_id %in% routes_brooklyn$route_id)
  gtfs = tidytransit::filter_feed_by_trips(gtfs, trips_routes_brooklyn$trip_id)
  
  return(gtfs)
}

manipulate_gtfs_fuenlabrada = function(gtfs) {
  # Append "L" suffix to route_short_name
  gtfs$routes$route_short_name = paste0("L", gtfs$routes$route_short_name)
  return(gtfs)
}
