test <-
"
The `birdweatheR` package will reduce barriers for researchers to use the
BirdWeather database for ecological analyses. The program, by providing
detections at fine spatiotemporal resolutions from standardized sensors,
provides a rich source to fuel investigations into the behaviors and
distributions of the world’s birds. We have already used BirdWeather to provide
syntheses of how birds respond behaviorally to light pollution [@pease2025] and
solar eclipses [@gilbert2026], and we are particularly hopeful that the dataset
will advance the emerging field of macrobehavior [@keith2023]. To reach its
potential as a research tool, BirdWeather must be accessible and usable by the
broadest audiences of ecologists as possible, and our package is a significant
step in that direction. To further illustrate the research impact and potential
of the package, we provide the following three worked examples, aimed at stimulating research from the scientific community.
"


stylermd::tidy_text(test) |>
  cat(sep = "\n")


stylermd::tidy_file(here('joss/paper.md'))
