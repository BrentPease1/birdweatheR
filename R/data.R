#' Wood Thrush Spring Migration Detections
#'
#' BirdWeather detections of Wood Thrush (Hylocichla mustelina) across
#' North America during spring migration, March-May 2025. Filtered to
#' detections with confidence >= 0.6.
#'
#' @format A data.table with 569,000 rows and 15 columns:
#' \describe{
#'   \item{id}{Detection ID}
#'   \item{timestamp}{Detection timestamp in station timezone}
#'   \item{confidence}{Model confidence}
#'   \item{score}{Calculated score}
#'   \item{species_id}{Species ID}
#'   \item{common_name}{Species common name}
#'   \item{scientific_name}{Species scientific name}
#'   \item{station_id}{Station ID}
#'   \item{station_name}{Station name}
#'   \item{station_type}{Station type}
#'   \item{station_timezone}{Station timezone}
#'   \item{station_country}{Country}
#'   \item{station_continent}{Continent}
#'   \item{station_state}{State or province}
#'   \item{station_lat}{Station latitude}
#'   \item{station_lon}{Station longitude}
#' }
#' @source BirdWeather API via birdweatheR
"woth"

#' St. Louis, Missouri, USA Storm Detections - May 2025
#'
#' BirdWeather PUC detections in the St. Louis metro area surrounding the
#' May 15-16, 2025 tornado outbreak, including an EF3 tornado.
#'
#' @format A data.table with detection and station columns as returned by
#'   \code{get_detections()}
#' @source BirdWeather API via birdweatheR
"stl_storm_May2025"

#' St. Louis, Missouri USA Environment Sensor Data - May 2025
#'
#' BirdWeather PUC environment sensor readings (temperature, humidity,
#' barometric pressure, AQI) in the St. Louis metro area surrounding the
#' May 15-16, 2025 tornado outbreak.
#'
#' @format A data.table with columns:
#' \describe{
#'   \item{station_id}{Station ID}
#'   \item{timestamp}{Reading timestamp}
#'   \item{temperature}{Temperature in Celsius}
#'   \item{humidity}{Relative humidity (percent)}
#'   \item{barometric_pressure}{Barometric pressure (hPa)}
#'   \item{aqi}{Air quality index}
#'   \item{eco2}{Equivalent CO2 (ppm)}
#'   \item{voc}{Volatile organic compounds}
#'   \item{sound_pressure_level}{Sound pressure level (dB)}
#' }
#' @source BirdWeather API via birdweatheR
"stl_env_May2025"

#' Solar Eclipse Bird Detections
#'
#' BirdWeather PUC detections across stations in the path of the April 8,
#' 2024 total solar eclipse in North America, filtered to confidence >= 0.6.
#'
#' @format A data.table with detection and station columns as returned by
#'   \code{get_detections()}
#' @source BirdWeather API via birdweatheR
"total_eclipse"

#' Solar Eclipse Light Sensor Data
#'
#' BirdWeather PUC light sensor readings across stations in the path of the
#' April 8, 2024 total solar eclipse in North America.
#'
#' @format A data.table with columns:
#' \describe{
#'   \item{station_id}{Station ID}
#'   \item{timestamp}{Reading timestamp}
#'   \item{clear}{Broadband visible light (counts)}
#'   \item{nir}{Near-infrared light (counts)}
#'   \item{f1-f8}{Spectral band channels}
#' }
#' @source BirdWeather API via birdweatheR
"eclipse_light_data"
