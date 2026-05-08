#' Get OSM relations and elements (ways and nodes) tagged as bus networks
get_osm_relations_bus <- function(osm_file) {
    bus_relations_pbf <- tempfile(fileext = ".osm.pbf")

    message("Filtering OSM relations tagged as bus...")
    rosmium::tags_filter(
        osm_file,
        "nwr/route=bus",
        output = bus_relations_pbf,
        overwrite = TRUE
    )

    message("Extracting OSM relations...")
    bus_relations_xml <- rosmium::show_content(
        bus_relations_pbf,
        object_type = c("relation"),
        output_format = "xml",
        preview = FALSE,
        spinner = FALSE
    )


    message("Extracting OSM relation attributes...")
    doc <- xml2::read_xml(bus_relations_xml)
    relations <- xml2::xml_find_all(doc, ".//relation")

    relations_data <- lapply(relations, function(rel) {
        tags <- xml2::xml_find_all(rel, ".//tag")
        tag_keys <- xml2::xml_attr(tags, "k")
        tag_vals <- xml2::xml_attr(tags, "v")
        names(tag_vals) <- tag_keys
        if (length(tags) == 0) {
            return(NULL)
        }
        ways <- xml2::xml_find_all(rel, ".//member[@type='way']")
        nodes <- xml2::xml_find_all(rel, ".//member[@type='node']")

        data.frame(
            # <relation>
            relation_osm_id = xml2::xml_attr(rel, "id"),
            ways = length(ways),
            nodes = length(nodes),
            # <tag>
            key = xml2::xml_attr(tags, "k"),
            val = xml2::xml_attr(tags, "v"),
            stringsAsFactors = FALSE,
            check.names = FALSE
        )
    })
    message("Binding OSM relation attributes...")
    relations_df <- dplyr::bind_rows(relations_data)

    return(relations_df)
}
