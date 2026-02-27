# Get BirdWeather Top Species

Returns the most frequently detected species for a given time period,
ranked by total detection count. Includes certainty breakdown.

## Usage

``` r
get_top_species(
  limit = 10,
  from = NULL,
  to = NULL,
  station_ids = NULL,
  station_types = NULL
)
```

## Arguments

- limit:

  Maximum number of species to return (default: 10)

- from:

  Start datetime in ISO8601 format (e.g. "2025-01-01T00:00:00.000Z")

- to:

  End datetime in ISO8601 format (e.g. "2025-01-02T00:00:00.000Z")

- station_ids:

  Character vector of station IDs to filter on (optional)

- station_types:

  Character vector of station types to filter on (optional)

## Value

A data.table with columns: species_id, common_name, scientific_name,
count, almost_certain, very_likely, unlikely, uncertain

## Examples

``` r
if (FALSE) { # \dontrun{
connect_birdweather()

# Top 10 species for a date range
get_top_species(
  from = "2025-05-01T00:00:00.000Z",
  to   = "2025-05-02T00:00:00.000Z"
)

# Top 25 species
get_top_species(
  limit = 25,
  from  = "2025-05-01T00:00:00.000Z",
  to    = "2025-05-02T00:00:00.000Z"
)
} # }
```
