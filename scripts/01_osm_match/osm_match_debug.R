library(dplyr)
library(mapview)

# MAke sure these variables are defined
output_root
regions
gtfs_date <- "20260526"
run_date <- "20260526"
run_hour <- "154055"

region <- regions |> slice_head(n = 1)

gtfs_file <- sprintf("%s/gtfs_%s_%s.zip", output_root, region$name, gtfs_date)
gtfs <- GTFShift::load_feed("osm_match/metromadrid/gtfs_20260526/gtfs_metroMadrid_20260526.zip", create_transfers = FALSE)
summary(gtfs)

gtfs_shapes <- tidytransit::shapes_as_sf(gtfs$shapes)

osm_shapes <- sf::st_read("osm_match/metromadrid/gtfs_20260526/run_20260526_154055/shapes_match_metroMadrid_gtfs20260526_run20260526.gpkg")
View(osm_shapes |> sf::st_drop_geometry() |> arrange(desc(distance_diff)))

shape_id <- "p9c8"
mapview(gtfs_shapes |> filter(shape_id == !!shape_id))



mapview(gtfs_shapes, zcol="shape_id") +
  mapview(osm_shapes |> filter(osm_id=="7840622"))
