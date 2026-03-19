#' Get BirdWeather Detections
#'
#' Retrieves bird detections from the BirdWeather API with optional filters.
#' Handles pagination automatically up to the specified limit. Returns a fully
#' flat data.table with all nested fields (coords, species, station) expanded
#' into individual columns. Includes automatic retry with exponential backoff
#' to handle transient 504/server errors mid-pagination.
#'
#' @param from Start datetime as a string in ISO8601 format in UTC
#'   (e.g. "2025-01-01T00:00:00.000Z"). Defaults to 24 hours ago if NULL.
#'   If \code{tz} is supplied, this should instead be a local datetime string
#'   without a trailing Z (e.g. "2025-05-16T00:00:00") and it will be
#'   converted to UTC automatically before the query.
#' @param to End datetime as a string in ISO8601 format in UTC
#'   (e.g. "2025-01-02T00:00:00.000Z"). Defaults to now if NULL.
#'   See \code{from} for local-time usage with \code{tz}.
#' @param tz Optional. An Olson timezone string (e.g. \code{"America/Chicago"},
#'   \code{"Europe/London"}) specifying the local timezone of the \code{from}
#'   and \code{to} strings. When supplied, both datetimes are converted to UTC
#'   before the API query. When NULL (the default), \code{from} and \code{to}
#'   are passed to the API as-is and are assumed to already be in UTC. Use
#'   \code{OlsonNames()} for valid timezone strings.
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
#' @param confidence_gte Minimum BirdNET confidence threshold as a float (optional)
#' @param probability_gte Numeric. Filter detections with probability greater
#'   than or equal to this value. Probability is a measure of the species' likely
#'   occurrence given timestamp, station_lat, and station_lon. eBird is the source
#'   of species occurrence probabilities. (optional)
#' @param probability_lte Numeric. Filter detections with probability less than
#'   or equal to this value. See probability_gte for details. (optional)
#' @param ne Named list with lat and lon defining the north-east corner of a
#'   bounding box (optional). Must be used together with sw.
#'   Example: list(lat = 42.0, lon = -85.0)
#' @param sw Named list with lat and lon defining the south-west corner of a
#'   bounding box (optional). Must be used together with ne.
#'   Example: list(lat = 36.0, lon = -96.0)
#' @param limit Maximum total number of detections to return (default: NULL,
#'   returns all matching detections). Each page fetches 250 at a time.
#'   Set to a specific number for exploratory pulls.
#' @param max_retries Maximum number of retry attempts per page on transient
#'   errors (default: 5). Retries use exponential backoff with jitter.
#'
#' @return A flat data.table where each row is one detection with columns:
#'   id, timestamp, confidence, probability, score,
#'   species_id, common_name, scientific_name, classification,
#'   station_id, station_name, station_type, station_timezone,
#'   station_country, station_continent, station_state, station_location,
#'   station_lat, station_lon
#' @seealso \code{\link{find_species}} to look up species IDs or names,
#'  \code{\link{get_stations}} to find station IDs for filtering,
#'  \code{\link{get_counts}} for a lightweight summary before pulling raw detections,
#'  \code{\link{get_daily_detection_counts}} for pre-aggregated daily totals
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
#' # NOTE: from/to are UTC. A "2025-05-12 midnight" in Chicago (CDT, UTC-5)
#' # would be "2025-05-12T05:00:00.000Z" — use tz= to avoid manual conversion.
#' dets <- get_detections(
#'   from  = "2025-05-12T00:00:00.000Z",
#'   to    = "2025-05-18T00:00:00.000Z",
#'   ne    = list(lat = 42.0, lon = -85.0),
#'   sw    = list(lat = 36.0, lon = -96.0),
#'   limit = 10000
#' )
#'
#' # Supply local times directly using tz — no manual UTC conversion needed.
#' # from/to are interpreted as America/Chicago local time and converted
#' # to UTC before the query.
#' dets <- get_detections(
#'   from  = "2025-05-16T00:00:00",
#'   to    = "2025-05-16T23:59:59",
#'   tz    = "America/Chicago",
#'   ne    = list(lat = 38.95, lon = -89.85),
#'   sw    = list(lat = 38.35, lon = -90.75),
#'   limit = 5000
#' )
#' }
get_detections <- function(from           = NULL,
                           to             = NULL,
                           tz             = NULL,
                           station_ids    = NULL,
                           station_types  = NULL,
                           species_ids    = NULL,
                           species_names  = NULL,
                           continents     = NULL,
                           countries      = NULL,
                           confidence_gte = NULL,
                           probability_gte = NULL,
                           probability_lte = NULL,
                           ne             = NULL,
                           sw             = NULL,
                           limit          = NULL,
                           max_retries    = 5) {

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
  # Timezone handling
  # -------------------------------------------------------
  if (!is.null(tz)) {
    # Validate the timezone string before using it
    if (!tz %in% OlsonNames()) {
      stop("'tz' does not appear to be a valid Olson timezone string. ",
           "Run OlsonNames() for valid options. Got: ", tz)
    }

    local_to_utc <- function(dt_str, tz) {
      # Accept strings with or without trailing Z
      dt_str <- sub("Z$", "", dt_str)
      dt <- as.POSIXct(dt_str, tz = tz, format = "%Y-%m-%dT%H:%M:%S")
      if (is.na(dt)) {
        stop("Could not parse datetime string '", dt_str, "' with tz = '", tz, "'. ",
             "Expected format: 'YYYY-MM-DDTHH:MM:SS'.")
      }
      format(dt, format = "%Y-%m-%dT%H:%M:%S.000Z", tz = "UTC")
    }

    if (!is.null(from)) {
      from_utc <- local_to_utc(from, tz)
      message("tz = '", tz, "': converting 'from' ", from, " -> ", from_utc)
      from <- from_utc
    }
    if (!is.null(to)) {
      to_utc <- local_to_utc(to, tz)
      message("tz = '", tz, "': converting 'to'   ", to, " -> ", to_utc)
      to <- to_utc
    }

  } else if (!is.null(from) || !is.null(to)) {
    # No tz supplied — warn once so users know the expectation
    warning(
      "from/to are treated as UTC. If your times are in a local timezone, ",
      "supply tz = \"Your/Timezone\" (e.g. tz = \"America/Chicago\") to convert ",
      "automatically. Run OlsonNames() for valid timezone strings.",
      call. = FALSE
    )
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
  if (!is.null(probability_gte)) base_variables$probabilityGte <- probability_gte
  if (!is.null(probability_lte)) base_variables$probabilityLte <- probability_lte
  if (!is.null(ne))             base_variables$ne            <- list(lat = ne$lat, lon = ne$lon)
  if (!is.null(sw))             base_variables$sw            <- list(lat = sw$lat, lon = sw$lon)
  if (!is.null(station_types))  base_variables$stationTypes  <- as.list(station_types)

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
    probabilityGte = "$probabilityGte: Float",
    probabilityLte = "$probabilityLte: Float",
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
    probabilityGte = "probabilityGte: $probabilityGte",
    probabilityLte = "probabilityLte: $probabilityLte",
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
            probability
            score
            species { id commonName scientificName classification }
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
  # Helper: format seconds as "Xs" or "Xm Ys"
  # -------------------------------------------------------
  format_seconds <- function(s) {
    s <- round(s)
    if (s < 60) return(paste0(s, "s"))
    paste0(s %/% 60, "m ", s %% 60, "s")
  }

  # -------------------------------------------------------
  # Execute first page (with retry)
  # -------------------------------------------------------
  query_exec <- ghql::Query$new()$query('url_link', initial_query)
  result     <- fetch_page_with_retry(query_exec, base_variables, max_retries = max_retries)

  nodes <- result$data$detections$nodes

  if (is.null(nodes) || length(nodes) == 0) {
    message("No detections found for the specified filters.")
    return(data.table::data.table())
  }

  all_pages    <- list(flatten_nodes(nodes))
  has_next     <- result$data$detections$pageInfo$hasNextPage
  after_cursor <- result$data$detections$pageInfo$endCursor
  total        <- result$data$detections$totalCount

  # Total we actually intend to fetch (respects limit)
  total_to_fetch  <- if (is.null(limit)) total else min(total, limit)
  n_pages_total   <- ceiling(total_to_fetch / 250)

  message("Total detections matching filters: ", format(total, big.mark = ","))

  if (n_pages_total > 1) {
    est_secs <- (n_pages_total - 1) * 1.5
    message("Estimated download time: ~", format_seconds(est_secs),
            " (", n_pages_total, " pages of 250)")
  }

  if (total > 10000 && is.null(limit)) {
    message("Note: ", format(total, big.mark = ","), " detections found. ",
            "This may take a while to download. ",
            "Set limit = 1000 to retrieve a subset instead.")
  }

  message("Fetched page 1/", n_pages_total, " — ",
          format(nrow(nodes), big.mark = ","), " detections")


  # -------------------------------------------------------
  # Paginate until limit is reached or no more pages
  # -------------------------------------------------------
  page <- 1
  page_times <- numeric(0)  # rolling record of seconds per page

  while (isTRUE(has_next) && (is.null(limit) || sum(sapply(all_pages, nrow)) < limit)) {

    Sys.sleep(1)
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

    t0     <- proc.time()[["elapsed"]]
    result     <- fetch_page_with_retry(query_exec, page_variables, max_retries = max_retries)
    t1     <- proc.time()[["elapsed"]]

    page_times <- c(page_times, t1 - t0 + 1)  # +1 for the Sys.sleep(1)

    nodes <- result$data$detections$nodes

    if (is.null(nodes) || nrow(nodes) == 0) {
      message("No data on page ", page, " - stopping.")
      break
    }

    all_pages[[page]] <- flatten_nodes(nodes)
    has_next     <- result$data$detections$pageInfo$hasNextPage
    after_cursor <- result$data$detections$pageInfo$endCursor

    fetched_so_far  <- sum(sapply(all_pages, nrow))
    pct_done        <- round(fetched_so_far / total_to_fetch * 100)
    pages_remaining <- n_pages_total - page
    avg_page_time   <- mean(page_times)
    eta_secs        <- pages_remaining * avg_page_time

    eta_str <- if (pages_remaining > 0) {
      paste0(" — ~", format_seconds(eta_secs), " remaining")
    } else {
      ""
    }

    message("Fetched page ", page, "/", n_pages_total,
            " (", format(fetched_so_far, big.mark = ","),
            " / ", format(total_to_fetch, big.mark = ","),
            ", ", pct_done, "%)", eta_str)
  }

  # -------------------------------------------------------
  # Bind all pages and return
  # -------------------------------------------------------
  final <- data.table::rbindlist(all_pages, fill = TRUE)
  message("Done. Returning ", format(nrow(final), big.mark = ","), " detections.")
  final
}
