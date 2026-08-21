test_that("get_detections returns a flat data.table for a small window", {
  skip_on_cran()
  skip_if_offline()
  connect_birdweather()

  result <- get_detections(
    from = "2025-05-01T00:00:00.000Z",
    to   = "2025-05-01T00:10:00.000Z",
    limit = 5
  )
  expect_s3_class(result, "data.table")
  expect_true(nrow(result) <= 5)
})

test_that("get_detections returns an empty data.table gracefully when nothing matches", {
  skip_on_cran()
  skip_if_offline()
  connect_birdweather()

  result <- get_detections(
    from = "1900-01-01T00:00:00.000Z",
    to   = "1900-01-02T00:00:00.000Z"
  )
  expect_s3_class(result, "data.table")
  expect_equal(nrow(result), 0)
})
