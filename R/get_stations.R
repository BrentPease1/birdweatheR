#' Get BirdWeather Stations
#'
#' Retrieves public BirdWeather stations with optional filters.
#' Handles pagination automatically and returns a flat data.table.
#'
#' @param query Optional search string to filter stations by name (optional)
#' @param from Start datetime in ISO8601 format (optional)
#' @param to End datetime in ISO8601 format (optional)
#' @param ne Named list with lat and lon defining the north-east corner of a
#'   bounding box (optional). Must be used together with sw.
#' @param sw Named list with lat and lon defining the south-west corner of a
#'   bounding box (optional). Must be used together with ne.
#' @param limit Maximum total number of stations to return (default: NULL,
#'   returns all matching stations). Each page fetches 250 at a time.
#'
#' @return A flat data.table where each row is one station with columns:
#'   station_id, station_name, station_type, station_timezone,
#'   station_country, station_continent, station_state, station_location,
#'   station_lat, station_lon, location_privacy
#' @note The fields \code{latestDetectionAt} and \code{earliestDetectionAt}
#'   are not returned due to server-side performance limitations.
#' @export
#' @importFrom data.table data.table rbindlist
#'
#' @examples
#' \dontrun{
#' connect_birdweather()
#'
#' # Get all stations
#' stations <- get_stations()
#'
#' # Search by name
#' stations <- get_stations(query = "backyard")
#'
#' # Filter by bounding box
#' stations <- get_stations(
#'   ne = list(lat = 42.0, lon = -85.0),
#'   sw = list(lat = 36.0, lon = -96.0)
#' )
#' }
get_stations <- function(query = NULL,
                         from  = NULL,
                         to    = NULL,
                         ne    = NULL,
                         sw    = NULL,
                         limit = NULL) {

  if (is.null(.birdweather_env$connection)) {
    stop("No API connection found. Please run connect_birdweather() first.")
  }

  # -------------------------------------------------------
  # Build variables incrementally - only what is non-NULL
  # -------------------------------------------------------
  base_variables <- list(first = as.integer(if (is.null(limit)) 250 else min(250, limit)))

  if (!is.null(query))      base_variables$query  <- query
  if (!is.null(from) && !is.null(to)) {
    base_variables$period <- list(from = from, to = to)
  }
  if (!is.null(ne))         base_variables$ne     <- list(lat = ne$lat, lon = ne$lon)
  if (!is.null(sw))         base_variables$sw     <- list(lat = sw$lat, lon = sw$lon)

  # -------------------------------------------------------
  # Build query string dynamically
  # -------------------------------------------------------
  var_types <- c(
    first  = "$first: Int",
    query  = "$query: String",
    period = "$period: InputDuration",
    ne     = "$ne: InputLocation",
    sw     = "$sw: InputLocation"
  )

  arg_names <- c(
    first  = "first: $first",
    query  = "query: $query",
    period = "period: $period",
    ne     = "ne: $ne",
    sw     = "sw: $sw"
  )

  active             <- names(var_types)[names(var_types) %in% names(base_variables)]
  query_declarations <- paste(var_types[active], collapse = ",\n    ")
  query_arguments    <- paste(arg_names[active],  collapse = ",\n    ")

  build_query <- function(include_after = FALSE) {
    after_dec <- if (include_after) ",\n    $after: String" else ""
    after_arg <- if (include_after) ",\n    after: $after"  else ""

    sprintf('
      query stations(
        %s%s
      ) {
        stations(
          %s%s
        ) {
          nodes {
            id
            name
            type
            country
            continent
            state
            location
            locationPrivacy
            coords { lat lon }
          }
          pageInfo { hasNextPage endCursor }
          totalCount
        }
      }
    ', query_declarations, after_dec, query_arguments, after_arg)
  }

  initial_query   <- build_query(include_after = FALSE)
  following_query <- build_query(include_after = TRUE)

  # -------------------------------------------------------
  # Helper to flatten nodes
  # -------------------------------------------------------
  flatten_stations <- function(nodes) {
    data.table::data.table(
      station_id       = nodes$id,
      station_name     = trimws(nodes$name),
      station_type     = nodes$type,
      station_country  = nodes$country,
      station_continent= nodes$continent,
      station_state    = nodes$state,
      station_location = nodes$location,
      station_lat      = nodes$coords$lat,
      station_lon      = nodes$coords$lon,
      location_privacy = nodes$locationPrivacy
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

  nodes <- result$data$stations$nodes

  if (is.null(nodes) || nrow(nodes) == 0) {
    message("No stations found for the specified filters.")
    return(data.table::data.table())
  }

  all_pages    <- list(flatten_stations(nodes))
  has_next     <- result$data$stations$pageInfo$hasNextPage
  after_cursor <- result$data$stations$pageInfo$endCursor
  total        <- result$data$stations$totalCount

  message("Total stations matching filters: ", total)
  message("Fetched page 1 - ", nrow(nodes), " stations")

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

    nodes <- result$data$stations$nodes

    if (is.null(nodes) || nrow(nodes) == 0) {
      message("No data on page ", page, " - stopping.")
      break
    }

    all_pages[[page]] <- flatten_stations(nodes)
    has_next     <- result$data$stations$pageInfo$hasNextPage
    after_cursor <- result$data$stations$pageInfo$endCursor

    message("Fetched page ", page, " - ", nrow(nodes), " stations")
  }

  # -------------------------------------------------------
  # Bind and return
  # -------------------------------------------------------
  final <- data.table::rbindlist(all_pages, fill = TRUE)
  message("Done. Returning ", nrow(final), " stations.")
  final
}
