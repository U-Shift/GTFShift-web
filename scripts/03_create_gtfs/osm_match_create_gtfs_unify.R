# Run with: $ Rscript 03_create_gtfs/osm_match_create_gtfs_unify.R
# remotes::install_github("gmatosferreira/gtfstools", ref="patch-2")
library(dplyr)

gtfs_urls <- c(
    "osm_gtfs/aml_1_aml_2_aml_3_aml_4_barreiro_cascais_lisboa/run_20260527_144749/gtfs_aml_1_osm.zip",
    "osm_gtfs/aml_1_aml_2_aml_3_aml_4_barreiro_cascais_lisboa/run_20260527_144749/gtfs_aml_2_osm.zip",
    "osm_gtfs/aml_1_aml_2_aml_3_aml_4_barreiro_cascais_lisboa/run_20260527_144749/gtfs_aml_3_osm.zip",
    "osm_gtfs/aml_1_aml_2_aml_3_aml_4_barreiro_cascais_lisboa/run_20260527_144749/gtfs_aml_4_osm.zip",
    "osm_gtfs/aml_1_aml_2_aml_3_aml_4_barreiro_cascais_lisboa/run_20260527_144749/gtfs_barreiro_osm.zip",
    "osm_gtfs/aml_1_aml_2_aml_3_aml_4_barreiro_cascais_lisboa/run_20260527_144749/gtfs_cascais_osm.zip",
    "osm_gtfs/aml_1_aml_2_aml_3_aml_4_barreiro_cascais_lisboa/run_20260527_144749/gtfs_lisboa_osm.zip",
    # Other operators
    "gtfs_external/run_20260528_145712/gtfs_2026-05-27_cp_manipulated.zip",
    "gtfs_external/run_20260528_145712/gtfs_2026-05-27_fertagus.zip",
    "gtfs_external/run_20260528_145712/gtfs_2026-05-27_metro_lisboa.zip",
    "gtfs_external/run_20260528_145712/gtfs_2026-05-27_mts.zip",
    "gtfs_external/run_20260528_145712/gtfs_2026-05-27_transtejo.zip"
)
output_dir <- "gtfs_external/run_20260528_145712/"

gtfs_list <- lapply(gtfs_urls, function(gtfs_url) {
    feed <- gtfstools::read_gtfs(gtfs_url)
    # If feed has columns start_pickup_drop_off_window and end_pickup_drop_off_window, remove them (they are not supported by gtfsrouter)
    if ("start_pickup_drop_off_window" %in% names(feed$stop_times)) {
        feed$stop_times <- feed$stop_times |> select(-start_pickup_drop_off_window, -end_pickup_drop_off_window)
    }
    summary(feed)
    return(feed)
})

prefix_arg <- unlist(lapply(gtfs_list, function(feed) feed$agency$agency_id))

unified <- do.call(GTFShift::unify, c(gtfs_list, list(prefix = TRUE)))

tidytransit::write_gtfs(unified, sprintf("%s/gtfs_unified.zip", output_dir))

# gtfs <- gtfstools::read_gtfs("gtfs_external/run_20260528_145712/gtfs_2026-05-27_cp.zip")
# summary(gtfs)
# gtfs$agency
