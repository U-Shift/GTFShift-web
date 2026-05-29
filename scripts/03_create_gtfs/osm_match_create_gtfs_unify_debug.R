library(dplyr)


unified_read <- GTFShift::load_feed("osm_gtfs/aml_1_aml_2_aml_3_aml_4_barreiro_cascais_lisboa/run_20260527_144749/gtfs_unified.zip", create_transfers = FALSE)
unified_read <- GTFShift::load_feed("gtfs_external/run_20260528_145712/gtfs_unified.zip", create_transfers = FALSE)
summary(unified_read)
# View(unified_read$stops |> filter(!is.na(parent_station) & parent_station != ""))
unified_read$agency
table(unified_read$agency$agency_id)

shapes_sf <- tidytransit::shapes_as_sf(unified_read$shapes) |>
    mutate(
        # Split shape_id by _ and get first value
        agency = sapply(strsplit(shape_id, "_"), `[`, 1),
        agency_id = sprintf("%s_%s", agency, agency)
    ) |> 
    left_join(unified_read$agency |> select(agency_id, agency_name), by="agency_id") |>
    mutate(agency_label = sprintf("%s | %s", agency, agency_name))
table(shapes_sf$agency)
nrow(shapes_sf)
mapview::mapview(shapes_sf, zcol = "agency_label")


gtfs <- tidytransit::read_gtfs("osm_match/aml/gtfs_20260506/gtfs_AML_20260506_osm.zip")
summary(gtfs)
shapes_sf <- tidytransit::shapes_as_sf(gtfs$shapes)
mapview::mapview(shapes_sf)
