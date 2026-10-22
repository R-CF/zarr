# Tests for print() and hierarchy() output through the cli package. The
# plain-text equivalents are in test-print.R; make_tree(), cli_out() and
# indent_of() are in helper-print.R. testthat turns off colour and Unicode
# symbols, so cli bullets and symbols are ASCII here; the node glyphs are
# literal strings and are not affected.

skip_if_not_installed("cli")

# ==== zarr object =============================================================

test_that("cli print() of a zarr object in memory", {
  out <- cli_out(print(make_tree()))
  expect_true(any(grepl("Zarr", out)))
  expect_true(any(grepl("Memory store - version 3", out)))
  expect_true(any(grepl("Contents", out)))
  expect_true(any(grepl("Arrays: 2", out)))
  expect_false(any(grepl("Location", out)))
})

test_that("cli print() of a zarr object on the file system", {
  out <- cli_out(print(make_tree(tempfile(fileext = ".zarr"))))
  expect_true(any(grepl("Location  :", out)))
  expect_true(any(grepl("Total size: [0-9.]+ (Bytes|KB)", out)))
})

test_that("cli print() of an uninitialised zarr object", {
  z <- zarr$new(zarr_memorystore$new())
  expect_true(any(grepl("uninitialised", cli_out(print(z)))))
})

test_that("cli print() of a single-array store", {
  out <- cli_out(print(as_zarr(1:10)))
  expect_true(any(grepl("Arrays: 1 (single array store)", out, fixed = TRUE)))
})

test_that("cli print() of a zarr object includes root attributes", {
  z <- make_tree()
  z$root$set_attribute("title", "A tree")
  out <- cli_out(print(z))
  expect_true(any(grepl("Attributes", out)))
  expect_true(any(grepl("title: A tree", out)))
})

# ==== hierarchy() =============================================================

test_that("cli hierarchy() nests groups and arrays", {
  out <- cli_out(make_tree()$hierarchy())
  expect_true(any(grepl("Zarr hierarchy", out)))
  expect_true(any(grepl("☰ / (root group)", out, fixed = TRUE)))
  expect_true(any(grepl("⌗ a [float64] [4, 6]", out, fixed = TRUE)))
  expect_true(any(grepl("⌗ b", out, fixed = TRUE)))
  expect_lt(indent_of(out, "☰ /"), indent_of(out, "☰ grp"))
  expect_lt(indent_of(out, "☰ grp"), indent_of(out, "☰ sub"))
  expect_equal(indent_of(out, "☰ sub"), indent_of(out, "⌗ b"))
})

test_that("cli hierarchy() shows dimension names of arrays", {
  meta <- define_array("int32", c(2L, 3L))$metadata()
  meta$dimension_names <- c("y", "x")
  z <- create_zarr()
  z$add_array("/", "a", meta)
  out <- cli_out(z$hierarchy())
  expect_true(any(grepl("⌗ a [int32] [y = 2, x = 3]", out, fixed = TRUE)))
})

test_that("cli hierarchy() of a single-array store", {
  out <- cli_out(as_zarr(1:10)$hierarchy())
  expect_true(any(grepl("⌗", out, fixed = TRUE)))
  expect_true(any(grepl("[10]", out, fixed = TRUE)))
})

test_that("hierarchy() of an uninitialised zarr object is plain text", {
  z <- zarr$new(zarr_memorystore$new())
  expect_output(z$hierarchy(), "\\(uninitialised\\)")
})

test_that("cli group hierarchy() starts at the group", {
  out <- cli_out(make_tree()[["/grp"]]$hierarchy())
  expect_true(any(grepl("Zarr hierarchy from ☰ /grp", out, fixed = TRUE)))
  expect_true(any(grepl("☰ grp", out, fixed = TRUE)))
  expect_false(any(grepl("⌗ a", out, fixed = TRUE)))
})

# ==== Stores ==================================================================

test_that("cli print() of a memory store shows its capabilities", {
  out <- paste(cli_out(print(zarr_memorystore$new())), collapse = "\n")
  expect_match(out, "Zarr store")
  expect_match(out, "Memory store - version 3")
  expect_match(out, paste(cli::symbol$tick, "Listing"), fixed = TRUE)
  expect_match(out, paste(cli::symbol$tick, "Writing"), fixed = TRUE)
  expect_match(out, paste(cli::symbol$tick, "Deleting"), fixed = TRUE)
  expect_match(out, paste(cli::symbol$cross, "Consolidated metadata"), fixed = TRUE)
})

test_that("cli print() of a local store shows location and size", {
  fn <- tempfile(fileext = ".zarr")
  z <- make_tree(fn)
  out <- cli_out(print(z$store))
  expect_true(any(grepl("Local file system store - version 3", out)))
  expect_true(any(grepl(basename(fn), out, fixed = TRUE)))
  expect_true(any(grepl("Total size: [0-9.]+ (Bytes|KB)", out)))
})

