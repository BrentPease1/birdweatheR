# prepare eclipse data


# eclipse example
# # Bounding box around midwest eclipse path on April 8, 2024
ne <- list(lat = 42.639347, lon = -79.672852)  # northeast corner
sw <- list(lat = 34.331340, lon = -94.570313)  # southwest corner

total_eclipse <- get_detections(
  from = "2024-04-08T00:00:00.000Z",
  to   = "2024-04-09T00:00:00.000Z",
  ne   = ne,
  sw   = sw,
  confidence_gte = 0.6,
  station_types = "puc"
)

usethis::use_data(total_eclipse, overwrite = TRUE)

# identify unique stations
unique_stations <- total_eclipse[, .(station_name = station_name[1],
                                     station_lat  = station_lat[1],
                                     station_lon  = station_lon[1]),
                                 by = station_id]

# download light data
eclipse_light_data <-   get_light_data(
  station_id = unique_stations$station_id,
  from = "2024-04-08T00:00:00.000Z",
  to   = "2024-04-09T00:00:00.000Z"
)


usethis::use_data(eclipse_light_data, overwrite = TRUE)

# download env data
eclipse_env_data <- get_environment_data(
  station_id = unique_stations$station_id,
  from       = "2024-04-08T00:00:00.000Z",
  to         = "2024-04-09T00:00:00.000Z"
)
usethis::use_data(eclipse_env_data, overwrite = TRUE)
