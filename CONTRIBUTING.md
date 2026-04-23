# Contributing to birdweatheR

Thank you for your interest in contributing to `birdweatheR`! This document outlines how to report bugs, request features, and contribute code.

## Reporting bugs

Please use the [bug report issue template](https://github.com/BrentPease1/birdweatheR/issues/new?template=bug_report.md) and include:

- A minimal reproducible example (use `reprex::reprex()` if possible)
- The output of `sessionInfo()`
- The full error message or unexpected output

## Requesting features

Use the [feature request template](https://github.com/BrentPease1/birdweatheR/issues/new?template=feature_request.md) to suggest new functions, additional API filters, or improvements to existing behavior.

## Contributing code

1. Fork the repository and create a branch from `main`
2. Make your changes, following the code style guidelines below
3. Run `devtools::check()` and resolve any errors or warnings
4. Submit a pull request with a clear description of what changed and why

### Code style

- Follow the [tidyverse style guide](https://style.tidyverse.org/) for general R conventions (naming, spacing)
- This package uses `data.table` throughout — new contributions should follow
  the same pattern rather than introducing `dplyr` or other data manipulation
  dependencies
- Use `lintr::lint_package()` to check for style issues before submitting
- All new functions must have roxygen2 documentation (`@param`, `@return`, `@examples`)
- Examples that require an API connection must be wrapped in `\dontrun{}`

### Adding new API functions

If you are wrapping a new BirdWeather API endpoint:

- Follow the existing pattern in `R/get_detections.R` for pagination and retry logic
- Use `fetch_page_with_retry()` for any paginated GraphQL queries
- Return a flat `data.table` — no nested lists in the output
- Add the function to `NAMESPACE` via `@export` and re-run `devtools::document()`

## Questions

For general questions about the package or the BirdWeather API, please [open an issue](https://github.com/BrentPease1/birdweatheR/issues) rather than emailing the maintainers directly — this keeps answers visible to the community.

For questions about the BirdWeather platform itself, see the [BirdWeather documentation](https://birdweather.com) or contact the BirdWeather team.
