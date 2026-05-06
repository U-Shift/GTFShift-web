library(GTFShift)
library(dplyr)
library(stringr)
library(mapview)

library(osmdata)
# get_overpass_url()
# set_overpass_url("https://maps.mail.ru/osm/tools/overpass/api/interpreter")
# set_overpass_url("https://overpass.private.coffee/api/interpreter") # 4 servers with 20 cores, 256GB RAM, SSD each
# set_overpass_url("https://overpass-api.de/api/interpreter")
# get_overpass_url()

# Refer to osm_match_parameters.R to define parameters before running this script!
output_root <- "osm_match"

# Get OSM extract to avoid API call
library(osmextract)
oe_download_directory()
osm_file <- oe_download(
  "https://download.geofabrik.de/europe/portugal-latest.osm.pbf",
  file_basename = sprintf("%s_%s.osm.pbf", "PT", format(Sys.Date(), "%Y%m%d"))
)
osm_file

# Define regions to analyse
regions <- data.frame(
  name = character(),
  gtfs_url = character(),
  query = I(list())
)
data <- read.csv(system.file("extdata", "gtfs_sources_pt.csv", package = "GTFShift"))

regions <- rbind( # Lisboa
  regions,
  data.frame(
    name = "lisboa",
    gtfs_url = data$URL[data$ID == "lisboa"],
    gtfs_day = Sys.Date(),
    query = I(list(list(
      list(key = "route", value = c("bus", "tram"), key_exact = TRUE),
      list(key = "network", value = "Carris", key_exact = TRUE)
    )))
  )
)

# main()
for (i in 1:nrow(regions)) {
  region <- regions[i, ]
  output_root <- sprintf("%s/%s/gtfs_%s", output_root, tolower(region$name), gsub("-", "", region$gtfs_day))
  output <- sprintf("%s/run_%s", output_root, format(Sys.time(), "%Y%m%d_%H%M%S"))
  if (!dir.exists(output)) {
    dir.create(output, recursive = TRUE)
  }
  message(sprintf("\n\nRunning for %s (%s)...", region$name, region$gtfs_day))

  gtfs_file <- sprintf("%s/gtfs_%s_%s.zip", output_root, region$name, region$gtfs_day)
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

  if (!is.null(region$gtfs_manipulate)) {
    message("Manipulating gtfs...")
    gtfs <- get(region$gtfs_manipulate)(gtfs)
    gtfs_file_manipulated <- sprintf("%s/gtfs_%s_%s_manipulated.zip", output_root, region$name, region$gtfs_day)
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

  # Match shapes geometry
  message("Matching shapes...")
  shapes_match_routes <- GTFShift::osm_shapes_match_routes(
    gtfs, q,
    gtfs_match = if (!is.null(region$gtfs_match)) region$gtfs_match else "route_short_name",
    osm_match = if (!is.null(region$osm_match)) region$osm_match else "ref",
    gtfs_osm_match_exact = if (!is.null(region$gtfs_osm_match_exact)) region$gtfs_osm_match_exact else TRUE,
    log_file = sprintf("%s/shapes_match_%s_gtfs%s_run%s.r.log", output, region$name, region$gtfs_day, gsub("-", "", Sys.Date())),
    osm_file = osm_file,
    num_cores = max(1, parallel::detectCores() - 2)
  )
  # assign(sprintf("shapes_match_routes_%s_gtfs%s", region$name, region$gtfs_day), shapes_match_routes)

  write.csv(shapes_match_routes |> sf::st_drop_geometry() |> mutate(
    distance_diff = round(distance_diff),
    points_diff = round(points_diff)
  ), sprintf("%s/shapes_match_%s_gtfs%s_run%s.csv", output, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), row.names = FALSE)
  sf::st_write(shapes_match_routes, sprintf("%s/shapes_match_%s_gtfs%s_run%s.gpkg", output, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), append = FALSE)
  message("Done! :)")
}
