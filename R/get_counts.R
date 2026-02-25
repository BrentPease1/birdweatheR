#' Get BirdWeather Summary Counts
#'
#' Returns a single-row summary of detections, species, stations, and BirdNet
#' detections for a given time period. Useful as a quick platform-wide or
#' regional snapshot before pulling raw detections.
#'
#' For finer-grained summaries by species or station over time, see
#' \code{\link{get_daily_detection_counts}} and \code{\link{get_detections}}.
#'
#' @param from Start datetime in ISO8601 format (e.g. "2025-01-01T00:00:00.000Z")
#' @param to End datetime in ISO8601 format (e.g. "2025-01-02T00:00:00.000Z")
#' @param station_ids Character vector of station IDs to filter on (optional)
#' @param station_types Character vector of station types to filter on (optional).
#'   Known types include "puc", "birdnetpi", and "app".
#' @param species_id A single species ID to filter on (optional). Use
#'   \code{\link{find_species}} to look up species IDs.
#' @param ne Named list with lat and lon defining the north-east corner of a
#'   bounding box (optional). Must be used together with sw.
#'   Example: list(lat = 42.0, lon = -85.0)
#' @param sw Named list with lat and lon defining the south-west corner of a
#'   bounding box (optional). Must be used together with ne.
#'   Example: list(lat = 36.0, lon = -96.0)
#'
#' @return A single-row data.table with columns:
#'   detections, species, stations
#' @export
#'
#' @examples
#' \dontrun{
#' connect_birdweather()
#'
#' # Platform-wide snapshot
#' get_counts(
#'   from = "2025-05-01T00:00:00.000Z",
#'   to   = "2025-05-02T00:00:00.000Z"
#' )
#'
#' # Regional snapshot using bounding box
#' get_counts(
#'   from = "2025-05-01T00:00:00.000Z",
#'   to   = "2025-05-02T00:00:00.000Z",
#'   ne   = list(lat = 42.0, lon = -85.0),
#'   sw   = list(lat = 36.0, lon = -96.0)
#' )
#'
#' # PUC stations only
#' get_counts(
#'   from          = "2025-05-01T00:00:00.000Z",
#'   to            = "2025-05-02T00:00:00.000Z",
#'   station_types = "puc"
#' )
#' }
get_counts <- function(from          = NULL,
                       to            = NULL,
                       station_ids   = NULL,
                       station_types = NULL,
                       species_id    = NULL,
                       ne            = NULL,
                       sw            = NULL) {

  if (is.null(.birdweather_env$connection)) {
    stop("No API connection found. Please run connect_birdweather() first.")
  }

  base_variables <- list()

  if (!is.null(from) && !is.null(to)) {
    base_variables$period <- list(from = from, to = to)
  }
  if (!is.null(station_ids))   base_variables$stationIds   <- as.list(as.character(station_ids))
  if (!is.null(station_types)) base_variables$stationTypes <- as.list(station_types)
  if (!is.null(species_id))    base_variables$speciesId    <- as.character(species_id)
  if (!is.null(ne))            base_variables$ne           <- list(lat = ne$lat, lon = ne$lon)
  if (!is.null(sw))            base_variables$sw           <- list(lat = sw$lat, lon = sw$lon)

  var_types <- c(
    period       = "$period: InputDuration",
    stationIds   = "$stationIds: [ID!]",
    stationTypes = "$stationTypes: [String!]",
    speciesId    = "$speciesId: ID",
    ne           = "$ne: InputLocation",
    sw           = "$sw: InputLocation"
  )

  arg_names <- c(
    period       = "period: $period",
    stationIds   = "stationIds: $stationIds",
    stationTypes = "stationTypes: $stationTypes",
    speciesId    = "speciesId: $speciesId",
    ne           = "ne: $ne",
    sw           = "sw: $sw"
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
  result <- .birdweather_env$connection$exec(
              query_exec$url_link,
              variables = if (length(base_variables) > 0) base_variables else NULL) |>
    jsonlite::fromJSON(flatten = FALSE)

  if (!is.null(result$errors)) {
    message("API returned errors:")
    print(result$errors)
    return(data.table::data.table())
  }

  data.table::as.data.table(result$data$counts)
}
