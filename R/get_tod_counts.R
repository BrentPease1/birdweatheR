#' Get BirdWeather Time of Day Detection Counts
#'
#' Returns detection counts binned by time of day for a given species.
#' Each row is one 30-minute time bin. Useful for visualizing daily
#' activity patterns like dawn chorus or nocturnal behavior.
#'
#' @param species_id A single species ID (required)
#' @param from Start datetime in ISO8601 format (e.g. "2025-01-01T00:00:00.000Z")
#' @param to End datetime in ISO8601 format (e.g. "2025-01-02T00:00:00.000Z")
#' @param station_ids Character vector of station IDs to filter on (optional)
#' @param confidence_gte Minimum confidence threshold as a float (optional)
#'
#' @return A data.table with columns:
#'   species_id, hour, count
#'   where hour is a fractional hour (e.g. 6.5 = 6:30am)
#' @export
#'
#' @examples
#' \dontrun{
#' connect_birdweather()
#'
#' # American Robin time of day activity
#' get_tod_counts(
#'   species_id = "123",
#'   from       = "2025-05-01T00:00:00.000Z",
#'   to         = "2025-05-07T00:00:00.000Z"
#' )
#' }
get_tod_counts <- function(species_id     = NULL,
                           from           = NULL,
                           to             = NULL,
                           station_ids    = NULL,
                           confidence_gte = NULL) {

  if (is.null(.birdweather_env$connection)) {
    stop("No API connection found. Please run connect_birdweather() first.")
  }

  if (is.null(species_id)) {
    message("species_id is required for get_tod_counts().")
    return(data.table::data.table())
  }

  base_variables <- list(speciesId = as.character(species_id))

  if (!is.null(from) && !is.null(to)) {
    base_variables$period <- list(from = from, to = to)
  }
  if (!is.null(station_ids)) {
    base_variables$stationIds <- as.list(as.character(station_ids))
  }
  if (!is.null(confidence_gte)) {
    base_variables$confidenceGte <- confidence_gte
  }

  var_types <- c(
    speciesId     = "$speciesId: ID",
    period        = "$period: InputDuration",
    stationIds    = "$stationIds: [ID!]",
    confidenceGte = "$confidenceGte: Float"
  )

  arg_names <- c(
    speciesId     = "speciesId: $speciesId",
    period        = "period: $period",
    stationIds    = "stationIds: $stationIds",
    confidenceGte = "confidenceGte: $confidenceGte"
  )

  active             <- names(var_types)[names(var_types) %in% names(base_variables)]
  query_declarations <- paste(var_types[active], collapse = ",\n    ")
  query_arguments    <- paste(arg_names[active], collapse = ",\n    ")

  query <- sprintf('
    query timeOfDayDetectionCounts(
      %s
    ) {
      timeOfDayDetectionCounts(
        %s
      ) {
        speciesId
        bins {
          key
          count
        }
      }
    }
  ', query_declarations, query_arguments)

  query_exec <- ghql::Query$new()$query('url_link', query)
  result <- .birdweather_env$connection$exec(query_exec$url_link,
                                             variables = base_variables) |>
    jsonlite::fromJSON(flatten = FALSE)

  if (!is.null(result$errors)) {
    message("API returned errors:")
    print(result$errors)
    return(data.table::data.table())
  }

  tod <- result$data$timeOfDayDetectionCounts

  if (is.null(tod) || length(tod) == 0) {
    message("No time of day data found for the specified filters.")
    return(data.table::data.table())
  }

  bins <- data.table::as.data.table(tod$bins[[1]])
  data.table::setnames(bins, c("key", "count"), c("hour", "count"))
  bins[, species_id := tod$speciesId[1]]
  data.table::setcolorder(bins, c("species_id", "hour", "count"))
  bins
}
