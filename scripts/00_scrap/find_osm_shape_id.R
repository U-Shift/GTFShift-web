library(dplyr)
library(osmextract)

# Change osmextract options("timeout") to 120 minutes
options(timeout = 60 * 60 * 2) # Seconds
options("timeout")
# Find neyworks with shape_id

# Load method get_osm_relations_bus from 00_scrap/osm_utils.R
source("osm_utils.R")

output_folder <- "results"
if (!dir.exists(output_folder)) dir.create(output_folder)

osm_regions <- c(
    # "australia-oceania",
    # "africa",
    # "south-america",
    # "asia",
    # "central-america",
    "europe",
    "north-america",
    "antarctica"
)

for (osm_region in osm_regions) {
    start_timestamp <- Sys.time()
    message(sprintf("Processing %s, starting at %s...", osm_region, start_timestamp))
    # Download PBF
    osm_file <- osmextract::oe_download(
        sprintf("https://download.geofabrik.de/%s-latest.osm.pbf", osm_region),
        file_basename = sprintf("%s_%s.osm.pbf", stringr::str_replace_all(osm_region, "/", "_"), format(Sys.Date(), "%Y%m%d"))
    )


    # Get route relations
    message("Getting OSM relations...")
    relations_df <- get_osm_relations_bus(osm_file)
    # nrow(relations_df)
    # names(relations_df)
    # summary(relations_df)
    # View(relations_df)

    # Get data on networks with OSM gtfs attributes
    message("Extracting OSM relation attributes...")
    relations <- relations_df |>
        group_by(relation_osm_id) |>
        summarise(
            tags = n(),
            network = first(val[key == "network"]),
            operator = first(val[key == "operator"]),
            name = first(val[key == "name"]),
            gtfs_shape_id = first(val[key == "gtfs:shape_id"]),
            gtfs_route_id = first(val[key == "gtfs:route_id"]),
            gtfs_feed_id = first(val[key == "gtfs:feed_id"])
        )
    # summary(relations)
    # View(relations)
    # summary(relations$gtfs_shape_id)

    networks <- relations |>
        group_by(network) |>
        summarise(
            relations = n(),
            gtfs_shape_id_n = sum(!is.na(gtfs_shape_id)),
            gtfs_route_id_n = sum(!is.na(gtfs_route_id)),
            gtfs_feed_id_n = sum(!is.na(gtfs_feed_id)),
            relation_id_example = first(relation_osm_id)
        ) |>
        arrange(desc(gtfs_shape_id_n))
    # summary(networks)
    # View(networks)

    operators <- relations |>
        group_by(operator) |>
        summarise(
            relations = n(),
            gtfs_shape_id_n = sum(!is.na(gtfs_shape_id)),
            gtfs_route_id_n = sum(!is.na(gtfs_route_id)),
            gtfs_feed_id_n = sum(!is.na(gtfs_feed_id)),
            relation_id_example = first(relation_osm_id)
        ) |>
        arrange(desc(gtfs_shape_id_n))
    # summary(operators)
    # View(operators)

    message("Writing OSM relations to file...")
    write.csv(networks, sprintf("%s/networks_osm_%s.csv", output_folder, osm_region), row.names = FALSE)
    write.csv(operators, sprintf("%s/operators_osm_%s.csv", output_folder, osm_region), row.names = FALSE)

    end_timestamp <- Sys.time()
    elapsed_time <- difftime(end_timestamp, start_timestamp, units = "mins")
    message(sprintf("Done! Processing %s ended at %s and took %.2f minutes.\n", osm_region, end_timestamp, elapsed_time))
}
