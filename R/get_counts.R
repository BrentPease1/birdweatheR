#' Get BirdWeather Summary Counts
#'
#' Returns a single-row summary of detections, species, stations, and BirdNet
#' detections for a given time period. Useful for quick snapshots.
#'
#' @param from Start datetime in ISO8601 format (e.g. "2025-01-01T00:00:00.000Z")
#' @param to End datetime in ISO8601 format (e.g. "2025-01-02T00:00:00.000Z")
#' @param station_ids Character vector of station IDs to filter on (optional)
#'
#' @return A single-row data.table with columns:
#'   detections, species, stations
#' @export
#'
#' @examples
#' \dontrun{
#' connect_birdweather()
#' get_counts(
#'   from = "2025-05-01T00:00:00.000Z",
#'   to   = "2025-05-02T00:00:00.000Z"
#' )
#' }
get_counts <- function(from        = NULL,
                       to          = NULL,
                       station_ids = NULL) {

  base_variables <- list()

  if (!is.null(from) && !is.null(to)) {
    base_variables$period <- list(from = from, to = to)
  }
  if (!is.null(station_ids)) {
    base_variables$stationIds <- as.list(as.character(station_ids))
  }

  var_types <- c(
    period     = "$period: InputDuration",
    stationIds = "$stationIds: [ID!]"
  )

  arg_names <- c(
    period     = "period: $period",
    stationIds = "stationIds: $stationIds"
  )

  active             <- names(var_types)[names(var_types) %in% names(base_variables)]
  query_declarations <- if (length(active) > 0) paste(var_types[active], collapse = ",\n    ") else ""
  query_arguments    <- if (length(active) > 0) paste(arg_names[active], collapse = ",\n    ") else ""

  dec_block <- if (nchar(query_declarations) > 0) sprintf("(\n    %s\n  )", query_declarations) else ""
  arg_block <- if (nchar(query_arguments)    > 0) sprintf("(\n    %s\n  )", query_arguments)    else ""

  query <- sprintf('
    query counts%s {
      counts%s {
        detections
        species
        stations
      }
    }
  ', dec_block, arg_block)

  query_exec <- ghql::Query$new()$query('url_link', query)
  result <- .birdweather_env$connection$exec(query_exec$url_link,
                                             variables = if (length(base_variables) > 0) base_variables else NULL) |>
    jsonlite::fromJSON(flatten = FALSE)

  if (!is.null(result$errors)) {
    message("API returned errors:")
    print(result$errors)
    return(data.table::data.table())
  }

  data.table::as.data.table(result$data$counts)
}
