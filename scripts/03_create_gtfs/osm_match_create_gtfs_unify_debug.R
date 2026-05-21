unified_read <- GTFShift::load_feed("osm_match/unified/gtfs_unified_20260521_1224.zip", create_transfers = TRUE)
summary(unified_read)
shapes_sf <- tidytransit::shapes_as_sf(unified_read$shapes) |>
    mutate(
        # Split shape_id by _ and get first value
        agency = sapply(strsplit(shape_id, "_"), `[`, 1)
    )
mapview::mapview(shapes_sf, zcol = "agency")


gtfs <- tidytransit::read_gtfs("osm_match/aml/gtfs_20260506/gtfs_AML_20260506_osm.zip")
summary(gtfs)
shapes_sf <- tidytransit::shapes_as_sf(gtfs$shapes)
mapview::mapview(shapes_sf)
