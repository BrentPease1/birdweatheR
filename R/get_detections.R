#' Get BirdWeather Detections
#'
#' Retrieves bird detections from the BirdWeather API with optional filters.
#' Handles pagination automatically up to the specified limit. Returns a fully
#' flat data.table with all nested fields (coords, species, station) expanded
#' into individual columns.
#'
#' @param from Start datetime as a string in ISO8601 format
#'   (e.g. "2025-01-01T00:00:00.000Z"). Defaults to 24 hours ago if NULL.
#' @param to End datetime as a string in ISO8601 format
#'   (e.g. "2025-01-02T00:00:00.000Z"). Defaults to now if NULL.
#' @param station_ids Character vector of station IDs to filter on (optional)
#' @param station_types Character vector of station types to filter on (optional).
#'   Known types include "puc" (BirdWeather PUC units), "birdnetpi"
#'   (Raspberry Pi-based stations), and "app" (mobile app detections).
#' @param species_ids Character vector of species IDs to filter on (optional)
#' @param species_names Character vector of species common or scientific names
#'   to filter on (optional). Will be resolved to IDs via find_species().
#'   If a name matches multiple species, all matches are printed and the
#'   user is prompted to rerun with a more specific name.
#' @param continents Character vector of continents to filter on (optional)
#' @param countries Character vector of countries to filter on (optional)
#' @param confidence_gte Minimum confidence threshold as a float (optional)
#' @param ne Named list with lat and lon defining the north-east corner of a
#'   bounding box (optional). Must be used together with sw.
#'   Example: list(lat = 42.0, lon = -85.0)
#' @param sw Named list with lat and lon defining the south-west corner of a
#'   bounding box (optional). Must be used together with ne.
#'   Example: list(lat = 36.0, lon = -96.0)
#' @param limit Maximum total number of detections to return (default: NULL,
#'   returns all matching detections). Each page fetches 250 at a time.
#'   Set to a specific number for exploratory pulls.
#'
#'
#' @return A flat data.table where each row is one detection with columns:
#'   id, timestamp, confidence, score,
#'   species_id, common_name, scientific_name,
#'   station_id, station_name, station_type,
#'   station_country, station_continent, station_state, station_location,
#'   station_lat, station_lon
#' @export
#' @importFrom data.table data.table as.data.table rbindlist
#'
#' @examples
#' \dontrun{
#' connect_birdweather()
#'
#' # Get detections for a date range
#' dets <- get_detections(
#'   from  = "2025-01-01T00:00:00.000Z",
#'   to    = "2025-01-02T00:00:00.000Z",
#'   limit = 1000
#' )
#'
#' # Filter by species name
#' dets <- get_detections(
#'   from          = "2025-01-01T00:00:00.000Z",
#'   to            = "2025-01-02T00:00:00.000Z",
#'   species_names = "Black-capped Chickadee",
#'   limit         = 1000
#' )
#'
#' # Filter by continent with confidence threshold
#' dets <- get_detections(
#'   from           = "2025-01-01T00:00:00.000Z",
#'   to             = "2025-01-02T00:00:00.000Z",
#'   continents     = "North America",
#'   confidence_gte = 0.9,
#'   limit          = 1000
#' )
#'
#' # Filter by bounding box (Missouri/Illinois/Kentucky region)
#' dets <- get_detections(
#'   from  = "2025-05-12T00:00:00.000Z",
#'   to    = "2025-05-18T00:00:00.000Z",
#'   ne    = list(lat = 42.0, lon = -85.0),
#'   sw    = list(lat = 36.0, lon = -96.0),
#'   limit = 10000
#' )
#' }
get_detections <- function(from           = NULL,
                           to             = NULL,
                           station_ids    = NULL,
                           station_types  = NULL,
                           species_ids    = NULL,
                           species_names  = NULL,
                           continents     = NULL,
                           countries      = NULL,
                           confidence_gte = NULL,
                           ne             = NULL,
                           sw             = NULL,
                           limit          = NULL) {

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

  # -------------------------------------------------------
  # Resolve species names to IDs if provided
  # -------------------------------------------------------
  if (!is.null(species_names)) {
    looked_up <- lapply(species_names, function(name) {
      # Strip scientific name in parentheses if user copied from output
      name <- trimws(gsub("\\(.*\\)", "", name))

      found <- find_species(name, limit = 10)
      if (nrow(found) == 0) {
        message("No species found for: ", name, " - skipping.")
        return(NULL)
      }
      if (nrow(found) > 1) {
        match_list <- paste(
          sprintf("  %s (%s)", found$common_name, found$scientific_name),
          collapse = "\n"
        )
        message(
          "Multiple matches for '", name, "':\n",
          match_list, "\n",
          "Please rerun with a more specific name."
        )
        return(NULL)
      }
      found$species_id[1]
    })

    looked_up <- looked_up[!sapply(looked_up, is.null)]

    if (length(looked_up) == 0) {
      message("No species could be resolved. Returning empty result.")
      return(data.table::data.table())
    }

    name_ids    <- as.character(unlist(looked_up))
    species_ids <- unique(c(species_ids, name_ids))
  }

  # -------------------------------------------------------
  # Build variables incrementally - only what is non-NULL
  # -------------------------------------------------------
  base_variables <- list(first = as.integer(if (is.null(limit)) 250 else min(250, limit)))

  if (!is.null(from) && !is.null(to)) {
    base_variables$period <- list(from = from, to = to)
  }
  if (!is.null(station_ids))    base_variables$stationIds    <- as.list(as.character(station_ids))
  if (!is.null(species_ids))    base_variables$speciesIds    <- as.list(as.character(species_ids))
  if (!is.null(continents))     base_variables$continents    <- as.list(continents)
  if (!is.null(countries))      base_variables$countries     <- as.list(countries)
  if (!is.null(confidence_gte)) base_variables$confidenceGte <- confidence_gte
  if (!is.null(ne))             base_variables$ne            <- list(lat = ne$lat, lon = ne$lon)
  if (!is.null(sw))             base_variables$sw            <- list(lat = sw$lat, lon = sw$lon)
  if (!is.null(station_types)) base_variables$stationTypes <- as.list(station_types)

  # -------------------------------------------------------
  # Build query string dynamically from active variables
  # so query signature always matches variables exactly
  # -------------------------------------------------------
  var_types <- c(
    first         = "$first: Int",
    period        = "$period: InputDuration",
    stationIds    = "$stationIds: [ID!]",
    stationTypes  = "$stationTypes: [String!]",
    speciesIds    = "$speciesIds: [ID!]",
    continents    = "$continents: [String!]",
    countries     = "$countries: [String!]",
    confidenceGte = "$confidenceGte: Float",
    ne            = "$ne: InputLocation",
    sw            = "$sw: InputLocation"
  )

  arg_names <- c(
    first         = "first: $first",
    period        = "period: $period",
    stationIds    = "stationIds: $stationIds",
    stationTypes  = "stationTypes: $stationTypes",
    speciesIds    = "speciesIds: $speciesIds",
    continents    = "continents: $continents",
    countries     = "countries: $countries",
    confidenceGte = "confidenceGte: $confidenceGte",
    ne            = "ne: $ne",
    sw            = "sw: $sw"
  )

  active             <- names(var_types)[names(var_types) %in% names(base_variables)]
  query_declarations <- paste(var_types[active], collapse = ",\n    ")
  query_arguments    <- paste(arg_names[active], collapse = ",\n    ")

  build_query <- function(include_after = FALSE) {
    after_dec <- if (include_after) ",\n    $after: String" else ""
    after_arg <- if (include_after) ",\n    after: $after"  else ""

    sprintf('
      query detections(
        %s%s
      ) {
        detections(
          %s%s
        ) {
          nodes {
            id
            timestamp
            confidence
            score
            species { id commonName scientificName }
            station {
              id name type
              country continent state location
              coords { lat lon }
            }
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

  nodes <- result$data$detections$nodes

  if (is.null(nodes) || length(nodes) == 0) {
    message("No detections found for the specified filters.")
    return(data.table::data.table())
  }

  all_pages    <- list(flatten_nodes(nodes))
  has_next     <- result$data$detections$pageInfo$hasNextPage
  after_cursor <- result$data$detections$pageInfo$endCursor
  total        <- result$data$detections$totalCount

  message("Total detections matching filters: ", total)

  if (total > 10000 && is.null(limit)) {
    message("Note: ", format(total, big.mark = ","), " detections found. ",
            "This may take a while to download. ",
            "Set limit = 1000 to retrieve a subset instead.")
  }

  message("Fetched page 1 - ", nrow(nodes), " detections")

  # -------------------------------------------------------
  # Paginate until limit is reached or no more pages
  # -------------------------------------------------------
  page <- 1

  while (isTRUE(has_next) && (is.null(limit) || sum(sapply(all_pages, nrow)) < limit)) {

    page      <- page + 1
    remaining <- if (is.null(limit)) 250 else min(250, limit - sum(sapply(all_pages, nrow)))

    page_variables <- c(
      base_variables,
      list(
        first = as.integer(remaining),
        after = after_cursor
      )
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

    nodes <- result$data$detections$nodes

    if (is.null(nodes) || nrow(nodes) == 0) {
      message("No data on page ", page, " - stopping.")
      break
    }

    all_pages[[page]] <- flatten_nodes(nodes)
    has_next     <- result$data$detections$pageInfo$hasNextPage
    after_cursor <- result$data$detections$pageInfo$endCursor

    message("Fetched page ", page, " - ", nrow(nodes), " detections")
  }

  # -------------------------------------------------------
  # Bind all pages and return
  # -------------------------------------------------------
  final <- data.table::rbindlist(all_pages, fill = TRUE)
  message("Done. Returning ", nrow(final), " detections.")
  final
}
