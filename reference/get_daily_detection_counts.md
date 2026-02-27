# Get BirdWeather Daily Detection Counts

Returns daily detection counts for a given time period. By default
returns one row per day with total detections. Optionally returns
species-level breakdown with one row per species per day.

## Usage

``` r
get_daily_detection_counts(
  from = NULL,
  to = NULL,
  station_ids = NULL,
  species_ids = NULL,
  by_species = FALSE
)
```

## Arguments

- from:

  Start datetime in ISO8601 format (e.g. "2025-01-01T00:00:00.000Z")

- to:

  End datetime in ISO8601 format (e.g. "2025-01-02T00:00:00.000Z")

- station_ids:

  Character vector of station IDs to filter on (optional)

- species_ids:

  Character vector of species IDs to filter on (optional)

- by_species:

  Logical. If FALSE (default) returns one row per day with total
  detections only. If TRUE returns one row per species per day.

## Value

A data.table. When by_species = FALSE: date, day_of_year, daily_total.
When by_species = TRUE: date, day_of_year, daily_total, species_id,
count.

## Examples

``` r
if (FALSE) { # \dontrun{
connect_birdweather()

# Daily totals only
get_daily_detection_counts(
  from = "2025-05-01T00:00:00.000Z",
  to   = "2025-05-07T00:00:00.000Z"
)

# Species-level breakdown
get_daily_detection_counts(
  from       = "2025-05-01T00:00:00.000Z",
  to         = "2025-05-07T00:00:00.000Z",
  by_species = TRUE
)
} # }
```
