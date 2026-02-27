# Get BirdWeather Stations

Retrieves public BirdWeather stations with optional filters. Handles
pagination automatically and returns a flat data.table.

## Usage

``` r
get_stations(
  query = NULL,
  from = NULL,
  to = NULL,
  ne = NULL,
  sw = NULL,
  limit = NULL
)
```

## Arguments

- query:

  Optional search string to filter stations by name (optional)

- from:

  Start datetime in ISO8601 format (optional)

- to:

  End datetime in ISO8601 format (optional)

- ne:

  Named list with lat and lon defining the north-east corner of a
  bounding box (optional). Must be used together with sw.

- sw:

  Named list with lat and lon defining the south-west corner of a
  bounding box (optional). Must be used together with ne.

- limit:

  Maximum total number of stations to return (default: NULL, returns all
  matching stations). Each page fetches 250 at a time.

## Value

A flat data.table where each row is one station with columns:
station_id, station_name, station_type, station_timezone,
station_country, station_continent, station_state, station_location,
station_lat, station_lon, location_privacy

## Note

The fields `latestDetectionAt` and `earliestDetectionAt` are not
returned due to server-side performance limitations.

## Examples

``` r
if (FALSE) { # \dontrun{
connect_birdweather()

# Get all stations
stations <- get_stations()

# Search by name
stations <- get_stations(query = "backyard")

# Filter by bounding box
stations <- get_stations(
  ne = list(lat = 42.0, lon = -85.0),
  sw = list(lat = 36.0, lon = -96.0)
)
} # }
```
