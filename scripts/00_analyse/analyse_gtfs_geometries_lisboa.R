# Visualize GTFS geometries
library(GTFShift)
library(dplyr)
library(sf)
library(mapview)

data <- read.csv(system.file("extdata", "gtfs_sources_pt.csv", package = "GTFShift"))

region <- "lisboa"
dir.create(sprintf("00_analyse/outputs/%s", region), showWarnings = FALSE, recursive = TRUE)

gtfs_lisboa <- GTFShift::load_feed(data[data$ID == "lisboa", ]$URL, create_transfers = FALSE)
gtfs <- gtfs_lisboa
summary(gtfs)

gtfs_shapes_sf <- tidytransit::shapes_as_sf(gtfs$shapes)
nrow(gtfs_shapes_sf)
map_gtfs_shapes <- mapview(gtfs_shapes_sf, legend = FALSE)
mapshot(map_gtfs_shapes, sprintf("00_analyse/outputs/%s/%s_gtfs_shapes.html", region, region), selfcontained = TRUE)

gtfs_shapes_points_sf <- gtfs$shapes |>
    st_as_sf(coords = c("shape_pt_lon", "shape_pt_lat"), crs = 4326)
nrow(gtfs_shapes_points_sf)
map_gtfs_shapes_points <- mapview(gtfs_shapes_points_sf, zcol = "shape_id", legend = FALSE)
mapshot(map_gtfs_shapes_points, sprintf("00_analyse/outputs/%s/%s_gtfs_shapes_points.html", region, region), selfcontained = TRUE)

osm_data <- st_read("/home/goncalo/Downloads/export(1).geojson") |>
    filter(st_geometry_type(geometry) %in% c("LINESTRING", "MULTILINESTRING"))
map_osm <- mapview(osm_data, zcol = "id", legend = FALSE)
mapshot(map_osm, sprintf("00_analyse/outputs/%s/%s_osm.html", region, region), selfcontained = TRUE)

# Get linestring points/vertices
osm_data_points <- osm_data |>
    st_transform(crs = 4326) |>
    st_cast("POINT")
map_osm_points <- mapview(osm_data_points, zcol = "id", legend = FALSE)
mapshot(map_osm_points, sprintf("00_analyse/outputs/%s/%s_osm_points.html", region, region), selfcontained = TRUE)
