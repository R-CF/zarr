# Tests for print(), str() and hierarchy() output, and for reading attributes
# back by path. Output is matched with regular expressions rather than
# snapshots so these tests also run where snapshots are skipped.
#
# This file tests the plain-text output; the cli output is tested in
# test-print-cli.R. make_tree() is in helper-print.R.

# ==== zarr object =============================================================
thm <- Zarr.options$zarr_theme
Zarr.options$zarr_theme <- NULL

test_that("print() of a zarr object in memory", {
  z <- make_tree()
  expect_output(print(z), "<Zarr>")
  expect_output(print(z), "Store     : Memory store - version 3")
  expect_output(print(z), "Arrays    : 2")
  out <- capture.output(print(z))
  expect_false(any(grepl("Location", out)))
})

test_that("print() of a zarr object on the file system adds location and size", {
  z <- make_tree(tempfile(fileext = ".zarr"))
  expect_output(print(z), "Location  :")
  expect_output(print(z), "Total size: [0-9.]+ (Bytes|KB)")
})

test_that("print() of an uninitialised zarr object", {
  z <- zarr$new(zarr_memorystore$new())
  expect_output(print(z), "Arrays    : \\(uninitialised\\)")
  expect_output(z$hierarchy(), "\\(uninitialised\\)")
})

test_that("print() of a single-array store", {
  z <- as_zarr(1:10)
  expect_output(print(z), "Arrays    : 1 \\(single array store\\)")
})

test_that("hierarchy() draws the tree", {
  out <- capture.output(make_tree()$hierarchy())
  expect_match(out[1L], "<Zarr hierarchy>")
  expect_true(any(grepl("/ \\(root group\\)", out)))
  expect_true(any(grepl("├ ☰ grp", out)))      # first of two children
  expect_true(any(grepl("│ └ ☰ sub|│ ├ ☰ sub", out)))
  expect_true(any(grepl("└ ⌗ a \\[4, 6\\]$", out)))  # last child of root, with shape
})

test_that("hierarchy() of a single-array store", {
  expect_output(as_zarr(1:10)$hierarchy(), "\\(root array\\)")
})

test_that("hierarchy() shows dimension names of arrays", {
  meta <- define_array("int32", c(2L, 3L))$metadata()
  meta$dimension_names <- c("y", "x")
  z <- create_zarr()
  z$add_array("/", "a", meta)
  expect_output(z$hierarchy(), "└ ⌗ a \\[y = 2, x = 3\\]")
})

test_that("save_to() reports progress when verbose", {
  out <- capture.output(make_tree()$save_to(tempfile(fileext = ".zarr"), verbose = TRUE))
  expect_true(any(grepl('^Created group "grp"', out)))
  expect_true(any(grepl('^Copying array "a" \\([12]/2\\)$', out)))
})

test_that("str() of a zarr object", {
  expect_output(str(make_tree()), "Zarr object with 2 arrays")
  expect_output(str(as_zarr(1:10)), "Zarr object with 1 array$")
})

# ==== Stores ==================================================================

test_that("print() of a memory store", {
  s <- zarr_memorystore$new()
  expect_output(print(s), "<Zarr store>")
  expect_output(print(s), "Store     : Memory store - version 3")
})

test_that("print() of a local store shows location and size", {
  fn <- tempfile(fileext = ".zarr")
  z <- make_tree(fn)
  expect_output(print(z$store), "Store     : Local file system store - version 3")
  expect_output(print(z$store), "Location  :")
  expect_output(print(z$store), basename(fn), fixed = TRUE)
  expect_output(print(z$store), "Total size: [0-9.]+ (Bytes|KB)")
})

# ==== Groups ==================================================================

test_that("print() of a group lists sub-groups, arrays and attributes", {
  z <- make_tree()
  grp <- z[["/grp"]]
  grp$set_attribute("title", "A group")
  expect_output(print(grp), "<Zarr group> ☰ grp")
  expect_output(print(grp), "Path      : /grp")
  expect_output(print(grp), "Sub-groups: sub")
  expect_output(print(grp), "Arrays    : b")
  expect_output(print(grp), "Attributes")
  expect_output(print(z$root), "<Zarr group> ☰ \\[root\\]")
})

test_that("group hierarchy() starts at the group", {
  out <- capture.output(make_tree()[["/grp"]]$hierarchy())
  expect_match(out[1L], "<Zarr hierarchy> /grp")
})

test_that("str() of groups", {
  z <- make_tree()
  expect_output(str(z[["/grp"]]), "Zarr group with 1 array and 1 sub-group")
  expect_output(str(z$root), "Zarr group with 1 array and 1 sub-group")
  z$add_group("/", "extra")
  expect_output(str(z$root), "Zarr group with 1 array and 2 sub-groups")
  expect_output(str(z[["/grp/sub"]]), "Zarr group without arrays or sub-groups")
})

