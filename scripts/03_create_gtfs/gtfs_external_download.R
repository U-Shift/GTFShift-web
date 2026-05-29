# Run with: $ Rscript 03_create_gtfs/gtfs_external_download.R
library(dplyr)

gtfs_data <- data.frame()
gtfs_data <- bind_rows(gtfs_data, data.frame(
  name = "metro_lisboa",
  gtfs_url = "gtfs_external/metroLisboa.zip",
  date = "2026-05-27"
))
gtfs_data <- bind_rows(gtfs_data, data.frame(
  name = "transtejo",
  gtfs_url = "https://api.transtejo.pt/files/GTFS.zip",
  date = "2026-05-27"
))
gtfs_data <- bind_rows(gtfs_data, data.frame(
  name = "fertagus",
  gtfs_url = "https://www.fertagus.pt/GTFSTMLzip/Fertagus_GTFS.zip",
  date = "2026-05-27"
))
gtfs_data <- bind_rows(gtfs_data, data.frame(
  name = "mts",
  gtfs_url = "gtfs_external/mts.zip",
  date = "2026-05-27"
))
gtfs_data <- bind_rows(gtfs_data, data.frame(
  name = "cp",
  gtfs_url = "https://publico.cp.pt/gtfs/gtfs.zip",
  date = "2026-05-27",
  gtfs_manipulate = "manipulate_gtfs_cp"
))

manipulate_gtfs_cp <- function(gtfs) {
  # gtfs = tidytransit::read_gtfs("https://publico.cp.pt/gtfs/gtfs.zip")
  # Filter by Lisbon Urban and Regional services
  # Adapted from https://github.com/lxparapessoas/rede-madrugada/blob/main/analysis.md#filtrar-gtfs-cp-para-urbanos-lisboa
  railways_lisbon = c(
    "Linha da Azambuja", "Linha de Sintra", "Linha do Sado", "Linha de Cascais" 
  )
  routes_lisbon = gtfs$routes |>
    filter(route_short_name %in% railways_lisbon) #  | route_short_name=="R"
  trips_lisbon = gtfs$trips |>
    filter(route_id %in% routes_lisbon$route_id)
  gtfs = tidytransit::filter_feed_by_trips(gtfs, trip_ids = trips_lisbon$trip_id) 

  # Generate shapes
  gtfs$shapes <- GTFShift::create_shapes_from_stops(gtfs)

  # Filter by AML area (to exclude Regional services outside)
  # municipios <- sf::st_bbox(sf::st_read("https://github.com/U-Shift/MQAT/raw/refs/heads/main/data/Municipalities_geo.gpkg") |> 
  #  sf::st_union())
  # mapview::mapview(municipios)
  # summary(gtfs)
  # gtfs_sf <- tidytransit::shapes_as_sf(GTFShift::create_shapes_from_stops(gtfs))
  # mapview::mapview(gtfs_sf)
  # gtfs_filtered = tidytransit::filter_feed_by_area(gtfs, municipios)
  # gtfs_filtered_sf <- tidytransit::shapes_as_sf(GTFShift::create_shapes_from_stops(gtfs_filtered))
  # mapview::mapview(gtfs_filtered_sf)
  # summary(gtfs_filtered)
  
  return(gtfs)
}

output_root <- "gtfs_external"
output_dir <- sprintf("%s/run_%s", output_root, format(Sys.time(), "%Y%m%d_%H%M%S"))
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

for (i in 1:nrow(gtfs_data)) {
  region <- gtfs_data[i, ]
  gtfs_url <- region$gtfs_url
  date <- region$date
  name <- region$name
  message(sprintf("Running for %s...", name))

  gtfs <- tidytransit::read_gtfs(gtfs_url)
  gtfs <- tidytransit::filter_feed_by_date(gtfs, extract_date = date)
  tidytransit::write_gtfs(gtfs, sprintf("%s/gtfs_%s_%s.zip", output_dir, date, name))

  if (!is.null(region$gtfs_manipulate) && !is.na(region$gtfs_manipulate)) {
    message("Manipulating gtfs...")
    gtfs <- get(region$gtfs_manipulate)(gtfs)
    gtfs_file_manipulated <- sprintf("%s/gtfs_%s_%s_manipulated.zip", output_dir, date, name)
    if (!file.exists(gtfs_file_manipulated)) {
      tidytransit::write_gtfs(gtfs, gtfs_file_manipulated)
    }
  }
}
