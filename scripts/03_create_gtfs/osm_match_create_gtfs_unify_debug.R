library(dplyr)


unified_read <- GTFShift::load_feed("osm_gtfs/aml_barreiro_cascais_lisboa/run_20260521_165353/gtfs_unified.zip", create_transfers = FALSE)
summary(unified_read)
View(unified_read$stops |> filter(!is.na(parent_station) & parent_station != ""))
# View(unified_read$agency)
table(unified_read$agency$agency_id)

shapes_sf <- tidytransit::shapes_as_sf(unified_read$shapes) |>
    mutate(
        # Split shape_id by _ and get first value
        agency = sapply(strsplit(shape_id, "_"), `[`, 1)
    )
table(shapes_sf$agency)
nrow(shapes_sf)
mapview::mapview(shapes_sf, zcol = "agency")


gtfs <- tidytransit::read_gtfs("osm_match/aml/gtfs_20260506/gtfs_AML_20260506_osm.zip")
summary(gtfs)
shapes_sf <- tidytransit::shapes_as_sf(gtfs$shapes)
mapview::mapview(shapes_sf)
