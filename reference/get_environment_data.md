# Get BirdWeather PUC Environmental Sensor Data

Retrieves environmental sensor readings from one or more BirdWeather PUC
stations. Includes temperature, humidity, barometric pressure, air
quality, eCO2, VOC, and sound pressure level. Handles pagination
automatically.

## Usage

``` r
get_environment_data(station_id = NULL, from = NULL, to = NULL, limit = NULL)
```

## Arguments

- station_id:

  A single station ID or character vector of station IDs (required)

- from:

  Start datetime in ISO8601 format (e.g. "2025-01-01T00:00:00.000Z")

- to:

  End datetime in ISO8601 format (e.g. "2025-01-02T00:00:00.000Z")

- limit:

  Maximum number of readings to return per station (default: NULL,
  returns all). When multiple station IDs are provided, limit applies to
  each station individually.

## Value

A data.table with columns: station_id, timestamp, temperature, humidity,
barometric_pressure, aqi, eco2, voc, sound_pressure_level

## Examples

``` r
if (FALSE) { # \dontrun{
connect_birdweather()

# Single station
env <- get_environment_data(
  station_id = "1733",
  from       = "2025-05-01T00:00:00.000Z",
  to         = "2025-05-02T00:00:00.000Z"
)

# Multiple stations - same time window
env <- get_environment_data(
  station_id = c("1733", "2522", "8947"),
  from       = "2025-05-01T00:00:00.000Z",
  to         = "2025-05-02T00:00:00.000Z"
)
} # }
```
