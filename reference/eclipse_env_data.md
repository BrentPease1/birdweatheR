# Solar Eclipse Environment Sensor Data

BirdWeather PUC environmental sensor readings across stations in the
path of the April 8, 2024 total solar eclipse in North America.

## Usage

``` r
eclipse_env_data
```

## Format

A data.table with 46,096 rows and 10 columns:

- station_id:

  Station ID

- timestamp:

  Reading timestamp with UTC offset (character)

- temperature:

  Temperature in Celsius

- humidity:

  Relative humidity (percent)

- barometric_pressure:

  Barometric pressure (hPa)

- aqi:

  Air quality index

- eco2:

  Equivalent CO2 (ppm)

- voc:

  Volatile organic compounds

- sound_pressure_level:

  Sound pressure level (dB)

- datetime:

  Parsed timestamp as POSIXct in local station time

## Source

BirdWeather API via birdweatheR
