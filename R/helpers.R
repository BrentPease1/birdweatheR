# helpers.R
# Shared utility functions for the birdweather package.
# These are internal helpers not exported to the user.
#
utils::globalVariables(":=")
#' Flatten a page of detection nodes into a clean data.table
#'
#' Takes the raw nested data frame returned by fromJSON for a page of
#' detection nodes and expands all nested objects (coords, species, station)
#' into individual flat columns. Also normalizes station_location so that
#' empty strings are converted to NA consistently.
#'
#' @param nodes A data frame of detection nodes as returned by fromJSON
#' @return A flat data.table with 20 columns
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
    classification    = nodes$species$classification,
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

#' Execute a paginated GraphQL request with exponential backoff retry
#'
#' Wraps a single BirdWeather API page request with automatic retry logic
#' to handle transient server errors (e.g. HTTP 504 gateway timeouts) that
#' can occur mid-pagination on large queries. On each failure, waits an
#' exponentially increasing amount of time before retrying. HTML error
#' response bodies are collapsed to a single readable line in the console.
#'
#' @param query_exec A ghql query object as returned by
#'   \code{ghql::Query$new()$query()}
#' @param variables A named list of GraphQL variables to pass with the request
#' @param max_retries Maximum number of attempts before giving up and throwing
#'   an error (default: 5). Backoff sequence is approximately 2s, 4s, 8s, 16s.
#'
#' @return The parsed JSON response list from \code{jsonlite::fromJSON} on
#'   success. Stops with an error if all attempts are exhausted.
#' @noRd
fetch_page_with_retry <- function(query_exec, variables, max_retries = 5) {
  attempt <- 0

  repeat {
    attempt <- attempt + 1

    result <- tryCatch(
      .birdweather_env$connection$exec(query_exec$url_link, variables = variables) |>
        jsonlite::fromJSON(flatten = FALSE),
      error = function(e) list(.__error = conditionMessage(e))
    )

    # Transport-level error (e.g. connection reset, curl error)
    if (!is.null(result$.__error)) {
      msg <- result$.__error
      # API-level error (e.g. 504 returned as GraphQL error body)
    } else if (!is.null(result$errors)) {
      msg <- paste(result$errors$message, collapse = "; ")
    } else {
      return(result)  # success — exit retry loop
    }

    # Collapse HTML error pages to one clean line
    if (grepl("<html", msg, ignore.case = TRUE)) {
      status <- regmatches(msg, regexpr("\\[HTTP \\d+\\]", msg))
      status <- if (length(status)) status else "HTTP error"
      msg    <- paste(status, "(server returned HTML error page)")
    }

    if (attempt >= max_retries) {
      stop("Page failed after ", max_retries, " attempts. Last error: ", msg)
    }

    wait <- 2^attempt + runif(1, 0, 1)  # exponential backoff + jitter
    message("  Transient error on attempt ", attempt, ": ", msg)
    message("  Retrying in ", round(wait, 1), "s...")
    Sys.sleep(wait)
  }
}
