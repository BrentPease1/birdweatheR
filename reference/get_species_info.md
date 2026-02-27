# Get BirdWeather Species Information

Retrieves species information for a vector of species IDs. Useful for
joining readable names onto output from get_daily_detection_counts() or
get_detections().

## Usage

``` r
get_species_info(ids)
```

## Arguments

- ids:

  Character vector of species IDs (required)

## Value

A data.table with columns: species_id, common_name, scientific_name,
color, alpha, alpha6, ebird_code, image_url, thumbnail_url,
wikipedia_summary

## Examples

``` r
if (FALSE) { # \dontrun{
connect_birdweather()

# Look up specific species
get_species_info(ids = c("305", "721", "1004"))

# Join onto daily detection counts
daily <- get_daily_detection_counts(
  from       = "2025-05-01T00:00:00.000Z",
  to         = "2025-05-07T00:00:00.000Z",
  by_species = TRUE
)
species_info <- get_species_info(ids = unique(daily$speciesId))
daily[species_info, on = .(speciesId = species_id),
      `:=`(common_name     = i.common_name,
           scientific_name = i.scientific_name)]
} # }
```
