#' Get BirdWeather Time of Day Detection Counts
#'
#' Returns detection counts binned by time of day for a given species.
#' Each row is one 30-minute time bin. Useful for visualizing daily
#' activity patterns like dawn chorus or nocturnal behavior.
#'
#' @param species_id A single species ID (required). Use
#'   \code{\link{find_species}} to look up species IDs.
#' @param from Start datetime in ISO8601 format (e.g. "2025-01-01T00:00:00.000Z")
#' @param to End datetime in ISO8601 format (e.g. "2025-01-02T00:00:00.000Z")
#' @param station_ids Character vector of station IDs to filter on (optional)
#' @param confidence_gte Minimum (>=) confidence threshold as a float (optional)
#' @param ne Named list with lat and lon defining the north-east corner of a
#'   bounding box (optional). Must be used together with sw.
#'   Example: list(lat = 42.0, lon = -85.0)
#' @param sw Named list with lat and lon defining the south-west corner of a
#'   bounding box (optional). Must be used together with ne.
#'   Example: list(lat = 36.0, lon = -96.0)
#' @param time_of_day_gte Minimum (>=) time of day as a fractional hour
#'   (e.g. 6.0 = 6:00am). Useful for subsetting to dawn or dusk windows (optional)
#' @param time_of_day_lte Maximum (<=) time of day as a fractional hour (optional)
#' @param by_station Logical. If TRUE, returns results grouped by station_id
#'   by making one API call per station and combining results. Requires
#'   station_ids to be provided. Default FALSE.
#' @param fill_zeros Logical. Used in combination with by_station. If TRUE, fills
#' zeros for stations/hours that did not detect focal species. Requires
#'   station_ids to be provided. Default FALSE.
#'
#' @return A data.table with columns:
#'   species_id, hour, count
#'   where hour is a fractional hour (e.g. 6.5 = 6:30am).
#'   If by_station = TRUE, an additional station_id column is included.
#' @export
#' @note This endpoint may only return data for frequently detected species.
#'   If no data is returned, try a more common species or a longer time period.
#'
#' @examples
#' \dontrun{
#' connect_birdweather()
#'
#' # American Robin time of day activity
#' robin_id <- find_species("American Robin")$species_id
#' get_tod_counts(
#'   species_id = robin_id,
#'   from       = "2025-05-01T00:00:00.000Z",
#'   to         = "2025-05-31T00:00:00.000Z"
#' )
#'
#' # Dawn window only (5am - 9am)
#' get_tod_counts(
#'   species_id       = robin_id,
#'   from             = "2025-05-01T00:00:00.000Z",
#'   to               = "2025-05-31T00:00:00.000Z",
#'   time_of_day_gte  = 5.0,
#'   time_of_day_lte  = 9.0
#' )
#'
#' # Regional activity using bounding box
#' get_tod_counts(
#'   species_id = robin_id,
#'   from       = "2025-05-01T00:00:00.000Z",
#'   to         = "2025-05-31T00:00:00.000Z",
#'   ne         = list(lat = 42.0, lon = -85.0),
#'   sw         = list(lat = 36.0, lon = -96.0)
#' )
#'
#' # Per-station breakdown
#' get_tod_counts(
#'   species_id  = robin_id,
#'   from        = "2025-05-01T00:00:00.000Z",
#'   to          = "2025-05-31T00:00:00.000Z",
#'   station_ids = c("1733", "2522"),
#'   by_station  = TRUE
#' )
#' }
get_tod_counts <- function(species_id      = NULL,
                           from            = NULL,
                           to              = NULL,
                           station_ids     = NULL,
                           confidence_gte  = NULL,
                           ne              = NULL,
                           sw              = NULL,
                           time_of_day_gte = NULL,
                           time_of_day_lte = NULL,
                           by_station      = FALSE,
                           fill_zeros      = FALSE) {

  if (is.null(.birdweather_env$connection)) {
    stop("No API connection found. Please run connect_birdweather() first.")
  }

  # Validate date format
  if (!is.null(from) && !grepl("^\\d{4}-\\d{2}-\\d{2}T", from)) {
    stop("'from' must be in ISO8601 format with zero-padded month and day ",
         "(e.g. '2025-05-01T00:00:00.000Z'). Got: ", from)
  }
  if (!is.null(to) && !grepl("^\\d{4}-\\d{2}-\\d{2}T", to)) {
    stop("'to' must be in ISO8601 format with zero-padded month and day ",
         "(e.g. '2025-05-07T00:00:00.000Z'). Got: ", to)
  }

  if (is.null(species_id)) {
    stop("species_id is required for get_tod_counts(). ",
         "Use find_species() to look up species IDs.")
  }

  if (isTRUE(by_station) && is.null(station_ids)) {
    stop("station_ids must be provided when by_station = TRUE.")
  }

  # -------------------------------------------------------
  # Internal helper: single API call for one set of filters
  # -------------------------------------------------------
  .fetch_tod <- function(sid_filter = NULL) {

    base_variables <- list(speciesId = as.character(species_id))

    if (!is.null(from) && !is.null(to)) {
      base_variables$period <- list(from = from, to = to)
    }
    if (!is.null(sid_filter))     base_variables$stationIds    <- as.list(as.character(sid_filter))
    if (!is.null(confidence_gte)) base_variables$confidenceGte <- confidence_gte
    if (!is.null(ne))             base_variables$ne            <- list(lat = ne$lat, lon = ne$lon)
    if (!is.null(sw))             base_variables$sw            <- list(lat = sw$lat, lon = sw$lon)
    if (!is.null(time_of_day_gte)) base_variables$timeOfDayGte <- as.integer(time_of_day_gte * 2)
    if (!is.null(time_of_day_lte)) base_variables$timeOfDayLte <- as.integer(time_of_day_lte * 2)

    var_types <- c(
      speciesId     = "$speciesId: ID",
      period        = "$period: InputDuration",
      stationIds    = "$stationIds: [ID!]",
      confidenceGte = "$confidenceGte: Float",
      ne            = "$ne: InputLocation",
      sw            = "$sw: InputLocation",
      timeOfDayGte  = "$timeOfDayGte: Int",
      timeOfDayLte  = "$timeOfDayLte: Int"
    )

    arg_names <- c(
      speciesId     = "speciesId: $speciesId",
      period        = "period: $period",
      stationIds    = "stationIds: $stationIds",
      confidenceGte = "confidenceGte: $confidenceGte",
      ne            = "ne: $ne",
      sw            = "sw: $sw",
      timeOfDayGte  = "timeOfDayGte: $timeOfDayGte",
      timeOfDayLte  = "timeOfDayLte: $timeOfDayLte"
    )

    active             <- names(var_types)[names(var_types) %in% names(base_variables)]
    query_declarations <- paste(var_types[active], collapse = ",\n    ")
    query_arguments    <- paste(arg_names[active],  collapse = ",\n    ")

    query <- sprintf('
      query timeOfDayDetectionCounts(
        %s
      ) {
        timeOfDayDetectionCounts(
          %s
        ) {
          speciesId
          count
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
      return(NULL)
    }

    tod <- result$data$timeOfDayDetectionCounts

    if (is.null(tod) || length(tod) == 0 || is.null(tod$bins[[1]])) {
      return(NULL)
    }

    bins <- data.table::as.data.table(tod$bins[[1]])
    data.table::setnames(bins, c("key", "count"), c("hour", "count"))
    bins[, species_id := tod$speciesId[1]]
    bins
  }

  # -------------------------------------------------------
  # by_station: loop over each station, rbindlist results
  # -------------------------------------------------------
  if (isTRUE(by_station)) {

    results <- lapply(seq_along(station_ids), function(i) {
      message("Fetching TOD counts for station ", i, "/", length(station_ids), "...")
      dt <- .fetch_tod(sid_filter = station_ids[i])
      if (!is.null(dt)) dt[, station_id := station_ids[i]]
      dt
    })

    results <- results[!sapply(results, is.null)]

    if (length(results) == 0) {
      message("No time of day data found for any of the specified stations.")
      return(data.table::data.table())
    }

    final <- data.table::rbindlist(results, fill = TRUE)
    data.table::setcolorder(final, c("station_id", "species_id", "hour", "count"))

    total_count <- sum(final$count, na.rm = TRUE)
    if (total_count < 100) {
      warning("Fewer than 100 total detections found across all stations. ",
              "Time-of-day pattern may not be reliable.")
    }

    if (isTRUE(fill_zeros)) {
      all_combos <- data.table::CJ(
        station_id = unique(final$station_id),
        hour       = seq(0, 23.5, by = 0.5)
      )
      final <- merge(all_combos, final, by = c("station_id", "hour"), all.x = TRUE)
      final[is.na(count),      count      := 0L]
      sid <- as.character(species_id)
      final[is.na(species_id), species_id := sid]
    }

    data.table::setcolorder(final, c("station_id", "species_id", "hour", "count"))
    return(final)
  }

  # -------------------------------------------------------
  # Default: single aggregated call
  # -------------------------------------------------------
  final <- .fetch_tod(sid_filter = station_ids)

  if (is.null(final)) {
    message("No time of day data found for species ", species_id, ". ",
            "This endpoint may only return data for frequently detected species.")
    return(data.table::data.table())
  }

  data.table::setcolorder(final, c("species_id", "hour", "count"))

  if (sum(final$count, na.rm = TRUE) < 100) {
    warning("Fewer than 100 detections found for this species. ",
            "Time-of-day pattern may not be reliable.")
  }

  final
}
