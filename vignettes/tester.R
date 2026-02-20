
devtools::load_all()
connect_birdweather()

find_species('chickadee')
focal_spp_id <- 224
test <- get_detections(
  from  = "2025-05-01T00:00:00.000Z",
  to    = "2025-05-02T00:00:00.000Z",
  limit = 5
)

detections <- get_detections(
  from        = "2024-05-01T00:00:00.000Z",
  to          = "2025-05-02T00:00:00.000Z",
  species_ids = focal_spp_id,
  limit = 1000
)

daily <- get_daily_detection_counts(
  from        = "2025-01-01T00:00:00.000Z",
  to          = "2025-01-05T00:00:00.000Z", by_species = T
)

# Join onto daily detection counts
species_info <- get_species_info(ids = unique(daily$speciesId))
daily[species_info, on = .(speciesId = species_id),
      `:=`(common_name     = i.common_name,
           scientific_name = i.scientific_name)]


# counts
counts <- get_counts(
  from = "2025-05-01T00:00:00.000Z",
  to   = "2025-05-02T00:00:00.000Z"
)

out <- result$data$timeOfDayDetectionCounts$bins[[1]]

robin_tod <- get_tod_counts(
  species_id = "123",
  from       = "2025-05-01T00:00:00.000Z",
  to         = "2025-05-07T00:00:00.000Z",
  confidence_gte = 0.65
)

get_top_species(
  from = "2025-05-01T00:00:00.000Z",
  to   = "2025-05-02T00:00:00.000Z"
)
