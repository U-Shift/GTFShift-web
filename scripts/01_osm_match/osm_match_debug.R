library(dplyr)
library(mapview)

# MAke sure these variables are defined
output_root
regions
gtfs_date <- "20260507"
run_date <- "20260507"
run_hour <- "113820"

region <- regions |> slice_head(n = 1)

gtfs_file <- sprintf("%s/gtfs_%s_%s.zip", output_root, region$name, region$gtfs_day)
gtfs <- GTFShift::load_feed(region$gtfs_url, create_transfers = FALSE)
summary(gtfs)

gtfs_shapes <- tidytransit::shapes_as_sf(gtfs$shapes)

osm_shapes <- sf::st_read(sprintf("%s/%s/gtfs_%s/run_%s_%s/shapes_match_%s_gtfs%s_run%s.gpkg", output_root, tolower(region$name), gtfs_date, run_date, run_hour, region$name, gtfs_date, run_date))
View(osm_shapes |> sf::st_drop_geometry() |> arrange(desc(distance_diff)))

shape_id <- "p9c8"
mapview(gtfs_shapes |> filter(shape_id == !!shape_id))
