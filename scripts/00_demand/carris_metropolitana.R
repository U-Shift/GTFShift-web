library(dplyr)

# Source: https://api.carrismetropolitana.pt/v2/metrics/demand/by_line/
json_data <- jsonlite::fromJSON("data/demand/cm_until_20260631.json")

date_extract <- "2026-05-20"

demand_df <- data.frame(
  route_short_name = character(),
  demand = numeric(),
  stringsAsFactors = FALSE
)

for (i in 1:nrow(json_data)) {
  row <- json_data[i, ]
  # Extract the relevant fields from the JSON object
  line_id <- row$properties$line_id
  demand_data <- row$data[[date_extract]]
  if (is.null(demand_data)) {
    next  # Skip this iteration if demand data is not available for the specified date
  }

  demand_df <- rbind(demand_df, data.frame(
    route_short_name = line_id,
    demand = demand_data$qty,
    stringsAsFactors = FALSE
  ))
}
View(demand_df)

write.csv(demand_df |> filter(!is.na(demand)), "data/demand/cm_demand_20260520.csv", row.names = FALSE)