# ==== Groups ==================================================================

test_that("cli print() of a group lists sub-groups and arrays", {
  out <- cli_out(print(make_tree()[["/grp"]]))
  expect_true(any(grepl("Zarr group ☰ grp", out, fixed = TRUE)))
  expect_true(any(grepl("Path      : /grp", out, fixed = TRUE)))
  expect_true(any(grepl("Sub-groups: sub", out, fixed = TRUE)))
  expect_true(any(grepl("Arrays    : b", out, fixed = TRUE)))
})

test_that("cli print() of the root group", {
  out <- cli_out(print(make_tree()$root))
  expect_true(any(grepl("Zarr group ☰ [root]", out, fixed = TRUE)))
})

# ==== Arrays ==================================================================

test_that("cli print() of an array", {
  out <- cli_out(print(make_tree()[["/a"]]))
  expect_true(any(grepl("Zarr array ⌗ a", out, fixed = TRUE)))
  expect_true(any(grepl("Path      : /a", out, fixed = TRUE)))
  expect_true(any(grepl("Data type : float64", out, fixed = TRUE)))
  expect_true(any(grepl("Shape     : 4, 6", out, fixed = TRUE)))
  expect_true(any(grepl("Chunk grid: 2, 2 [2 x 3]", out, fixed = TRUE)))
})

test_that("cli print() of an array shows dimension names", {
  meta <- define_array("int32", c(2L, 3L))$metadata()
  meta$dimension_names <- c("y", "x")
  a <- create_zarr()$add_array("/", "a", meta)
  out <- cli_out(print(a))
  expect_true(any(grepl("Shape     : 2, 3 [y, x]", out, fixed = TRUE)))
})

test_that("cli print() of a scalar array", {
  out <- cli_out(print(make_tree()[["/grp/b"]]))
  expect_true(any(grepl("Shape     : (scalar)", out, fixed = TRUE)))
  expect_true(any(grepl("Chunk grid: (scalar)", out, fixed = TRUE)))
})

# ==== Attributes ==============================================================

test_that("cli print() shows scalar and vector attributes", {
  a <- make_tree()[["/a"]]
  a$set_attribute("units", "K")
  a$set_attribute("valid_range", c(0, 100))
  a$set_attribute("flags", list(1, 2, 3))
  out <- cli_out(print(a))
  expect_true(any(grepl("Attributes", out)))
  expect_true(any(grepl("units: K", out, fixed = TRUE)))
  expect_true(any(grepl("valid_range: [0, 100]", out, fixed = TRUE)))
  expect_true(any(grepl("flags: [1, 2, 3]", out, fixed = TRUE)))
})

test_that("cli print() nests object attributes", {
  a <- make_tree()[["/a"]]
  a$set_attribute("source/model", "EC-Earth3")
  a$set_attribute("source/run", 1L)
  out <- cli_out(print(a))
  expect_true(any(grepl("source:", out, fixed = TRUE)))
  expect_true(any(grepl("model: EC-Earth3", out, fixed = TRUE)))
  expect_true(any(grepl("run: 1", out, fixed = TRUE)))
  expect_lt(indent_of(out, "source:"), indent_of(out, "model:"))
})

test_that("cli print() itemises arrays of objects and scalars", {
  a <- make_tree()[["/a"]]
  a$append_array_attribute("history", list(step = "regrid"))
  a$append_array_attribute("history", "plain note")
  out <- cli_out(print(a))
  expect_true(any(grepl("history:", out, fixed = TRUE)))
  expect_true(any(grepl("Item 1", out, fixed = TRUE)))
  expect_true(any(grepl("Item 2", out, fixed = TRUE)))
  expect_true(any(grepl("step: regrid", out, fixed = TRUE)))
  expect_true(any(grepl("plain note", out, fixed = TRUE)))
  expect_lt(indent_of(out, "Item 1"), indent_of(out, "step:"))
})

test_that("cli print_attributes() flags unsaved edits", {
  a <- make_tree()[["/a"]]
  a$set_attribute("units", "K")
  out <- cli_out(a$print_attributes(dirty = TRUE))
  expect_true(any(grepl("Attributes (*)", out, fixed = TRUE)))
})

test_that("cli attribute values with braces are printed literally", {
  a <- make_tree()[["/a"]]
  a$set_attribute("template", "{x}")
  out <- cli_out(print(a))
  expect_true(any(grepl("template: {x}", out, fixed = TRUE)))
})

# ==== save_to() ===============================================================

test_that("cli save_to() reports progress when verbose", {
  out <- cli_out(make_tree()$save_to(tempfile(fileext = ".zarr"), verbose = TRUE))
  expect_true(any(grepl("Created group ☰", out, fixed = TRUE)))
  expect_true(any(grepl("Created array ⌗", out, fixed = TRUE)))
  expect_true(any(grepl("(2/2)", out, fixed = TRUE)))
})
