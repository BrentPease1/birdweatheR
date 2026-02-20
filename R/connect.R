# Package-level environment to store the API connection.
# Using a private environment means the connection object is accessible
# across all package functions without polluting the user's workspace.
.birdweather_env <- new.env(parent = emptyenv())

#' Connect to the BirdWeather API
#'
#' Establishes a connection to the BirdWeather GraphQL API. Must be called
#' once per session before using any other package functions.
#'
#' @return Invisibly returns the connection object
#' @export
#'
#' @examples
#' \dontrun{
#' connect_birdweather()
#' }
connect_birdweather <- function() {
  .birdweather_env$connection <- ghql::GraphqlClient$new(
    url = 'https://app.birdweather.com/graphql'
  )
  message("Connected to BirdWeather API.")
  invisible(.birdweather_env$connection)
}
