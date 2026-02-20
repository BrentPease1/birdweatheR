# helpers.R
# Shared utility functions for the birdweather package.
# These are internal helpers not exported to the user.

#' Flatten a page of detection nodes into a clean data.table
#'
#' Takes the raw nested data frame returned by fromJSON for a page of
#' detection nodes and expands all nested objects (coords, species, station)
#' into individual flat columns. Also normalizes station_location so that
#' empty strings are converted to NA consistently.
#'
#' @param nodes A data frame of detection nodes as returned by fromJSON
#' @return A flat data.table with 19 columns
#' @noRd
flatten_nodes <- function(nodes) {
  data.table::data.table(
    id                = nodes$id,
    timestamp         = nodes$timestamp,
    confidence        = nodes$confidence,
    score             = nodes$score,
    det_lat           = nodes$coords$lat,
    det_lon           = nodes$coords$lon,
    species_id        = nodes$species$id,
    common_name       = nodes$species$commonName,
    scientific_name   = nodes$species$scientificName,
    station_id        = nodes$station$id,
    station_name      = nodes$station$name,
    station_type      = nodes$station$type,
    station_timezone  = nodes$station$timezone,
    station_country   = nodes$station$country,
    station_continent = nodes$station$continent,
    station_state     = nodes$station$state,
    station_location = data.table::fifelse(
      is.na(nodes$station$location) | nodes$station$location == "",
      NA_character_,
      as.character(nodes$station$location)
    ),
    station_lat       = nodes$station$coords$lat,
    station_lon       = nodes$station$coords$lon
  )
}

utils::globalVariables(":=")
