#' Get BirdWeather Daily Detection Counts
#'
#' Returns daily detection counts for a given time period. By default returns
#' one row per day with total detections. Optionally returns species-level
#' breakdown with one row per species per day.
#'
#' When \code{station_ids} is supplied, the function issues one API call per
#' station and tags every row with \code{station_id} so results can be
#' distinguished. Without \code{station_ids} the column is omitted.
#'
#' @param from Start datetime in ISO8601 format (e.g. "2025-01-01T00:00:00.000Z")
#' @param to End datetime in ISO8601 format (e.g. "2025-01-02T00:00:00.000Z")
#' @param station_ids Character vector of station IDs to filter on (optional)
#' @param species_ids Character vector of species IDs to filter on (optional)
#' @param by_species Logical. If FALSE (default) returns one row per day with
#'   total detections only. If TRUE returns one row per species per day.
#'
#' @return A data.table. When by_species = FALSE: station_id, date, day_of_year, daily_total.
#'   When by_species = TRUE: station_id, date, day_of_year, daily_total, species_id, count.
#'   If station_ids is NULL, station_id column is omitted.
#' @seealso \code{\link{get_counts}} for a single-row platform-wide snapshot,
#'  \code{\link{get_species_info}} to join readable names onto species_id values,
#'  \code{\link{get_detections}} for row-level detection data
#' @export
#'
#' @examples
#' \dontrun{
#' connect_birdweather()
#'
#' # Daily totals only
#' get_daily_detection_counts(
#'   from = "2025-05-01T00:00:00.000Z",
#'   to   = "2025-05-07T00:00:00.000Z"
#' )
#'
#' # Species-level breakdown, tagged by station
#' get_daily_detection_counts(
#'   from        = "2025-05-01T00:00:00.000Z",
#'   to          = "2025-05-07T00:00:00.000Z",
#'   station_ids = c("123", "456"),
#'   by_species  = TRUE
#' )
#' }
get_daily_detection_counts <- function(from        = NULL,
                                       to          = NULL,
                                       station_ids = NULL,
                                       species_ids = NULL,
                                       by_species  = FALSE) {

  if (is.null(.birdweather_env$connection)) {
    stop("No API connection found. Please run connect_birdweather() first.")
  }

  # Normalize date inputs - accepts strings, Date, POSIXct, lubridate, etc.
  from <- normalize_datetime(from, "from")
  to   <- normalize_datetime(to,   "to")

  # ---------------------------------------------------------------------------
  # Helper: issue one API call for a single station_id (or NULL for all)
  # ---------------------------------------------------------------------------
  .fetch_one <- function(station_id = NULL) {
    base_variables <- list()

    if (!is.null(from) && !is.null(to)) {
      base_variables$period <- list(from = from, to = to)
    }
    if (!is.null(station_id)) {
      base_variables$stationIds <- list(as.character(station_id))
    }
    if (!is.null(species_ids)) {
      base_variables$speciesIds <- as.list(as.character(species_ids))
    }

    var_types <- c(
      period     = "$period: InputDuration",
      stationIds = "$stationIds: [ID!]",
      speciesIds = "$speciesIds: [ID!]"
    )

    arg_names <- c(
      period     = "period: $period",
      stationIds = "stationIds: $stationIds",
      speciesIds = "speciesIds: $speciesIds"
    )

    active             <- names(var_types)[names(var_types) %in% names(base_variables)]
    query_declarations <- if (length(active) > 0) paste(var_types[active], collapse = ",\n    ") else ""
    query_arguments    <- if (length(active) > 0) paste(arg_names[active], collapse = ",\n    ") else ""

    dec_block <- if (nchar(query_declarations) > 0) sprintf("(\n    %s\n  )", query_declarations) else ""
    arg_block <- if (nchar(query_arguments)    > 0) sprintf("(\n    %s\n  )", query_arguments)    else ""

    counts_block <- if (isTRUE(by_species)) {
      '\n        counts {\n          count\n          speciesId\n        }'
    } else {
      ""
    }

    query <- sprintf('
    query dailyDetectionCounts%s {
      dailyDetectionCounts%s {
        date
        dayOfYear
        total%s
      }
    }
  ', dec_block, arg_block, counts_block)

    query_exec <- ghql::Query$new()$query('url_link', query)
    result <- .birdweather_env$connection$exec(
      query_exec$url_link,
      variables = if (length(base_variables) > 0) base_variables else NULL
    ) |>
      jsonlite::fromJSON(flatten = FALSE)

    if (!is.null(result$errors)) {
      message("API returned errors for station ", station_id, ": ",
              paste(result$errors$message, collapse = "; "))
      return(data.table::data.table())
    }

    daily <- result$data$dailyDetectionCounts

    if (is.null(daily) || !length(daily)) {
      return(data.table::data.table())
    }

    # Simple daily totals
    if (!isTRUE(by_species)) {
      dt <- data.table::data.table(
        date        = daily$date,
        day_of_year = daily$dayOfYear,
        daily_total = daily$total
      )
      if (!is.null(station_id)) dt[, station_id := station_id]
      return(dt)
    }

    # Species-level breakdown
    dt <- data.table::rbindlist(
      lapply(seq_len(nrow(daily)), function(i) {
        row_dt <- data.table::as.data.table(daily$counts[[i]])
        data.table::setnames(row_dt, c("speciesId", "count"), c("species_id", "count"))
        row_dt[, `:=`(
          date        = daily$date[i],
          day_of_year = daily$dayOfYear[i],
          daily_total = daily$total[i]
        )]
        row_dt
      })
    )
    if (!is.null(station_id)) dt[, station_id := station_id]
    dt
  }

  # ---------------------------------------------------------------------------
  # If station_ids supplied, loop one call per station so rows can be tagged
  # ---------------------------------------------------------------------------
  if (!is.null(station_ids)) {
    all_station_ids <- as.character(station_ids)
    n_stations      <- length(all_station_ids)

    message("Fetching daily detection counts for ", n_stations, " station",
            if (n_stations > 1) "s" else "", "...")

    page_times  <- numeric(0)
    result_list <- vector("list", n_stations)

    for (i in seq_along(all_station_ids)) {
      t_start          <- proc.time()[["elapsed"]]
      result_list[[i]] <- .fetch_one(all_station_ids[i])
      elapsed          <- proc.time()[["elapsed"]] - t_start
      page_times       <- c(page_times, elapsed)

      stations_remaining <- n_stations - i
      if (stations_remaining > 0) {
        avg_time <- mean(page_times)
        eta_secs <- stations_remaining * avg_time
        eta_str  <- paste0(" - ~", format_seconds(eta_secs), " remaining")
      } else {
        eta_str <- ""
      }

      message("  Station ", i, "/", n_stations,
              " (", all_station_ids[i], ")",
              " - ", format(nrow(result_list[[i]]), big.mark = ","), " rows",
              eta_str)
    }

    out <- data.table::rbindlist(result_list, fill = TRUE)

    if (!nrow(out)) {
      message("No detections found for the specified filters.")
      return(data.table::data.table())
    }

    col_order <- if (isTRUE(by_species)) {
      c("station_id", "date", "day_of_year", "daily_total", "species_id", "count")
    } else {
      c("station_id", "date", "day_of_year", "daily_total")
    }
    data.table::setcolorder(out, intersect(col_order, names(out)))
    message("Done. Returning ", format(nrow(out), big.mark = ","), " rows across ",
            n_stations, " station", if (n_stations > 1) "s" else "", ".")
    return(out)
  }

  # ---------------------------------------------------------------------------
  # No station_ids - single call, no station_id column
  # ---------------------------------------------------------------------------
  out <- .fetch_one(station_id = NULL)

  if (!nrow(out)) {
    message("No detections found for the specified filters.")
    return(data.table::data.table())
  }

  if (isTRUE(by_species)) {
    data.table::setcolorder(
      out,
      intersect(c("date", "day_of_year", "daily_total", "species_id", "count"), names(out))
    )
  }

  out
}
