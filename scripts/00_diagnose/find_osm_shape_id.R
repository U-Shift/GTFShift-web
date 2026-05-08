# Find neyworks with shape_id

osm_regions <- c(
    "south-america"
)

for (osm_region in osm_regions) {
    # Download PBF
    osm_file <- osmextract::oe_download(
        sprintf("https://download.geofabrik.de/%s-latest.osm.pbf", osm_region),
        file_basename = sprintf("%s_%s.osm.pbf", stringr::str_replace_all(osm_region, "/", "_"), format(Sys.Date(), "%Y%m%d"))
    )

    # Get route relations
    bus_relations_pbf <- tempfile(fileext = ".osm.pbf")
    rosmium::tags_filter(
        osm_file,
        "nwr/route=bus",
        output = bus_relations_pbf,
        overwrite = TRUE
    )
    bus_relations_xml <- rosmium::show_content(
        bus_relations_pbf,
        object_type = c("relation"),
        output_format = "xml",
        preview = TRUE,
        spinner = FALSE
    )
    doc <- xml2::read_xml(bus_relations_xml)
    relations <- xml2::xml_find_all(doc, ".//relation")
    # TODO! From here
}
