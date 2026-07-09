
osm_data <- sf::st_read("https://github.com/U-Shift/busclar/releases/download/0.9/shapes_match_carris_gtfs20260527_run20260626.gpkg")
previous <- sf::st_read("data/cm_20260413_220260430_business/processing_speed_shape_distance/osm_shapes_linestring.gpkg")
# new <- sf::st_read("data/cm_20260413_220260430_business/processing_speed_shape_distance_osm_multiline_to_line_circular_fix/osm_shapes_linestring.gpkg")
# previous <- sf::st_read("data/cm_20260413_220260430_business/osm_multiline_to_line_circular_fix/osm_shapes_linestring.gpkg")
new <- sf::st_read("data/cm_20260413_220260430_business/osm_multiline_to_line_circular_fix_2/osm_shapes_linestring.gpkg")

mapview(previous)
mapview(new)

# Numbers
metric_crs = 3763
previous_length <- previous |> st_transform(metric_crs) |> mutate(previous_length = as.numeric(st_length(geom))) |> st_drop_geometry()
new_length <- new |> st_transform(metric_crs) |> mutate(new_length = as.numeric(st_length(geom))) |> st_drop_geometry()

comparison <- previous_length |> 
  left_join(new_length |> select(osm_id, new_length), by = "osm_id") |> 
  mutate(
    length_diff = new_length - previous_length,
    length_diff_abs = abs(length_diff)
  ) |>
  left_join(osm_data|> st_drop_geometry() |> select(osm_id, route_short_name, osm_name), by = "osm_id") |>
  filter(!is.na(new_length)) |>
  arrange(desc(length_diff_abs))

View(comparison)
summary(comparison$length_diff_abs)
(nrow(comparison |> filter(length_diff_abs > 0)) / nrow(comparison)) * 100

# Visualize
OSM_ID_DEBUG = 19136076 # 751 ⬜
OSM_ID_DEBUG = 13930600 # 717 ⬆️
OSM_ID_DEBUG = 9479486 # 717 ⬆️
OSM_ID_DEBUG = 10400965 # 22B ⬜
OSM_ID_DEBUG = 9349266 # 79B ❌
OSM_ID_DEBUG = 8754525 # 723  ⬆️
OSM_ID_DEBUG = 9623106 # 751 ⬜
OSM_ID_DEBUG = 13602671 # 797 ⬜
OSM_ID_DEBUG = 9486535 # 747 ❌
OSM_ID_DEBUG = 9963441 # 34B ⬆️

mapview(previous[previous$osm_id == OSM_ID_DEBUG, ], layer.name = "Previous", color = "orange", lwd=10, alpha=0.5) +
  mapview(new[new$osm_id == OSM_ID_DEBUG, ], layer.name = "New", color = "black")

SHAPE_ID_DEBUG = "226_0_CIRC_shp" # 34B ✅
mapview(previous[previous$shape_id == SHAPE_ID_DEBUG, ], layer.name = "Previous", color = "orange", lwd=10, alpha=0.5) +
  mapview(new[new$shape_id == SHAPE_ID_DEBUG, ], layer.name = "New", color = "black")
