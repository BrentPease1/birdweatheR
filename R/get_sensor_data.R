#' Get BirdWeather PUC Environmental Sensor Data
#'
#' Retrieves environmental sensor readings from one or more BirdWeather PUC
#' stations. Includes temperature, humidity, barometric pressure, air quality,
#' eCO2, VOC, and sound pressure level. Handles pagination automatically.
#'
#' @param station_id A single station ID or character vector of station IDs (required)
#' @param from Start datetime in ISO8601 format (e.g. "2025-01-01T00:00:00.000Z")
#' @param to End datetime in ISO8601 format (e.g. "2025-01-02T00:00:00.000Z")
#' @param limit Maximum number of readings to return per station (default: NULL,
#'   returns all). When multiple station IDs are provided, limit applies to each
#'   station individually.
#'
#' @return A data.table with columns:
#'   station_id, timestamp, temperature, humidity, barometric_pressure,
#'   aqi, eco2, voc, sound_pressure_level
#' @export
#'
#' @examples
#' \dontrun{
#' connect_birdweather()
#'
#' # Single station
#' env <- get_environment_data(
#'   station_id = "1733",
#'   from       = "2025-05-01T00:00:00.000Z",
#'   to         = "2025-05-02T00:00:00.000Z"
#' )
#'
#' # Multiple stations - same time window
#' env <- get_environment_data(
#'   station_id = c("1733", "2522", "8947"),
#'   from       = "2025-05-01T00:00:00.000Z",
#'   to         = "2025-05-02T00:00:00.000Z"
#' )
#' }
get_environment_data <- function(station_id = NULL,
                                 from       = NULL,
                                 to         = NULL,
                                 limit      = NULL) {

  if (is.null(.birdweather_env$connection)) {
    stop("No API connection found. Please run connect_birdweather() first.")
  }

  if (is.null(station_id)) {
    stop("station_id is required for get_environment_data().")
  }

  # -------------------------------------------------------
  # Internal helper: fetch one station
  # -------------------------------------------------------
  .fetch_env <- function(sid) {

    initial_query <- '
      query station($id: ID!, $period: InputDuration, $first: Int) {
        station(id: $id) {
          sensors {
            environmentHistory(period: $period, first: $first) {
              pageInfo { hasNextPage endCursor }
              edges {
                node {
                  timestamp
                  temperature
                  humidity
                  barometricPressure
                  aqi
                  eco2
                  voc
                  soundPressureLevel
                }
                cursor
              }
            }
          }
        }
      }
    '

    following_query <- '
      query station($id: ID!, $period: InputDuration, $first: Int, $after: String) {
        station(id: $id) {
          sensors {
            environmentHistory(period: $period, first: $first, after: $after) {
              pageInfo { hasNextPage endCursor }
              edges {
                node {
                  timestamp
                  temperature
                  humidity
                  barometricPressure
                  aqi
                  eco2
                  voc
                  soundPressureLevel
                }
                cursor
              }
            }
          }
        }
      }
    '

    base_variables <- list(
      id    = as.character(sid),
      first = as.integer(if (is.null(limit)) 250 else min(250, limit))
    )

    if (!is.null(from) && !is.null(to)) {
      base_variables$period <- list(from = from, to = to)
    }

    flatten_env <- function(edges, sid) {
      node <- edges$node
      data.table::data.table(
        station_id           = sid,
        timestamp            = node$timestamp,
        temperature          = node$temperature,
        humidity             = node$humidity,
        barometric_pressure  = node$barometricPressure,
        aqi                  = node$aqi,
        eco2                 = node$eco2,
        voc                  = node$voc,
        sound_pressure_level = node$soundPressureLevel
      )
    }

    query_exec <- ghql::Query$new()$query('url_link', initial_query)
    result <- .birdweather_env$connection$exec(query_exec$url_link,
                variables = base_variables) |>
      jsonlite::fromJSON(flatten = FALSE)

    if (!is.null(result$errors)) {
      message("API returned errors for station ", sid, ":")
      print(result$errors)
      return(NULL)
    }

    env_hist <- result$data$station$sensors$environmentHistory
    edges    <- env_hist$edges

    if (is.null(edges) || length(edges) == 0) {
      message("No environmental data found for station ", sid)
      return(NULL)
    }

    all_pages    <- list(flatten_env(edges, sid))
    has_next     <- env_hist$pageInfo$hasNextPage
    after_cursor <- env_hist$pageInfo$endCursor

    message("Fetched page 1 - ", nrow(edges), " readings")

    page <- 1

    while (isTRUE(has_next) && (is.null(limit) || sum(sapply(all_pages, nrow)) < limit)) {

      page      <- page + 1
      remaining <- if (is.null(limit)) 250 else min(250, limit - sum(sapply(all_pages, nrow)))

      page_variables <- c(
        base_variables,
        list(first = as.integer(remaining), after = after_cursor)
      )

      query_exec <- ghql::Query$new()$query('url_link', following_query)
      result <- .birdweather_env$connection$exec(query_exec$url_link,
                  variables = page_variables) |>
        jsonlite::fromJSON(flatten = FALSE)

      if (!is.null(result$errors)) {
        message("API error on page ", page, " - stopping.")
        print(result$errors)
        break
      }

      env_hist <- result$data$station$sensors$environmentHistory
      edges    <- env_hist$edges

      if (is.null(edges) || length(edges) == 0) {
        message("No data on page ", page, " - stopping.")
        break
      }

      all_pages[[page]] <- flatten_env(edges, sid)
      has_next          <- env_hist$pageInfo$hasNextPage
      after_cursor      <- env_hist$pageInfo$endCursor

      message("Fetched page ", page, " - ", nrow(edges), " readings")
    }

    data.table::rbindlist(all_pages, fill = TRUE)
  }

  # -------------------------------------------------------
  # Loop over stations if multiple provided
  # -------------------------------------------------------
  station_id <- as.character(station_id)

  if (length(station_id) == 1) {
    result <- .fetch_env(station_id)
    if (is.null(result)) return(data.table::data.table())
    message("Done. Returning ", nrow(result), " environmental readings.")
    return(result)
  }

  message("Fetching environmental data for ", length(station_id), " stations...")
  results <- lapply(seq_along(station_id), function(i) {
    message("Station ", i, "/", length(station_id), " (", station_id[i], ")")
    .fetch_env(station_id[i])
  })

  results <- results[!sapply(results, is.null)]

  if (length(results) == 0) {
    message("No environmental data found for any of the specified stations.")
    return(data.table::data.table())
  }

  final <- data.table::rbindlist(results, fill = TRUE)
  message("Done. Returning ", nrow(final), " environmental readings across ",
          length(station_id), " stations.")
  final
}


