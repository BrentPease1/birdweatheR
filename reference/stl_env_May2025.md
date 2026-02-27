# St. Louis, Missouri USA Environment Sensor Data - May 2025

BirdWeather PUC environment sensor readings (temperature, humidity,
barometric pressure, AQI) in the St. Louis metro area surrounding the
May 15-16, 2025 tornado outbreak.

## Usage

``` r
stl_env_May2025
```

## Format

A data.table with columns:

- station_id:

  Station ID

- timestamp:

  Reading timestamp

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

## Source

BirdWeather API via birdweatheR
