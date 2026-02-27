# Search BirdWeather Species by Name

Searches for species by common or scientific name. Useful for finding
species IDs to pass into get_detections(), or for exploring what species
exist in the BirdWeather database.

## Usage

``` r
find_species(query, limit = 20)
```

## Arguments

- query:

  A search string — common name, scientific name, or partial match (e.g.
  "chickadee", "Poecile", "Black-capped")

- limit:

  Maximum number of results to return (default: 20)

## Value

A data.table with columns: species_id, common_name, scientific_name

## Examples

``` r
if (FALSE) { # \dontrun{
bw_find_species("chickadee")
bw_find_species("Poecile atricapillus")
bw_find_species("quail", limit = 20)
} # }
```
