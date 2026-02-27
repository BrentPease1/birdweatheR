# Solar Eclipse Light Sensor Data

BirdWeather PUC light sensor readings across stations in the path of the
April 8, 2024 total solar eclipse in North America.

## Usage

``` r
eclipse_light_data
```

## Format

A data.table with columns:

- station_id:

  Station ID

- timestamp:

  Reading timestamp

- clear:

  Broadband visible light (counts)

- nir:

  Near-infrared light (counts)

- f1-f8:

  Spectral band channels

## Source

BirdWeather API via birdweatheR
