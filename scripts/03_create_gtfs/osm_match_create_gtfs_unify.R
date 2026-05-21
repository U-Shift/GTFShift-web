# Run with: $ Rscript 03_create_gfts/osm_match_create_gtfs_unify.R
library(dplyr)

gtfs_urls <- c(
    "osm_match/cascais/gtfs_20260507/gtfs_cascais_20260507_osm.zip",
    "osm_match/barreiro/gtfs_20260518/gtfs_barreiro_20260518_osm.zip",
    "osm_match/lisboa/gtfs_20260505/gtfs_lisboa_2026-05-05_osm.zip",
    "osm_match/aml/gtfs_20260506/gtfs_AML_20260506_osm.zip"
)

gtfs_list <- lapply(gtfs_urls, function(gtfs_url) {
    feed <- GTFShift::load_feed(gtfs_url, create_transfers = FALSE)
    # If feed has columns start_pickup_drop_off_window and end_pickup_drop_off_window, remove them (they are not supported by gtfsrouter)
    if ("start_pickup_drop_off_window" %in% names(feed$stop_times)) {
        feed$stop_times <- feed$stop_times |> select(-start_pickup_drop_off_window, -end_pickup_drop_off_window)
    }
    summary(feed)
    return(feed)
})

unified <- GTFShift::unify(gtfs_list[[1]], gtfs_list[[2]], gtfs_list[[3]], prefix = TRUE)

if (!dir.exists("osm_match/unified")) dir.create("osm_match/unified")
tidytransit::write_gtfs(unified, sprintf("osm_match/unified/gtfs_unified_%s.zip", format(Sys.time(), "%Y%m%d_%H%M")))
