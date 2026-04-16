library(GTFShift)
library(dplyr)
library(stringr)

library(osmdata)
get_overpass_url()
# set_overpass_url("https://maps.mail.ru/osm/tools/overpass/api/interpreter")
set_overpass_url("https://overpass.private.coffee/api/interpreter") # 4 servers with 20 cores, 256GB RAM, SSD each
get_overpass_url()

# Refer to osm_match_parameters.R to define parameters before running this script!

# main()
for (i in 1:nrow(regions)) {
  region <- regions[i, ]
  output <- sprintf("%s/%s", output_root, tolower(region$name))
  if (!dir.exists(output)) {
    dir.create(output, recursive = TRUE)
  }
  message(sprintf("\n\nRunning for %s (%s)...", region$name, region$gtfs_day))

  gtfs <- GTFShift::load_feed(region$gtfs_url, headers = if (!is.null(region$gtfs_url_headers)) unlist(region$gtfs_url_headers[[1]]) else NULL)
  summary(gtfs)
  assign(sprintf("gtfs_%s_%s", region$name, region$gtfs_day), gtfs)
  tidytransit::write_gtfs(gtfs, sprintf("%s/gtfs_%s_%s.zip", output, region$name, region$gtfs_day))

  gtfs_shapes <- tidytransit::shapes_as_sf(gtfs$shapes)
  bbox <- sf::st_bbox(gtfs_shapes)

  if (!is.null(region$gtfs_manipulate)) {
    gtfs <- get(region$gtfs_manipulate)(gtfs)
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

  # Match shapes geometry
  shapes_match_routes <- GTFShift::osm_shapes_match_routes(
    gtfs, q,
    gtfs_match = if (!is.null(region$gtfs_match)) region$gtfs_match else "route_short_name",
    osm_match = if (!is.null(region$osm_match)) region$osm_match else "ref",
    gtfs_osm_match_exact = if (!is.null(region$gtfs_osm_match_exact)) region$gtfs_osm_match_exact else TRUE,
    log_file = sprintf("%s/shapes_match_%s_gtfs%s_run%s.r.log", output, region$name, region$gtfs_day, gsub("-", "", Sys.Date()))
  )
  # assign(sprintf("shapes_match_routes_%s_gtfs%s", region$name, region$gtfs_day), shapes_match_routes)

  write.csv(shapes_match_routes |> sf::st_drop_geometry() |> mutate(
    distance_diff = round(distance_diff),
    points_diff = round(points_diff)
  ), sprintf("%s/shapes_match_%s_gtfs%s_run%s.csv", output, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), row.names = FALSE)
  sf::st_write(shapes_match_routes, sprintf("%s/shapes_match_%s_gtfs%s_run%s.gpkg", output, region$name, region$gtfs_day, gsub("-", "", Sys.Date())), append = FALSE)
}

shapes_match_routes
nrow(shapes_match_routes)
nrow(shapes_match_routes |> distinct(route_id, shape_id, osm_id))
nrow(shapes_match_routes |> distinct(osm_id))

result <- shapes_match_routes |> sf::st_drop_geometry()
# View(result)
summary(result)
nrow(result)
nrow(result |> filter(distance_diff < 500 & points_diff < 100))
nrow(result |> filter(distance_diff < 1000 & points_diff < 500))
nrow(result |> filter(distance_diff < 1500 & points_diff < 500))

# View(result |> filter(distance_diff<1000 & points_diff<500))
# View(result |> filter(distance_diff>=1000))
# View(result |> filter(distance_diff>=1000 | points_diff>=500))

nrow(result |> filter(distance_diff >= 1000 | points_diff >= 500))

# View(shapes_match_routes |> filter(distance_diff<500 & points_diff<100))

summary(shapes_match_routes)

# DEBUG

# > See OSM routes geometry
routes <- gtfs$routes |>
  # filter(grepl("Sintra", route_short_name)) |>
  mutate(
    from = str_split_fixed(route_id, "-", 3)[, 2],
    to = str_split_fixed(route_id, "-", 3)[, 3]
  ) |>
  left_join(gtfs$stops |> select(stop_id, stop_name) |> rename(from_name = stop_name), by = c("from" = "stop_id")) |>
  left_join(gtfs$stops |> select(stop_id, stop_name) |> rename(to_name = stop_name), by = c("to" = "stop_id")) |>
  right_join(shapes_match_routes |> select(osm_id, route_id, shape_id), by = "route_id") |>
  sf::st_as_sf()

routes
# mapview::mapview(routes, zcol="osm_id")

# > Draw original shapes for those routes
routes_original <- routes |>
  sf::st_drop_geometry() |>
  left_join(gtfs_shapes, by = "shape_id") |>
  sf::st_as_sf()

# mapview::mapview(routes_original, zcol="osm_id")

osm_id_debug <- "2931353"
mapview::mapview(routes |> filter(osm_id == osm_id_debug), layer.name = "OSM route", color = "red") +
  mapview::mapview(routes_original |> filter(osm_id == osm_id_debug), layer.name = "GTFS route", color = "blue")
