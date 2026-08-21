test_that("connect_birdweather sets a GraphqlClient connection", {
  conn <- connect_birdweather()
  expect_s3_class(conn, "GraphqlClient")
  expect_false(is.null(birdweatheR:::.birdweather_env$connection))
})
