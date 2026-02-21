# birdweatheR

The `birdweatheR` R package provides access to the [BirdWeather](https://birdweather.com) bioacoustic community-science platform. Download and analyze bird vocalization detections from BirdWeather stations worldwide.

## Installation

You can install the development version of birdweatheR from GitHub:

``` r
# install.packages("devtools")
devtools::install_github("BrentPease1/birdweatheR")
```

## Getting Started

```r
library(birdweatheR)

# Establish connection to the BirdWeather API - required once per session
connect_birdweather()
```

---

## Functions

### `find_species()`

Search for species by common or scientific name. Useful for exploring which species exist in the BirdWeather database and finding species IDs before pulling detections.

```r
# Search by common name
find_species("chickadee")

# Search by scientific name
find_species("Poecile")

# Use a wildcard for partial matches
find_species("whip*")
```

---

### `get_detections()`

Retrieve bird detections from the BirdWeather API with optional filters. Handles pagination automatically and returns a flat `data.table` with detection, species, and station information.

```r
# Get detections for a date range
detections <- get_detections(
  from  = "2025-01-01T00:00:00.000Z",
  to    = "2025-01-02T00:00:00.000Z",
  limit = 1000
)

# Filter by species name - if multiple matches are found, all are shown
# and the user is prompted to rerun with a more specific name
detections <- get_detections(
  from          = "2025-05-01T00:00:00.000Z",
  to            = "2025-05-02T00:00:00.000Z",
  species_names = "Eastern Whip-poor-will",
  limit         = 1000
)

# For faster pulls, look up species ID first and pass it directly
ewpw_id <- find_species("Eastern Whip-poor-will")$species_id

detections <- get_detections(
  from        = "2025-05-01T00:00:00.000Z",
  to          = "2025-05-02T00:00:00.000Z",
  species_ids = ewpw_id,
  limit       = 1000
)

# Filter by continent with a confidence threshold
detections <- get_detections(
  from           = "2025-01-01T00:00:00.000Z",
  to             = "2025-01-02T00:00:00.000Z",
  continents     = "North America",
  confidence_gte = 0.9,
  limit          = 1000
)
```

#### Returned columns

| Column | Description |
|---|---|
| `id` | Detection ID |
| `timestamp` | Detection timestamp in station timezone |
| `confidence` | BirdNET confidence |
| `score` | Calculated identification likelihood score |
| `species_id` | Species ID |
| `common_name` | Species common name |
| `scientific_name` | Species scientific name |
| `station_id` | Station ID |
| `station_name` | Station name |
| `station_type` | Station type |
| `station_timezone` | Station timezone |
| `station_country` | Country |
| `station_continent` | Continent |
| `station_state` | State / province |
| `station_lat`, `station_lon` | Station coordinates |

---

### `get_counts()`

Returns a single-row summary snapshot of detections, species, and stations for a given time period.

```r
get_counts(
  from = "2025-05-01T00:00:00.000Z",
  to   = "2025-05-02T00:00:00.000Z"
)
```

---

### `get_top_species()`

Returns the most frequently detected species for a given time period, ranked by total detection count. Includes a certainty breakdown.

```r
# Top 10 species (default)
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
```

---

### `get_daily_detection_counts()`

Returns daily detection counts for a given time period. By default returns one row per day with total detections. Optionally returns a species-level breakdown.

```r
# Daily totals
daily <- get_daily_detection_counts(
  from = "2025-05-01T00:00:00.000Z",
  to   = "2025-05-07T00:00:00.000Z"
)

# Species-level breakdown - one row per species per day
daily <- get_daily_detection_counts(
  from       = "2025-05-01T00:00:00.000Z",
  to         = "2025-05-07T00:00:00.000Z",
  by_species = TRUE
)
```

---

### `get_species_info()`

Retrieves species information for a vector of species IDs. Most useful for joining readable names onto output from `get_daily_detection_counts(by_species = TRUE)`.

```r
# Look up specific species
get_species_info(ids = c("305", "721", "1004"))

# Join species names onto daily detection counts
daily <- get_daily_detection_counts(
  from       = "2025-05-01T00:00:00.000Z",
  to         = "2025-05-07T00:00:00.000Z",
  by_species = TRUE
)

species_info <- get_species_info(ids = unique(daily$speciesId))

daily[species_info, on = .(speciesId = species_id),
      `:=`(common_name     = i.common_name,
           scientific_name = i.scientific_name)]
```

---

### `get_tod_counts()`

Returns detection counts binned by time of day (30-minute intervals) for a given species. Useful for visualizing daily activity patterns like dawn chorus or nocturnal behavior.

```r
# American Robin time of day activity
robin_tod <- get_tod_counts(
  species_id = "123",
  from       = "2025-05-01T00:00:00.000Z",
  to         = "2025-05-07T00:00:00.000Z"
)
```

---

## BirdWeather PUC Sensors

BirdWeather PUCs are an AI powered bioacoustics platform with dual onboard microphones, WiFi/BLE, GPS, environmental sensors, and a built-in neural engine, all in a weatherproof enclosure. The following functions allow users to extract and annotate their bird vocalization data with environmental and light conditions.

## `get_environment_data()`

Retrieves environmental sensor readings from a BirdWeather PUC station. Readings are logged approximately every 42 seconds and include temperature, humidity, barometric pressure, air quality, eCO2, VOC, and sound pressure level.

```r
env <- get_environment_data(
  station_id = "1733",
  from       = "2025-05-01T00:00:00.000Z",
  to         = "2025-05-02T00:00:00.000Z"
)
```

#### Returned columns

| Column | Description |
|---|---|
| `station_id` | Station ID |
| `timestamp` | Reading timestamp |
| `temperature` | Temperature |
| `humidity` | Relative humidity |
| `barometric_pressure` | Barometric pressure |
| `aqi` | Air quality index |
| `eco2` | Equivalent CO2 |
| `voc` | Volatile organic compounds |
| `sound_pressure_level` | Ambient sound pressure level |

---

### `get_light_data()`

Retrieves spectral light sensor readings from a BirdWeather PUC station. Includes 8 spectral channels (f1-f8), broadband clear light, and near-infrared. Useful for studying light availability and phenology alongside bird activity.

```r
light <- get_light_data(
  station_id = "1733",
  from       = "2025-05-01T00:00:00.000Z",
  to         = "2025-05-02T00:00:00.000Z"
)
```

#### Returned columns

| Column | Description |
|---|---|
| `station_id` | Station ID |
| `timestamp` | Reading timestamp |
| `clear` | Broadband clear light |
| `nir` | Near-infrared |
| `f1` - `f8` | Spectral channels |

--

## Citation

If you use this package in your research, please cite both the package and BirdWeather:

```r
citation("birdweatheR")
```

## License

MIT

## Issues

Please report issues at: https://github.com/BrentPease1/birdweatheR/issues
