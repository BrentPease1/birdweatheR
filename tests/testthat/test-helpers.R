test_that("flatten_nodes returns correct structure", {
  fake <- make_fake_nodes(2)
  out <- flatten_nodes(fake)

  expect_s3_class(out, "data.table")
  expect_equal(nrow(out), 2)
  expect_equal(ncol(out), 21)
  expect_true(all(c("common_name", "station_id", "det_lat") %in% names(out)))
})

test_that("flatten_nodes converts empty station_location to NA", {
  fake <- make_fake_nodes(1)
  out <- flatten_nodes(fake)
  expect_true(is.na(out$station_location))
})

test_that("normalize_datetime passes through full ISO8601 strings unchanged", {
  out <- normalize_datetime("2025-05-01T00:00:00.000Z", "from")
  expect_equal(out, "2025-05-01T00:00:00.000Z")
})

test_that("normalize_datetime appends midnight UTC to a bare date string", {
  out <- normalize_datetime("2025-05-01", "from")
  expect_equal(out, "2025-05-01T00:00:00.000Z")
})

test_that("normalize_datetime converts a Date object", {
  out <- normalize_datetime(as.Date("2025-05-01"), "from")
  expect_equal(out, "2025-05-01T00:00:00.000Z")
})

test_that("normalize_datetime converts a POSIXct object to UTC", {
  dt <- as.POSIXct("2025-05-01 12:30:00", tz = "UTC")
  out <- normalize_datetime(dt, "from")
  expect_equal(out, "2025-05-01T12:30:00.000Z")
})

test_that("normalize_datetime returns NULL for NULL input", {
  expect_null(normalize_datetime(NULL, "from"))
})

test_that("normalize_datetime errors on an unparseable type", {
  expect_error(normalize_datetime(TRUE, "from"), "must be a date string")
  expect_error(normalize_datetime(list(a = 1), "from"), "must be a date string")
})

test_that("normalize_datetime errors on a malformed date string", {
  expect_error(normalize_datetime("not-a-date", "from"), "must be a date string")
})