test_that("count_arrays() counts recursively or not", {
  z <- make_tree()
  expect_equal(z$root$count_arrays(), 2L)
  expect_equal(z$root$count_arrays(recursive = FALSE), 1L)
  expect_equal(z[["/grp/sub"]]$count_arrays(), 0L)
})

# ==== Arrays ==================================================================

test_that("print() of an array", {
  a <- make_tree()[["/a"]]
  expect_output(print(a), "<Zarr array> .* a")
  expect_output(print(a), "Data type : float64")
  expect_output(print(a), "Shape     : 4 6\n")
  expect_output(print(a), "Chunking  : 2 3")
})

test_that("print() of an array shows dimension names", {
  meta <- define_array("int32", c(2L, 3L))$metadata()
  meta$dimension_names <- c("y", "x")
  a <- create_zarr()$add_array("/", "a", meta)
  expect_output(print(a), "Shape     : 2 3 \\[y, x\\]")
})

test_that("print() of a scalar array", {
  b <- make_tree()[["/grp/b"]]
  expect_output(print(b), "Shape     : \\(scalar\\)")
  expect_output(print(b), "Chunking  : \\(scalar\\)")
})

test_that("str() of an array", {
  expect_output(str(make_tree()[["/a"]]), "Zarr array: \\[float64\\] shape \\[4, 6\\] chunk \\[2, 3\\]")
})

# ==== Attributes ==============================================================

test_that("print() shows nested, list and vector attributes", {
  a <- make_tree()[["/a"]]
  a$set_attribute("units", "K")
  a$set_attribute("valid_range", c(0, 100))
  a$set_attribute("flags", list(1, 2, 3))
  a$set_attribute("source/model", "EC-Earth3")
  a$set_attribute("source/run", 1L)
  a$append_array_attribute("history", list(step = "regrid"))
  a$append_array_attribute("history", "plain note")
  out <- capture.output(print(a))
  expect_true(any(grepl("^units *: K$", out)))
  expect_true(any(grepl("^valid_range *: \\[0, 100\\]$", out)))
  expect_true(any(grepl("^flags *: \\[1, 2, 3\\]$", out)))
  expect_true(any(grepl("^source *:$", out)))
  expect_true(any(grepl("^  model *: EC-Earth3$", out)))
  expect_true(any(grepl("^history *:$", out)))
  expect_true(any(grepl("^  \\[1\\]$", out)))
  expect_true(any(grepl("^    step *: regrid$", out)))
  expect_true(any(grepl("^    plain note$", out)))
})

test_that("print_attributes() flags unsaved edits", {
  a <- make_tree()[["/a"]]
  a$set_attribute("units", "K")
  expect_output(a$print_attributes(dirty = TRUE), "Attributes \\(\\*\\)")
  expect_silent(create_zarr()$root$print_attributes())
})

test_that("attribute() retrieves values by path", {
  a <- make_tree()[["/a"]]
  a$set_attribute("source/model", "EC-Earth3")
  a$append_array_attribute("history", list(step = "regrid"))
  a$append_array_attribute("history", list(step = "mask"))
  expect_equal(a$attribute("source/model"), "EC-Earth3")
  expect_equal(a$attribute("history/2/step"), "mask")
  expect_equal(a$attribute("/source//model"), "EC-Earth3")
})

test_that("attribute() returns NULL for anything that is not there", {
  a <- make_tree()[["/a"]]
  expect_null(a$attribute("units"))                 # no attributes at all
  a$set_attribute("source/model", "EC-Earth3")
  a$append_array_attribute("history", list(step = "regrid"))
  expect_null(a$attribute(""))
  expect_null(a$attribute("missing"))
  expect_null(a$attribute("source/model/deeper"))
  expect_null(a$attribute("history/5"))
  expect_null(a$attribute("history/0"))
})

test_that("delete_attribute() on a node without attributes is a no-op", {
  a <- make_tree()[["/a"]]
  a$delete_attribute("units")
  expect_null(a$attributes)
  a$set_attribute("units", "K")
  a$delete_attribute("")
  expect_equal(a$attributes, list(units = "K"))
})

test_that("delete_attribute() ignores paths through non-list values", {
  a <- make_tree()[["/a"]]
  a$set_attribute("units", "K")
  a$append_array_attribute("history", "plain note")
  a$delete_attribute("units/deeper")
  a$delete_attribute("history/1/deeper")
  expect_equal(a$attributes, list(units = "K", history = list("plain note")))
})

Zarr.options$zarr_theme <- thm
