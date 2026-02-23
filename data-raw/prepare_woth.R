# data-raw/prepare_woth.R
# Script to prepare Wood Thrush example dataset for birdweatheR package
# Requires a live API connection - run manually, not during package build

library(birdweatheR)

connect_birdweather()

woth_id <- find_species("Wood Thrush")$species_id

woth <- get_detections(
  from           = "2025-03-01T00:00:00.000Z",
  to             = "2025-05-31T00:00:00.000Z",
  species_ids    = woth_id,
  confidence_gte = 0.6,
  continents     = "North America"
)

usethis::use_data(woth, overwrite = TRUE)
