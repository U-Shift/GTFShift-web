# Visualize GTFS geometries
library(GTFShift)
library(dplyr)
library(sf)
library(mapview)

data <- read.csv(system.file("extdata", "gtfs_sources_pt.csv", package = "GTFShift"))
gtfs_aml <- GTFShift::load_feed(data[data$ID == "AML", ]$URL, create_transfers = FALSE)
gtfs_aml <- GTFShift::load_feed("osm_match/aml/gtfs_20260506/gtfs_AML_20260506.zip", create_transfers = FALSE)

region <- "seixal"
dir.create(sprintf("00_analyse/outputs/%s", region), showWarnings = FALSE, recursive = TRUE)

gtfs <- gtfs_aml
summary(gtfs)

summary(gtfs)
gtfs_1 <- GTFShift::filter_by_agency(gtfs, id = 41)
summary(gtfs_1)
table(gtfs_1$stop_times$pickup_type)

gtfs_2 <- GTFShift::filter_by_agency(gtfs, id = 42)
summary(gtfs_2)
table(gtfs_2$stop_times$pickup_type)

gtfs_3 <- GTFShift::filter_by_agency(gtfs, id = 43)
summary(gtfs_3)
table(gtfs_3$stop_times$pickup_type)

gtfs_4 <- GTFShift::filter_by_agency(gtfs, id = 44)
summary(gtfs_4)
table(gtfs_4$stop_times$pickup_type)

# Get bbox to reduce area
aml <- sf::st_read("https://github.com/U-Shift/MQAT/raw/refs/heads/main/geo/MUNICIPIOSgeo.gpkg", quiet = TRUE)
bbox <- aml |>
    filter(Concelho == "Seixal") |>
    st_union()

gtfs_shapes_sf <- tidytransit::shapes_as_sf(gtfs$shapes) |> st_intersection(bbox)
nrow(gtfs_shapes_sf)
map_gtfs_shapes <- mapview(gtfs_shapes_sf, legend = FALSE)
mapshot(map_gtfs_shapes, sprintf("00_analyse/outputs/%s/%s_gtfs_shapes.html", region, region), selfcontained = TRUE)

gtfs_shapes_points_sf <- gtfs$shapes |>
    st_as_sf(coords = c("shape_pt_lon", "shape_pt_lat"), crs = 4326) |>
    st_intersection(bbox)
nrow(gtfs_shapes_points_sf)
map_gtfs_shapes_points <- mapview(gtfs_shapes_points_sf, zcol = "shape_id", legend = FALSE)
mapshot(map_gtfs_shapes_points, sprintf("00_analyse/outputs/%s/%s_gtfs_shapes_points.html", region, region), selfcontained = TRUE)

osm_data <- st_read("/home/goncalo/Downloads/export(3).geojson")
nrow(osm_data)
# Remove geometry type polygon and multipolygon
osm_data <- osm_data |>
    filter(st_geometry_type(geometry) %in% c("LINESTRING", "MULTILINESTRING"))
nrow(osm_data)

map_osm <- mapview(osm_data, zcol = "id", legend = FALSE)
mapshot(map_osm, sprintf("00_analyse/outputs/%s/%s_osm.html", region, region), selfcontained = TRUE)

# Get linestring points/vertices
osm_data_points <- osm_data |>
    st_transform(crs = 4326) |>
    st_cast("POINT")
map_osm_points <- mapview(osm_data_points, zcol = "id", legend = FALSE)
mapshot(map_osm_points, sprintf("00_analyse/outputs/%s/%s_osm_points.html", region, region), selfcontained = TRUE)
