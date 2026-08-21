make_fake_nodes <- function(n = 2) {
  df <- data.frame(
    id          = as.character(1:n),
    timestamp   = rep("2025-05-01T08:00:00.000Z", n),
    confidence  = rep(0.9, n),
    probability = rep(0.85, n),
    score       = rep(1.2, n),
    stringsAsFactors = FALSE
  )

  df$coords <- data.frame(
    lat = rep(38.5, n),
    lon = rep(-89.2, n)
  )

  df$species <- data.frame(
    id              = rep("305", n),
    commonName      = rep("Black-capped Chickadee", n),
    scientificName  = rep("Poecile atricapillus", n),
    classification  = rep("bird", n),
    stringsAsFactors = FALSE
  )

  station_coords <- data.frame(
    lat = rep(38.5, n),
    lon = rep(-89.2, n)
  )

  df$station <- data.frame(
    id        = rep("100", n),
    name      = rep("Test Station", n),
    type      = rep("puc", n),
    timezone  = rep("America/Chicago", n),
    country   = rep("US", n),
    continent = rep("North America", n),
    state     = rep("IL", n),
    location  = rep("", n),
    stringsAsFactors = FALSE
  )
  df$station$coords <- station_coords

  df
}
