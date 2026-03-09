# birdweatheR 0.1.0

Initial release.

## New functions

* `connect_birdweather()` — establish a session connection to the BirdWeather
  GraphQL API. Must be called once before using any other package functions.

* `find_species()` — search the BirdWeather species database by common name,
  scientific name, or partial string. Returns species IDs for use in other
  functions.

* `get_detections()` — retrieve individual bird detections with full filtering
  support (date range, species, station, country, continent, bounding box,
  confidence threshold, probability threshold). Handles pagination automatically
  with exponential-backoff retry on transient server errors.

* `get_counts()` — return a single-row summary of total detections, species
  richness, and active stations for a given period and filter set.

* `get_daily_detection_counts()` — return detection counts aggregated by day,
  optionally broken down by species.

* `get_top_species()` — return the most frequently detected species for a
  period, ranked by count, with confidence-tier breakdown
  (almost certain / very likely / unlikely / uncertain).

* `get_tod_counts()` — return detection counts binned by time of day (30-minute
  bins) for a focal species. Supports per-station breakdown via `by_station`
  and zero-filling via `fill_zeros`.

* `get_stations()` — retrieve public BirdWeather stations with optional
  name search, date range, and bounding-box filters.

* `get_species_info()` — look up species metadata (common name, scientific
  name, eBird code, image URLs, Wikipedia summary) for a vector of species IDs.

* `get_environment_data()` — retrieve PUC environmental sensor readings
  (temperature, humidity, barometric pressure, AQI, eCO2, VOC, sound pressure
  level) for one or more stations.

* `get_light_data()` — retrieve PUC spectral light sensor readings (clear,
  NIR, and eight spectral channels f1–f8) for one or more stations.

## Bundled datasets

* `woth` — Wood Thrush (*Hylocichla mustelina*) detections across North America
  during spring migration, March–May 2025 (confidence ≥ 0.6; ~569,000 rows).

* `stl_storm_May2025` — BirdWeather PUC detections in the St. Louis metro area
  surrounding the May 15–16, 2025 tornado outbreak (including an EF3 tornado).

* `stl_env_May2025` — PUC environmental sensor readings from the same St. Louis
  stations and time window.

* `total_eclipse` — Detections from stations in the path of the April 8, 2024
  total solar eclipse across North America (confidence ≥ 0.6).

* `eclipse_light_data` — PUC light sensor readings from eclipse-path stations
  on April 8, 2024.
