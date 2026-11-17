
test_that("use_cli switches the cli theme off and on", {
  skip_if_not_installed("cli")
  old <- zarr_options("use_cli")
  on.exit(zarr_options("use_cli", old), add = TRUE)

  zarr_options("use_cli", FALSE)
  expect_null(zarr_options("zarr_theme"))
  zarr_options("use_cli", TRUE)
  expect_true(is.list(zarr_options("zarr_theme")))
})

test_that("use_cli ignores invalid values", {
  old <- zarr_options("use_cli")
  on.exit(zarr_options("use_cli", old), add = TRUE)
  zarr_options("use_cli", "no")
  zarr_options("use_cli", NA)
  expect_identical(zarr_options("use_cli"), old)
})

test_that("a style option keeps the theme off when use_cli is FALSE", {
  skip_if_not_installed("cli")
  old <- zarr_options("use_cli")
  on.exit(zarr_options("use_cli", old), add = TRUE)
  zarr_options("use_cli", FALSE)
  zarr_options("group_style", c("red", "bold"))
  on.exit(zarr_options("group_style", c("blue", "bold")), add = TRUE)
  expect_null(zarr_options("zarr_theme"))
})

test_that("text_style sets the text style, not the array style", {
  old_text <- zarr_options("text_style")
  old_array <- zarr_options("array_style")
  on.exit(zarr_options("text_style", old_text), add = TRUE)
  zarr_options("text_style", "red")
  expect_identical(zarr_options("text_style"), "red")
  expect_identical(zarr_options("array_style"), old_array)
})