#' Get BirdWeather PUC Light Sensor Data
#'
#' Retrieves spectral light sensor readings from one or more BirdWeather PUC
#' stations. Includes 8 spectral channels (f1-f8), clear light, and
#' near-infrared. Handles pagination automatically.
#'
#' @param station_id A single station ID or character vector of station IDs (required)
#' @param from Start datetime in ISO8601 format (e.g. "2025-01-01T00:00:00.000Z")
#' @param to End datetime in ISO8601 format (e.g. "2025-01-02T00:00:00.000Z")
#' @param limit Maximum number of readings to return per station (default: NULL,
#'   returns all). When multiple station IDs are provided, limit applies to each
#'   station individually.
#'
#' @return A data.table with columns:
#'   station_id, timestamp, clear, nir, f1, f2, f3, f4, f5, f6, f7, f8
#' @export
#'
#' @examples
#' \dontrun{
#' connect_birdweather()
#'
#' # Single station
#' light <- get_light_data(
#'   station_id = "1733",
#'   from       = "2025-05-01T00:00:00.000Z",
#'   to         = "2025-05-02T00:00:00.000Z"
#' )
#'
#' # Multiple stations - same time window
#' light <- get_light_data(
#'   station_id = c("1733", "2522", "8947"),
#'   from       = "2025-05-01T00:00:00.000Z",
#'   to         = "2025-05-02T00:00:00.000Z"
#' )
#' }
get_light_data <- function(station_id = NULL,
                           from       = NULL,
                           to         = NULL,
                           limit      = NULL) {

  if (is.null(.birdweather_env$connection)) {
    stop("No API connection found. Please run connect_birdweather() first.")
  }

  if (is.null(station_id)) {
    stop("station_id is required for get_light_data().")
  }

  # -------------------------------------------------------
  # Internal helper: fetch one station
  # -------------------------------------------------------
  .fetch_light <- function(sid) {

    initial_query <- '
      query station($id: ID!, $period: InputDuration, $first: Int) {
        station(id: $id) {
          sensors {
            lightHistory(period: $period, first: $first) {
              pageInfo { hasNextPage endCursor }
              edges {
                node {
                  timestamp
                  clear
                  nir
                  f1
                  f2
                  f3
                  f4
                  f5
                  f6
                  f7
                  f8
                }
                cursor
              }
            }
          }
        }
      }
    '

    following_query <- '
      query station($id: ID!, $period: InputDuration, $first: Int, $after: String) {
        station(id: $id) {
          sensors {
            lightHistory(period: $period, first: $first, after: $after) {
              pageInfo { hasNextPage endCursor }
              edges {
                node {
                  timestamp
                  clear
                  nir
                  f1
                  f2
                  f3
                  f4
                  f5
                  f6
                  f7
                  f8
                }
                cursor
              }
            }
          }
        }
      }
    '

    base_variables <- list(
      id    = as.character(sid),
      first = as.integer(if (is.null(limit)) 250 else min(250, limit))
    )

    if (!is.null(from) && !is.null(to)) {
      base_variables$period <- list(from = from, to = to)
    }

    flatten_light <- function(edges, sid) {
      node <- edges$node
      data.table::data.table(
        station_id = sid,
        timestamp  = node$timestamp,
        clear      = node$clear,
        nir        = node$nir,
        f1         = node$f1,
        f2         = node$f2,
        f3         = node$f3,
        f4         = node$f4,
        f5         = node$f5,
        f6         = node$f6,
        f7         = node$f7,
        f8         = node$f8
      )
    }

    query_exec <- ghql::Query$new()$query('url_link', initial_query)
    result <- .birdweather_env$connection$exec(query_exec$url_link,
                variables = base_variables) |>
      jsonlite::fromJSON(flatten = FALSE)

    if (!is.null(result$errors)) {
      message("API returned errors for station ", sid, ":")
      print(result$errors)
      return(NULL)
    }

    light_hist <- result$data$station$sensors$lightHistory
    edges      <- light_hist$edges

    if (is.null(edges) || length(edges) == 0) {
      message("No light data found for station ", sid)
      return(NULL)
    }

    all_pages    <- list(flatten_light(edges, sid))
    has_next     <- light_hist$pageInfo$hasNextPage
    after_cursor <- light_hist$pageInfo$endCursor

    message("Fetched page 1 - ", nrow(edges), " readings")

    page <- 1

    while (isTRUE(has_next) && (is.null(limit) || sum(sapply(all_pages, nrow)) < limit)) {

      page      <- page + 1
      remaining <- if (is.null(limit)) 250 else min(250, limit - sum(sapply(all_pages, nrow)))

      page_variables <- c(
        base_variables,
        list(first = as.integer(remaining), after = after_cursor)
      )

      query_exec <- ghql::Query$new()$query('url_link', following_query)
      result <- .birdweather_env$connection$exec(query_exec$url_link,
                  variables = page_variables) |>
        jsonlite::fromJSON(flatten = FALSE)

      if (!is.null(result$errors)) {
        message("API error on page ", page, " - stopping.")
        print(result$errors)
        break
      }

      light_hist <- result$data$station$sensors$lightHistory
      edges      <- light_hist$edges

      if (is.null(edges) || length(edges) == 0) {
        message("No data on page ", page, " - stopping.")
        break
      }

      all_pages[[page]] <- flatten_light(edges, sid)
      has_next          <- light_hist$pageInfo$hasNextPage
      after_cursor      <- light_hist$pageInfo$endCursor

      message("Fetched page ", page, " - ", nrow(edges), " readings")
    }

    data.table::rbindlist(all_pages, fill = TRUE)
  }

  # -------------------------------------------------------
  # Loop over stations if multiple provided
  # -------------------------------------------------------
  station_id <- as.character(station_id)

  if (length(station_id) == 1) {
    result <- .fetch_light(station_id)
    if (is.null(result)) return(data.table::data.table())
    message("Done. Returning ", nrow(result), " light readings.")
    return(result)
  }

  message("Fetching light data for ", length(station_id), " stations...")
  results <- lapply(seq_along(station_id), function(i) {
    message("Station ", i, "/", length(station_id), " (", station_id[i], ")")
    .fetch_light(station_id[i])
  })

  results <- results[!sapply(results, is.null)]

  if (length(results) == 0) {
    message("No light data found for any of the specified stations.")
    return(data.table::data.table())
  }

  final <- data.table::rbindlist(results, fill = TRUE)
  message("Done. Returning ", nrow(final), " light readings across ",
          length(station_id), " stations.")
  final
}
