# Debug
library(sf)
prioritization_debug <- prioritization |> mutate(
    routes = sapply(routes, function(x) paste(x, collapse = ";"), USE.NAMES = FALSE),
    shapes = sapply(shapes, function(x) paste(x, collapse = ";"), USE.NAMES = FALSE)
)
# prioritization <- st_read("releases/web/lisboa/2026-02-04/prioritization_lisboa_rt_gtfs2026-02-04_run20260203_extended.geojson")
loures <- sf::st_read("https://github.com/U-Shift/MQAT/raw/refs/heads/main/geo/MUNICIPIOSgeo.gpkg", quiet = TRUE) |> filter(Concelho == "Loures")

prioritization_0800 <- prioritization_debug |> filter(hour == 8)
prioritization_0800 <- st_intersection(prioritization_0800, loures)

p50_frequency <- quantile(prioritization_0800$frequency, 0.5, na.rm = TRUE)
p50_speed <- quantile(prioritization_0800$speed_avg, 0.5, na.rm = TRUE)
mapview::mapview(
    prioritization_0800 |> filter(is_bus_lane & (frequency < p50_frequency | (is.na(n_lanes) | n_lanes_direction <= 1) | speed_avg <= p50_speed)),
    layer.name = sprintf("Bus lane with -%d bus/h OR -2 lane/dir OR %.2f km/h or - avg. speed", p50_frequency, p50_speed),
    color = "#DAD887",
    homebutton = FALSE,
    lwd = 3
) + mapview::mapview(
    prioritization_0800 |> filter(is_bus_lane & frequency >= p50_frequency & !is.na(n_lanes) & n_lanes_direction > 1 & speed_avg > p50_speed),
    layer.name = sprintf("Bus lane with +%d bus/h AND +1 lane/dir AND +%.2f km/h avg.speed", p50_frequency - 1, p50_speed),
    color = "#3BC1A8",
    homebutton = FALSE,
    lwd = 3
) + mapview::mapview(
    prioritization_0800 |> filter(!is_bus_lane & frequency >= p50_frequency & !is.na(n_lanes) & n_lanes_direction > 1 & speed_avg <= p50_speed),
    layer.name = sprintf("NO bus lane with +%d bus/h AND +1 lane/dir AND %.2f km/h or - avg.speed", p50_frequency - 1, p50_speed),
    color = "#F63049",
    homebutton = FALSE,
    lwd = 3
)


mapview::mapview(
    prioritization_0800,
    color = rev(viridis::viridis(10, option = "F")),
    zcol = "speed_avg",
    layer.name = "Average speed per lane"
)

mapview::mapview(
    prioritization_0800,
    color = rev(viridis::viridis(10, option = "F")),
    zcol = "n_lanes_direction",
    layer.name = "Lanes/direction"
) + mapview::mapview(
    prioritization_0800,
    color = rev(viridis::viridis(10, option = "F")),
    zcol = "n_lanes_parking",
    layer.name = "Parking lanes",
    hide = TRUE
) + mapview::mapview(
    prioritization_0800,
    color = rev(viridis::viridis(10, option = "F")),
    zcol = "n_lanes_circulation",
    layer.name = "Circulation lanes",
    hide = TRUE
)


mapview::mapview(
    prioritization_0800 |> filter(is_bus_lane == TRUE),
    layer.name = "Bus lanes",
    color = "#3bc1a8"
)

mapview::mapview(loures) +
    mapview::mapview(
        prioritization_0800 |> filter(n_lanes_direction > 1),
        color = rev(viridis::viridis(10, option = "F")),
        zcol = "n_lanes_direction",
        layer.name = "Lanes/direction"
    )
