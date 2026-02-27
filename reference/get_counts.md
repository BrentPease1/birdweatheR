# Get BirdWeather Summary Counts

Returns a single-row summary of detections, species, stations, and
BirdNet detections for a given time period. Useful as a quick
platform-wide or regional snapshot before pulling raw detections.

## Usage

``` r
get_counts(
  from = NULL,
  to = NULL,
  station_ids = NULL,
  station_types = NULL,
  species_id = NULL,
  ne = NULL,
  sw = NULL
)
```

## Arguments

- from:

  Start datetime in ISO8601 format (e.g. "2025-01-01T00:00:00.000Z")

- to:

  End datetime in ISO8601 format (e.g. "2025-01-02T00:00:00.000Z")

- station_ids:

  Character vector of station IDs to filter on (optional)

- station_types:

  Character vector of station types to filter on (optional). Known types
  include "puc", "birdnetpi", and "app".

- species_id:

  A single species ID to filter on (optional). Use
  [`find_species`](https://brentpease1.github.io/birdweatheR/reference/find_species.md)
  to look up species IDs.

- ne:

  Named list with lat and lon defining the north-east corner of a
  bounding box (optional). Must be used together with sw. Example:
  list(lat = 42.0, lon = -85.0)

- sw:

  Named list with lat and lon defining the south-west corner of a
  bounding box (optional). Must be used together with ne. Example:
  list(lat = 36.0, lon = -96.0)

## Value

A single-row data.table with columns: detections, species, stations

## Details

For finer-grained summaries by species or station over time, see
[`get_daily_detection_counts`](https://brentpease1.github.io/birdweatheR/reference/get_daily_detection_counts.md)
and
[`get_detections`](https://brentpease1.github.io/birdweatheR/reference/get_detections.md).

## Examples

``` r
if (FALSE) { # \dontrun{
connect_birdweather()

# Platform-wide snapshot
get_counts(
  from = "2025-05-01T00:00:00.000Z",
  to   = "2025-05-02T00:00:00.000Z"
)

# Regional snapshot using bounding box
get_counts(
  from = "2025-05-01T00:00:00.000Z",
  to   = "2025-05-02T00:00:00.000Z",
  ne   = list(lat = 42.0, lon = -85.0),
  sw   = list(lat = 36.0, lon = -96.0)
)

# PUC stations only
get_counts(
  from          = "2025-05-01T00:00:00.000Z",
  to            = "2025-05-02T00:00:00.000Z",
  station_types = "puc"
)
} # }
```
