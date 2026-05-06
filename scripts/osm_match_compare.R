library(sf)
library(dplyr)

match_1 <- sf::st_read("osm_match/lisboa/gtfs_20260505/run_20260505_090741/shapes_match_lisboa_gtfs2026-05-05_run20260505.gpkg")
match_2 <- sf::st_read("osm_match/lisboa/gtfs_20260505/run_20260505_090741/shapes_match_lisboa_gtfs2026-05-05_run20260505.gpkg")

summary(match_1 |> select(distance_diff, points_diff, stops_diff))
summary(match_2 |> select(distance_diff, points_diff, stops_diff))

# For each shape_id, confirm if they have the same osm_id
assertthat::assert_that(nrow(match_1) == nrow(match_2))
match_compare <- match_1 |>
    st_drop_geometry() |>
    select(shape_id, osm_id) |>
    left_join(match_2 |> st_drop_geometry() |> select(shape_id, osm_id), by = "shape_id") |>
    mutate(match = osm_id.x == osm_id.y)

summary(match_compare)
