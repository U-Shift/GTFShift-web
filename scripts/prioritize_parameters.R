

# Parameters
output = "web_data"

regions = data.frame(
  name = character(),
  name_long = character(),
  gtfs = character(),
  query = I(list()),
  rt_interval = character(),
  rt_collection = I(list()) # sf object
  
)
data = read.csv(system.file("extdata", "gtfs_sources_pt.csv", package = "GTFShift"))

regions = rbind( # Lisboa
  regions,
  data.frame(
    name = "lisboa_rt",
    name_long = "Lisboa, Portugal",
    gtfs_url = "data/Lisboa_20260205.zip",
    gtfs_day = "2026-02-04",
    gtfs_manipulate = "manipulate_carris_lx",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Carris", key_exact = TRUE)
    ))),
    rt_interval = "02-06/02/2026",
    rt_collection = I(list(sf::st_read("data/lisboa_updates_20260202_20260206.csv") |>
                             mutate(
                               lon = str_replace(lon, "c\\(", ""),
                               lat = str_replace(lat, "\\)", ""),
                               speed = as.numeric(speed)
                             ) |> st_as_sf(coords = c("lon", "lat"), crs = 4326)))
  )
)

regions = rbind( # CarrisMetropolitana
  regions,
  data.frame(
    name = "aml_rt",
    name_long = "Lisboa Metro Area, Portugal",
    gtfs_url = "dev/AML_20260205.zip",
    gtfs_day = "2026-02-04",
    gtfs_manipulate = "manipulate_carris_met",
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "Carris Metropolitana", key_exact = TRUE)
    )))
    rt_interval = "02-06/02/2026",
    rt_collection = I(list(sf::st_read("data/cmet_20250113_20250119_updates.csv") |>
                             mutate(
                               speed = as.numeric(speed)
                             ) |> st_as_sf(coords = c("lon", "lat"), crs = 4326)))
  )
)

regions = rbind( # Cascais
  regions,
  data.frame(
    name = "cascais",
    name_long = "Cascais, Portugal",
    gtfs_url = "https://drive.google.com/uc?export=download&id=13ucYiAJRtu-gXsLa02qKJrGOgDjbnUWX",
    gtfs_day = Sys.Date(),
    query = I(list(list(
      list(key = "route", value = c("bus"), key_exact = TRUE),
      list(key = "network", value = "MobiCascais", key_exact = TRUE)
    )))
  )
)
#
# regions = rbind( # STCP
#   regions,
#   data.frame(
#     name = "stcp",
#     gtfs_url = data$URL[data$ID == "stcp"],
#     gtfs_day = gsub("-", "", Sys.Date()),
#     query = I(list(list(
#       list(key = "route", value = c("bus"), key_exact = TRUE),
#       list(key = "operator", value = "STCP", key_exact = TRUE)
#     )))
#   )
# )

regions = rbind( # NYC, MTA
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

manipulate_carris_met = function(gtfs) {
  
  # Remove all text from [ to ] from gtfs$shape_ids, which are present in Carris Metropolitana feed and cause issues in matching with OSM shapes
  gtfs$shapes$shape_id = str_replace_all(gtfs$shapes$shape_id, "\\[.*\\]", "")
  gtfs$trips$shape_id = str_replace_all(gtfs$trips$shape_id, "\\[.*\\]", "")
  
  return(gtfs)
}

manipulate_carris_lx = function(gtfs) {
  colors = read.csv("data_useful/carris_colors.csv")
  
  gtfs$routes = gtfs$routes |>
    select(-c(route_color, route_text_color)) |>
    left_join(colors, by = "route_short_name")
  
  return(gtfs)
}
