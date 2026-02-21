#' Get BirdWeather Daily Detection Counts
#'
#' Returns daily detection counts for a given time period. By default returns
#' one row per day with total detections. Optionally returns species-level
#' breakdown with one row per species per day.
#'
#' @param from Start datetime in ISO8601 format (e.g. "2025-01-01T00:00:00.000Z")
#' @param to End datetime in ISO8601 format (e.g. "2025-01-02T00:00:00.000Z")
#' @param station_ids Character vector of station IDs to filter on (optional)
#' @param species_ids Character vector of species IDs to filter on (optional)
#' @param by_species Logical. If FALSE (default) returns one row per day with
#'   total detections only. If TRUE returns one row per species per day.
#'
#' @return A data.table. When by_species = FALSE: date, day_of_year, daily_total.
#'   When by_species = TRUE: date, day_of_year, daily_total, species_id, count.
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
#' # Species-level breakdown
#' get_daily_detection_counts(
#'   from       = "2025-05-01T00:00:00.000Z",
#'   to         = "2025-05-07T00:00:00.000Z",
#'   by_species = TRUE
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

  base_variables <- list()

  if (!is.null(from) && !is.null(to)) {
    base_variables$period <- list(from = from, to = to)
  }
  if (!is.null(station_ids)) {
    base_variables$stationIds <- as.list(as.character(station_ids))
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

  # Only request counts block if by_species = TRUE
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
  result <- .birdweather_env$connection$exec(query_exec$url_link,
                                             variables = if (length(base_variables) > 0) base_variables else NULL) |>
    jsonlite::fromJSON(flatten = FALSE)

  if (!is.null(result$errors)) {
    message("API returned errors:")
    print(result$errors)
    return(data.table::data.table())
  }

  daily <- result$data$dailyDetectionCounts

  if (is.null(daily) || nrow(daily) == 0) {
    message("No data found for the specified filters.")
    return(data.table::data.table())
  }

  # Simple daily totals
  if (!isTRUE(by_species)) {
    return(data.table::data.table(
      date        = daily$date,
      day_of_year = daily$dayOfYear,
      daily_total = daily$total
    ))
  }

  # Species-level breakdown
  data.table::rbindlist(
    lapply(seq_len(nrow(daily)), function(i) {
      dt <- data.table::as.data.table(daily$counts[[i]])
      dt[, `:=`(
        date        = daily$date[i],
        day_of_year = daily$dayOfYear[i],
        daily_total = daily$total[i]
      )]
      data.table::setcolorder(dt, c("date", "day_of_year", "daily_total", "speciesId", "count"))
      dt
    })
  )
}
