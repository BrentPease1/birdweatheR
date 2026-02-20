#' Get BirdWeather PUC Environmental Sensor Data
#'
#' Retrieves environmental sensor readings from a BirdWeather PUC station.
#' Includes temperature, humidity, barometric pressure, air quality, eCO2,
#' VOC, and sound pressure level. Handles pagination automatically.
#'
#' @param station_id A single station ID (required)
#' @param from Start datetime in ISO8601 format (e.g. "2025-01-01T00:00:00.000Z")
#' @param to End datetime in ISO8601 format (e.g. "2025-01-02T00:00:00.000Z")
#' @param limit Maximum number of readings to return (default: NULL, returns all)
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
#' env <- get_environment_data(
#'   station_id = "1733",
#'   from       = "2025-05-01T00:00:00.000Z",
#'   to         = "2025-05-02T00:00:00.000Z"
#' )
#' }
get_environment_data <- function(station_id = NULL,
                                 from       = NULL,
                                 to         = NULL,
                                 limit      = NULL) {

  if (is.null(station_id)) {
    message("station_id is required for get_environment_data().")
    return(data.table::data.table())
  }

  # -------------------------------------------------------
  # Initial query (no after argument)
  # -------------------------------------------------------
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

  # -------------------------------------------------------
  # Following query (adds after argument)
  # -------------------------------------------------------
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
    id    = as.character(station_id),
    first = as.integer(if (is.null(limit)) 250 else min(250, limit))
  )

  if (!is.null(from) && !is.null(to)) {
    base_variables$period <- list(from = from, to = to)
  }

  # -------------------------------------------------------
  # Helper to flatten edges$node into a data.table
  # -------------------------------------------------------
  flatten_env <- function(edges, station_id) {
    node <- edges$node
    data.table::data.table(
      station_id          = station_id,
      timestamp           = node$timestamp,
      temperature         = node$temperature,
      humidity            = node$humidity,
      barometric_pressure = node$barometricPressure,
      aqi                 = node$aqi,
      eco2                = node$eco2,
      voc                 = node$voc,
      sound_pressure_level = node$soundPressureLevel
    )
  }

  # -------------------------------------------------------
  # Execute first page
  # -------------------------------------------------------
  query_exec <- ghql::Query$new()$query('url_link', initial_query)
  result <- .birdweather_env$connection$exec(query_exec$url_link,
                                             variables = base_variables) |>
    jsonlite::fromJSON(flatten = FALSE)

  if (!is.null(result$errors)) {
    message("API returned errors:")
    print(result$errors)
    return(data.table::data.table())
  }

  env_hist <- result$data$station$sensors$environmentHistory
  edges    <- env_hist$edges

  if (is.null(edges) || length(edges) == 0) {
    message("No environmental data found for station ", station_id)
    return(data.table::data.table())
  }

  all_pages    <- list(flatten_env(edges, station_id))
  has_next     <- env_hist$pageInfo$hasNextPage
  after_cursor <- env_hist$pageInfo$endCursor

  message("Fetched page 1 - ", nrow(edges), " readings")

  # -------------------------------------------------------
  # Paginate
  # -------------------------------------------------------
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

    all_pages[[page]] <- flatten_env(edges, station_id)
    has_next          <- env_hist$pageInfo$hasNextPage
    after_cursor      <- env_hist$pageInfo$endCursor

    message("Fetched page ", page, " - ", nrow(edges), " readings")
  }

  final <- data.table::rbindlist(all_pages, fill = TRUE)
  message("Done. Returning ", nrow(final), " environmental readings.")
  final
}


#' Get BirdWeather PUC Light Sensor Data
#'
#' Retrieves spectral light sensor readings from a BirdWeather PUC station.
#' Includes 8 spectral channels (f1-f8), clear light, and near-infrared.
#' Handles pagination automatically.
#'
#' @param station_id A single station ID (required)
#' @param from Start datetime in ISO8601 format (e.g. "2025-01-01T00:00:00.000Z")
#' @param to End datetime in ISO8601 format (e.g. "2025-01-02T00:00:00.000Z")
#' @param limit Maximum number of readings to return (default: NULL, returns all)
#'
#' @return A data.table with columns:
#'   station_id, timestamp, clear, nir, f1, f2, f3, f4, f5, f6, f7, f8
#' @export
#'
#' @examples
#' \dontrun{
#' connect_birdweather()
#'
#' light <- get_light_data(
#'   station_id = "1733",
#'   from       = "2025-05-01T00:00:00.000Z",
#'   to         = "2025-05-02T00:00:00.000Z"
#' )
#' }
get_light_data <- function(station_id = NULL,
                           from       = NULL,
                           to         = NULL,
                           limit      = NULL) {

  if (is.null(station_id)) {
    message("station_id is required for get_light_data().")
    return(data.table::data.table())
  }

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
    id    = as.character(station_id),
    first = as.integer(if (is.null(limit)) 250 else min(250, limit))
  )

  if (!is.null(from) && !is.null(to)) {
    base_variables$period <- list(from = from, to = to)
  }

  flatten_light <- function(edges, station_id) {
    node <- edges$node
    data.table::data.table(
      station_id = station_id,
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
    message("API returned errors:")
    print(result$errors)
    return(data.table::data.table())
  }

  light_hist <- result$data$station$sensors$lightHistory
  edges      <- light_hist$edges

  if (is.null(edges) || length(edges) == 0) {
    message("No light data found for station ", station_id)
    return(data.table::data.table())
  }

  all_pages    <- list(flatten_light(edges, station_id))
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

    all_pages[[page]] <- flatten_light(edges, station_id)
    has_next          <- light_hist$pageInfo$hasNextPage
    after_cursor      <- light_hist$pageInfo$endCursor

    message("Fetched page ", page, " - ", nrow(edges), " readings")
  }

  final <- data.table::rbindlist(all_pages, fill = TRUE)
  message("Done. Returning ", nrow(final), " light readings.")
  final
}
