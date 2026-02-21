#' Get BirdWeather Species Information
#'
#' Retrieves species information for a vector of species IDs. Useful for
#' joining readable names onto output from get_daily_detection_counts()
#' or get_detections().
#'
#' @param ids Character vector of species IDs (required)
#'
#' @return A data.table with columns:
#'   species_id, common_name, scientific_name, color, alpha, alpha6,
#'   ebird_code, image_url, thumbnail_url, wikipedia_summary
#' @export
#'
#' @examples
#' \dontrun{
#' connect_birdweather()
#'
#' # Look up specific species
#' get_species_info(ids = c("305", "721", "1004"))
#'
#' # Join onto daily detection counts
#' daily <- get_daily_detection_counts(
#'   from       = "2025-05-01T00:00:00.000Z",
#'   to         = "2025-05-07T00:00:00.000Z",
#'   by_species = TRUE
#' )
#' species_info <- get_species_info(ids = unique(daily$speciesId))
#' daily[species_info, on = .(speciesId = species_id),
#'       `:=`(common_name     = i.common_name,
#'            scientific_name = i.scientific_name)]
#' }
get_species_info <- function(ids) {

  if (is.null(.birdweather_env$connection)) {
    stop("No API connection found. Please run connect_birdweather() first.")
  }

  if (is.null(ids) || length(ids) == 0) {
    message("No species IDs provided.")
    return(data.table::data.table())
  }

  query <- '
    query allSpecies($ids: [ID!]!) {
      allSpecies(ids: $ids) {
        nodes {
          id
          commonName
          scientificName
          color
          alpha
          alpha6
          ebirdCode
          imageUrl
          thumbnailUrl
          wikipediaSummary
        }
      }
    }
  '

  variables <- list(ids = as.list(as.character(ids)))

  query_exec <- ghql::Query$new()$query('url_link', query)
  result <- .birdweather_env$connection$exec(query_exec$url_link,
                                             variables = variables) |>
    jsonlite::fromJSON(flatten = FALSE)

  if (!is.null(result$errors)) {
    message("API returned errors:")
    print(result$errors)
    return(data.table::data.table())
  }

  nodes <- result$data$allSpecies$nodes

  if (is.null(nodes) || length(nodes) == 0) {
    message("No species found for provided IDs.")
    return(data.table::data.table())
  }

  dt <- data.table::as.data.table(nodes)
  data.table::setnames(dt,
                       old = c("id", "commonName", "scientificName", "ebirdCode",
                               "imageUrl", "thumbnailUrl", "wikipediaSummary"),
                       new = c("species_id", "common_name", "scientific_name", "ebird_code",
                               "image_url", "thumbnail_url", "wikipedia_summary")
  )
  dt
}
