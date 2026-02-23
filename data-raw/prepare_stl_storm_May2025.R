# data-raw/prepare_stl_storm_May2025.R
# Script to prepare Tornado storm dataset for birdweatheR package
# Requires a live API connection - run manually, not during package build

library(birdweatheR)

connect_birdweather()

# # Bounding box around St.Louis Missouri Metro area
ne <- list(lat = 39.235090, lon = -89.417725)  # northeast corner
sw <- list(lat = 38.262625, lon = -91.345825)  # southwest corner

stl_storm_May2025 <- get_detections(
  from = "2025-05-12T00:00:00.000Z",
  to   = "2025-05-18T00:00:00.000Z",
  ne   = ne,
  sw   = sw,
  confidence_gte = 0.6,
  station_types = 'puc'
)

usethis::use_data(stl_storm_May2025, overwrite = TRUE)

# identify unique stations
unique_stations <- stl_storm_May2025[, .(station_name = station_name[1],
                                         station_lat  = station_lat[1],
                                         station_lon  = station_lon[1]),
                                     by = station_id]

# get environmental data for the stations
env_list <- lapply(unique_stations$station_id, function(sid) {
  get_environment_data(
    station_id = sid,
    from       = "2025-05-14T00:00:00.000Z",
    to         = "2025-05-17T00:00:00.000Z"
  )
})

stl_env_May2025 <- data.table::rbindlist(env_list, fill = TRUE)

usethis::use_data(stl_env_May2025, overwrite = TRUE)
