#' Search BirdWeather Species by Name
#'
#' Searches for species by common or scientific name. Useful for finding
#' species IDs to pass into get_detections(), or for exploring what
#' species exist in the BirdWeather database.
#'
#' @param query A search string — common name, scientific name, or partial
#'   match (e.g. "chickadee", "Poecile", "Black-capped")
#' @param limit Maximum number of results to return (default: 20)
#'
#' @return A data.table with columns: species_id, common_name, scientific_name
#' @export
#' @importFrom data.table as.data.table setnames
#'
#' @examples
#' \dontrun{
#' bw_find_species("chickadee")
#' bw_find_species("Poecile atricapillus")
#' bw_find_species("quail", limit = 20)
#' }
find_species <- function(query, limit = 20) {

  if (is.null(.birdweather_env$connection)) {
    stop("No API connection found. Please run connect_birdweather() first.")
  }

  search_query <- '
    query searchSpecies($query: String, $first: Int) {
      searchSpecies(query: $query, first: $first) {
        nodes {
          id
          commonName
          scientificName
        }
        totalCount
      }
    }
  '

  variables <- list(
    query = query,
    first = as.integer(limit)
  )

  query_exec <- ghql::Query$new()$query('url_link', search_query)
  result <- .birdweather_env$connection$exec(query_exec$url_link, variables = variables) |>
    jsonlite::fromJSON(flatten = FALSE)

  if (!is.null(result$errors)) {
    message("API returned errors:")
    print(result$errors)
    return(data.table::data.table())
  }

  nodes <- result$data$searchSpecies$nodes

  if (is.null(nodes) || length(nodes) == 0) {
    message("No species found matching: ", query,
            ". Consider using a wildcard (e.g., '",
            substr(query, 1, round(nchar(query) * 0.3)),
            "*') for a partial search. Including hyphens in name is helpful.")
    return(data.table::data.table())
  }

  if(length(nodes) > 20){
    message("More than 20 species match your query. Displaying first 20
            Use the `limit` argument to allow more returns (e.g., limit = 30")
  }

  dt <- data.table::as.data.table(nodes)
  data.table::setnames(dt, c("id", "commonName", "scientificName"),
                           c("species_id", "common_name", "scientific_name"))
  dt
}
