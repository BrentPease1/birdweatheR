test_that("find_species returns expected columns for a common name", {
  skip_on_cran()
  skip_if_offline()
  connect_birdweather()

  result <- find_species("chickadee")
  expect_s3_class(result, "data.table")
  expect_true(all(c("species_id", "common_name", "scientific_name") %in% names(result)))
})

test_that("find_species returns empty data.table for nonsense query", {
  skip_on_cran()
  skip_if_offline()
  connect_birdweather()

  result <- find_species("zzzznotaspecieszzzz")
  expect_s3_class(result, "data.table")
  expect_equal(nrow(result), 0)
})
