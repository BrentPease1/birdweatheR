# Wood Thrush Spring Migration Detections

BirdWeather detections of Wood Thrush (Hylocichla mustelina) across
North America during spring migration, March-May 2025. Filtered to
detections with confidence \>= 0.6.

## Usage

``` r
woth
```

## Format

A data.table with 569,000 rows and 15 columns:

- id:

  Detection ID

- timestamp:

  Detection timestamp in station timezone

- confidence:

  Model confidence

- score:

  Calculated score

- species_id:

  Species ID

- common_name:

  Species common name

- scientific_name:

  Species scientific name

- station_id:

  Station ID

- station_name:

  Station name

- station_type:

  Station type

- station_timezone:

  Station timezone

- station_country:

  Country

- station_continent:

  Continent

- station_state:

  State or province

- station_lat:

  Station latitude

- station_lon:

  Station longitude

## Source

BirdWeather API via birdweatheR
