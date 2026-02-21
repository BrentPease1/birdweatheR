#' Get BirdWeather Top Species
#'
#' Returns the most frequently detected species for a given time period,
#' ranked by total detection count. Includes certainty breakdown.
#'
#' @param limit Maximum number of species to return (default: 10)
#' @param from Start datetime in ISO8601 format (e.g. "2025-01-01T00:00:00.000Z")
#' @param to End datetime in ISO8601 format (e.g. "2025-01-02T00:00:00.000Z")
#' @param station_ids Character vector of station IDs to filter on (optional)
#' @param station_types Character vector of station types to filter on (optional)
#'
#' @return A data.table with columns:
#'   species_id, common_name, scientific_name, count,
#'   almost_certain, very_likely, unlikely, uncertain
#' @export
#'
#' @examples
#' \dontrun{
#' connect_birdweather()
#'
#' # Top 10 species for a date range
#' get_top_species(
#'   from = "2025-05-01T00:00:00.000Z",
#'   to   = "2025-05-02T00:00:00.000Z"
#' )
#'
#' # Top 25 species
#' get_top_species(
#'   limit = 25,
#'   from  = "2025-05-01T00:00:00.000Z",
#'   to    = "2025-05-02T00:00:00.000Z"
#' )
#' }
get_top_species <- function(limit        = 10,
                            from         = NULL,
                            to           = NULL,
                            station_ids  = NULL,
                            station_types = NULL) {

  if (is.null(.birdweather_env$connection)) {
    stop("No API connection found. Please run connect_birdweather() first.")
  }

  base_variables <- list(limit = as.integer(limit))

  if (!is.null(from) && !is.null(to)) {
    base_variables$period <- list(from = from, to = to)
  }
  if (!is.null(station_ids)) {
    base_variables$stationIds <- as.list(as.character(station_ids))
  }
  if (!is.null(station_types)) {
    base_variables$stationTypes <- as.list(station_types)
  }

  var_types <- c(
    limit        = "$limit: Int",
    period       = "$period: InputDuration",
    stationIds   = "$stationIds: [ID!]",
    stationTypes = "$stationTypes: [String!]"
  )

  arg_names <- c(
    limit        = "limit: $limit",
    period       = "period: $period",
    stationIds   = "stationIds: $stationIds",
    stationTypes = "stationTypes: $stationTypes"
  )

  active             <- names(var_types)[names(var_types) %in% names(base_variables)]
  query_declarations <- paste(var_types[active], collapse = ",\n    ")
  query_arguments    <- paste(arg_names[active], collapse = ",\n    ")

  query <- sprintf('
    query topSpecies(
      %s
    ) {
      topSpecies(
        %s
      ) {
        speciesId
        count
        species { commonName scientificName }
        breakdown {
          almostCertain
          veryLikely
          unlikely
          uncertain
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

  top <- result$data$topSpecies

  if (is.null(top) || nrow(top) == 0) {
    message("No data found for the specified filters.")
    return(data.table::data.table())
  }

  data.table::data.table(
    species_id      = top$speciesId,
    common_name     = top$species$commonName,
    scientific_name = top$species$scientificName,
    count           = top$count,
    almost_certain  = top$breakdown$almostCertain,
    very_likely     = top$breakdown$veryLikely,
    unlikely        = top$breakdown$unlikely,
    uncertain       = top$breakdown$uncertain
  )
}
