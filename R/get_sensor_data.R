#' Get BirdWeather PUC Environmental Sensor Data
#'
#' Retrieves environmental sensor readings from one or more BirdWeather PUC
#' stations. Includes temperature, humidity, barometric pressure, air quality,
#' eCO2, VOC, and sound pressure level. Handles pagination automatically.
#'
#' @param station_id A single station ID or character vector of station IDs (required)
#' @param from Start datetime in ISO8601 format (e.g. "2025-01-01T00:00:00.000Z").
#' BirdWeather API resolves to calendar days; sub-day filtering is done through package.
#' @param to End datetime in ISO8601 format (e.g. "2025-01-02T00:00:00.000Z")
#' #' BirdWeather API resolves to calendar days; sub-day filtering is done through package.
#' @param limit Maximum number of readings to return per station (default: NULL,
#'   returns all). When multiple station IDs are provided, limit applies to each
#'   station individually.
#' @param max_retries Maximum number of retry attempts per page on transient
#'   errors (default: 5). Retries use exponential backoff with jitter.
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
get_environment_data <- function(station_id  = NULL,
                                 from        = NULL,
                                 to          = NULL,
                                 limit       = NULL,
                                 max_retries = 5) {

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
              totalCount
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
              totalCount
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
    result     <- fetch_page_with_retry(query_exec, base_variables, max_retries = max_retries)

    env_hist <- result$data$station$sensors$environmentHistory
    edges    <- env_hist$edges

    if (is.null(edges) || length(edges) == 0) {
      message("No environmental data found for station ", sid)
      return(NULL)
    }

    total          <- env_hist$totalCount
    total_to_fetch <- if (is.null(limit)) total else min(total, limit)
    n_pages_total  <- ceiling(total_to_fetch / 250)

    if (n_pages_total > 1) {
      est_secs <- (n_pages_total - 1) * 1.5
      message("  Total readings: ", format(total, big.mark = ","),
              " - Estimated download time: ~", format_seconds(est_secs),
              " (", n_pages_total, " pages of 250)")
    }

    all_pages    <- list(flatten_env(edges, sid))
    has_next     <- env_hist$pageInfo$hasNextPage
    after_cursor <- env_hist$pageInfo$endCursor

    message("  Fetched page 1/", n_pages_total, " - ",
            format(nrow(edges), big.mark = ","), " readings")

    page       <- 1
    page_times <- numeric(0)

    while (isTRUE(has_next) && (is.null(limit) || sum(sapply(all_pages, nrow)) < limit)) {

      page      <- page + 1
      remaining <- if (is.null(limit)) 250 else min(250, limit - sum(sapply(all_pages, nrow)))

      page_variables <- c(
        base_variables,
        list(first = as.integer(remaining), after = after_cursor)
      )

      query_exec <- ghql::Query$new()$query('url_link', following_query)

      t0     <- proc.time()[["elapsed"]]
      result <- fetch_page_with_retry(query_exec, page_variables, max_retries = max_retries)
      t1     <- proc.time()[["elapsed"]]

      page_times <- c(page_times, t1 - t0)

      env_hist <- result$data$station$sensors$environmentHistory
      edges    <- env_hist$edges

      if (is.null(edges) || length(edges) == 0) {
        message("  No data on page ", page, " - stopping.")
        break
      }

      all_pages[[page]] <- flatten_env(edges, sid)
      has_next          <- env_hist$pageInfo$hasNextPage
      after_cursor      <- env_hist$pageInfo$endCursor

      fetched_so_far  <- sum(sapply(all_pages, nrow))
      pct_done        <- round(fetched_so_far / total_to_fetch * 100)
      pages_remaining <- n_pages_total - page
      avg_page_time   <- mean(page_times)
      eta_secs        <- pages_remaining * avg_page_time

      eta_str <- if (pages_remaining > 0) {
        paste0(" - ~", format_seconds(eta_secs), " remaining")
      } else {
        ""
      }

      message("  Fetched page ", page, "/", n_pages_total,
              " (", format(fetched_so_far, big.mark = ","),
              " / ", format(total_to_fetch, big.mark = ","),
              ", ", pct_done, "%)", eta_str)
    }

    out <- data.table::rbindlist(all_pages, fill = TRUE)
    if (!is.null(from) && !is.null(to)) {
      from_posix <- as.POSIXct(sub("Z$", "", from), format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
      to_posix   <- as.POSIXct(sub("Z$", "", to),   format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
      ts_posix   <- as.POSIXct(sub("Z$", "", out$timestamp), format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
      out        <- out[ts_posix >= from_posix & ts_posix <= to_posix]
    }
    out
  }

  # -------------------------------------------------------
  # Loop over stations if multiple provided
  # -------------------------------------------------------
  station_id <- as.character(station_id)

  if (length(station_id) == 1) {
    result <- .fetch_env(station_id)
    if (is.null(result)) return(data.table::data.table())
    message("Done. Returning ", format(nrow(result), big.mark = ","),
            " environmental readings.")
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
  message("Done. Returning ", format(nrow(final), big.mark = ","),
          " environmental readings across ", length(station_id), " stations.")
  final
}


#' Get BirdWeather PUC Light Sensor Data
#'
#' Retrieves spectral light sensor readings from one or more BirdWeather PUC
#' stations. Includes 8 spectral channels (f1-f8), clear light, and
#' near-infrared. Handles pagination automatically.
#'
#' @param station_id A single station ID or character vector of station IDs (required)
#' @param from Start datetime in ISO8601 format (e.g. "2025-01-01T00:00:00.000Z").
#' BirdWeather API resolves to calendar days; sub-day filtering is done through package.
#' @param to End datetime in ISO8601 format (e.g. "2025-01-02T00:00:00.000Z")
#' #' BirdWeather API resolves to calendar days; sub-day filtering is done through package.
#' @param limit Maximum number of readings to return per station (default: NULL,
#'   returns all). When multiple station IDs are provided, limit applies to each
#'   station individually.
#' @param max_retries Maximum number of retry attempts per page on transient
#'   errors (default: 5). Retries use exponential backoff with jitter.
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
get_light_data <- function(station_id  = NULL,
                           from        = NULL,
                           to          = NULL,
                           limit       = NULL,
                           max_retries = 5) {

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
              totalCount
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
              totalCount
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
    result     <- fetch_page_with_retry(query_exec, base_variables, max_retries = max_retries)

    light_hist <- result$data$station$sensors$lightHistory
    edges      <- light_hist$edges

    if (is.null(edges) || length(edges) == 0) {
      message("No light data found for station ", sid)
      return(NULL)
    }

    total          <- light_hist$totalCount
    total_to_fetch <- if (is.null(limit)) total else min(total, limit)
    n_pages_total  <- ceiling(total_to_fetch / 250)

    if (n_pages_total > 1) {
      est_secs <- (n_pages_total - 1) * 1.5
      message("  Total readings: ", format(total, big.mark = ","),
              " - Estimated download time: ~", format_seconds(est_secs),
              " (", n_pages_total, " pages of 250)")
    }

    all_pages    <- list(flatten_light(edges, sid))
    has_next     <- light_hist$pageInfo$hasNextPage
    after_cursor <- light_hist$pageInfo$endCursor

    message("  Fetched page 1/", n_pages_total, " - ",
            format(nrow(edges), big.mark = ","), " readings")

    page       <- 1
    page_times <- numeric(0)

    while (isTRUE(has_next) && (is.null(limit) || sum(sapply(all_pages, nrow)) < limit)) {

      page      <- page + 1
      remaining <- if (is.null(limit)) 250 else min(250, limit - sum(sapply(all_pages, nrow)))

      page_variables <- c(
        base_variables,
        list(first = as.integer(remaining), after = after_cursor)
      )

      query_exec <- ghql::Query$new()$query('url_link', following_query)

      t0     <- proc.time()[["elapsed"]]
      result <- fetch_page_with_retry(query_exec, page_variables, max_retries = max_retries)
      t1     <- proc.time()[["elapsed"]]

      page_times <- c(page_times, t1 - t0)

      light_hist <- result$data$station$sensors$lightHistory
      edges      <- light_hist$edges

      if (is.null(edges) || length(edges) == 0) {
        message("  No data on page ", page, " - stopping.")
        break
      }

      all_pages[[page]] <- flatten_light(edges, sid)
      has_next          <- light_hist$pageInfo$hasNextPage
      after_cursor      <- light_hist$pageInfo$endCursor

      fetched_so_far  <- sum(sapply(all_pages, nrow))
      pct_done        <- round(fetched_so_far / total_to_fetch * 100)
      pages_remaining <- n_pages_total - page
      avg_page_time   <- mean(page_times)
      eta_secs        <- pages_remaining * avg_page_time

      eta_str <- if (pages_remaining > 0) {
        paste0(" - ~", format_seconds(eta_secs), " remaining")
      } else {
        ""
      }

      message("  Fetched page ", page, "/", n_pages_total,
              " (", format(fetched_so_far, big.mark = ","),
              " / ", format(total_to_fetch, big.mark = ","),
              ", ", pct_done, "%)", eta_str)
    }

    out <- data.table::rbindlist(all_pages, fill = TRUE)
    if (!is.null(from) && !is.null(to)) {
      from_posix <- as.POSIXct(sub("Z$", "", from), format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
      to_posix   <- as.POSIXct(sub("Z$", "", to),   format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
      ts_posix   <- as.POSIXct(sub("Z$", "", out$timestamp), format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
      out        <- out[ts_posix >= from_posix & ts_posix <= to_posix]
    }
    out
  }

  # -------------------------------------------------------
  # Loop over stations if multiple provided
  # -------------------------------------------------------
  station_id <- as.character(station_id)

  if (length(station_id) == 1) {
    result <- .fetch_light(station_id)
    if (is.null(result)) return(data.table::data.table())
    message("Done. Returning ", format(nrow(result), big.mark = ","), " light readings.")
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
  message("Done. Returning ", format(nrow(final), big.mark = ","),
          " light readings across ", length(station_id), " stations.")
  final
}
