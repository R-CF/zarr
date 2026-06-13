test_that("set_attribute: Adding scalar and array attributes", {
  z <- as_zarr(array(runif(10), c(5, 2)), 'my_data')
  node <- z[['/my_data']]

  # Simple scalar attributes
  node$set_attribute("simple_str", "hello")
  expect_equal(node$attributes[["simple_str"]], "hello")

  node$set_attribute("simple_int", 42L)
  expect_equal(node$attributes[["simple_int"]], 42L)

  node$set_attribute("simple_dbl", 3.14)
  expect_equal(node$attributes[["simple_dbl"]], 3.14)

  node$set_attribute("simple_lgl", TRUE)
  expect_equal(node$attributes[["simple_lgl"]], TRUE)

  # Overwrite existing
  node$set_attribute("simple_str", "world")
  expect_equal(node$attributes[["simple_str"]], "world")

  # Atomic vector attributes
  node$set_attribute("vec_chr", c("a", "b", "c"))
  expect_equal(node$attributes[["vec_chr"]], c("a", "b", "c"))

  node$set_attribute("vec_int", 1:5)
  expect_equal(node$attributes[["vec_int"]], 1:5)

  node$set_attribute("vec_dbl", c(1.1, 2.2, 3.3))
  expect_equal(node$attributes[["vec_dbl"]], c(1.1, 2.2, 3.3))

  node$set_attribute("vec_lgl", c(TRUE, FALSE, TRUE))
  expect_equal(node$attributes[["vec_lgl"]], c(TRUE, FALSE, TRUE))

  # Nested path creates intermediate nodes
  node$set_attribute("a/b/c", "deep")
  expect_equal(node$attributes[["a"]][["b"]][["c"]], "deep")

  # Sibling at same level
  node$set_attribute("a/b/d", "sibling")
  expect_equal(node$attributes[["a"]][["b"]][["c"]], "deep")
  expect_equal(node$attributes[["a"]][["b"]][["d"]], "sibling")

  # New branch off existing parent
  node$set_attribute("a/e", "branch")
  expect_equal(node$attributes[["a"]][["b"]][["c"]], "deep")
  expect_equal(node$attributes[["a"]][["e"]], "branch")

  # Named list as attribute (JSON object)
  obj <- list(name = "proj", version = 1L, active = TRUE)
  node$set_attribute("my_obj", obj)
  expect_equal(node$attributes[["my_obj"]], obj)

  # Nested named list
  nested <- list(outer = list(inner = list(value = 42L)))
  node$set_attribute("nested_obj", nested)
  expect_equal(node$attributes[["nested_obj"]][["outer"]][["inner"]][["value"]], 42L)

  # Overwrite scalar with nested path
  node$set_attribute("x", "scalar")
  node$set_attribute("x/y", "new")
  expect_equal(node$attributes[["x"]][["y"]], "new")
})

test_that("append_array_attribute", {
  z <- as_zarr(array(runif(10), c(5, 2)), 'my_data')
  node <- z[['/my_data']]

  node$append_array_attribute("arr", "first")
  expect_equal(node$attributes[["arr"]], list("first"))

  # Appends to end by default"
  node$append_array_attribute("arr", "second")
  node$append_array_attribute("arr", "third")
  expect_equal(node$attributes[["arr"]], list("first", "second", "third"))

  # after = 0 prepends
  node$append_array_attribute("arr", "zeroth", after = 0L)
  expect_equal(node$attributes[["arr"]], list("zeroth", "first", "second", "third"))

  # after = n inserts at position
  node$append_array_attribute("arr", "inserted", after = 1L)
  expect_equal(node$attributes[["arr"]], list("zeroth", "inserted", "first", "second", "third"))

  # Array of named lists (JSON array of objects)
  conv1 <- list(name = "proj", uuid = "aaa-111")
  conv2 <- list(name = "cs",   uuid = "bbb-222")
  conv3 <- list(name = "ref",  uuid = "ccc-333")

  node$append_array_attribute("zarr_conventions", conv1)
  node$append_array_attribute("zarr_conventions", conv2)
  node$append_array_attribute("zarr_conventions", conv3, after = 0L)

  atts <- node$attributes[["zarr_conventions"]]
  expect_equal(length(atts), 3L)
  expect_equal(atts[[1L]], conv3)
  expect_equal(atts[[2L]], conv1)
  expect_equal(atts[[3L]], conv2)

  # Nested path
  node$append_array_attribute("a/b/arr", "x")
  node$append_array_attribute("a/b/arr", "y")
  expect_equal(node$attributes[["a"]][["b"]][["arr"]], list("x", "y"))

  # Errors on named list target
  node$set_attribute("obj", list(key = "val"))
  expect_error(node$append_array_attribute("obj", "x"), "not an array")

  # Modify field inside array element
  node$append_array_attribute("arr", list(a = 1L, b = 2L), after = 0L)

  node$set_attribute("arr/1/a", 99L)
  expect_equal(node$attributes[["arr"]][[1L]][["a"]], 99L)
  expect_equal(node$attributes[["arr"]][[1L]][["b"]], 2L)   # untouched

  # Add new field inside array element
  node$append_array_attribute("arr", list(a = 1L))
  node$append_array_attribute("arr", list(a = 2L))

  node$set_attribute("arr/2/b", "new")
  expect_equal(node$attributes[["arr"]][[2L]][["b"]], "new")
  expect_equal(node$attributes[["arr"]][[1L]][["b"]], 2L)  # untouched

  # Deep nesting through multiple arrays
  node$append_array_attribute("outer", list(inner = list("x", "y")))
  node$set_attribute("outer/1/inner/2", "z")
  expect_equal(node$attributes[["outer"]][[1L]][["inner"]][[2L]], "z")
  expect_equal(node$attributes[["outer"]][[1L]][["inner"]][[1L]], "x")  # untouched

  # Atomic vector element via index
  node$set_attribute("vec", c("a", "b", "c"))
  node$set_attribute("vec/2", "B")
  expect_equal(node$attributes[["vec"]][[2L]], "B")
})

test_that("delete_attribute", {
  z <- as_zarr(array(runif(10), c(5, 2)), 'my_data')
  node <- z[['/my_data']]

  # Simple scalar
  node$set_attribute("to_delete", "bye")
  node$set_attribute("to_keep", "hi")
  node$delete_attribute("to_delete")
  expect_null(node$attributes[["to_delete"]])
  expect_equal(node$attributes[["to_keep"]], "hi")

  # Absent attribute is silent
  expect_silent(node$delete_attribute("does_not_exist"))

  # Nested named attribute
  node$set_attribute("a/b/c", "deep")
  node$set_attribute("a/b/d", "sibling")
  node$delete_attribute("a/b/c")
  expect_null(node$attributes[["a"]][["b"]][["c"]])
  expect_equal(node$attributes[["a"]][["b"]][["d"]], "sibling")

  # Intermediate node removes subtree
  node$set_attribute("a/b/c", "x")
  node$set_attribute("a/b/d", "y")
  node$set_attribute("a/e",   "z")
  node$delete_attribute("a/b")
  expect_null(node$attributes[["a"]][["b"]])
  expect_equal(node$attributes[["a"]][["e"]], "z")

  # Entire array
  node$append_array_attribute("arr", "a")
  node$append_array_attribute("arr", "b")
  node$delete_attribute("arr")
  expect_null(node$attributes[["arr"]])

  # Array element by index
  node$append_array_attribute("arr", "a")
  node$append_array_attribute("arr", "b")
  node$append_array_attribute("arr", "c")
  node$delete_attribute("arr/2")
  expect_equal(node$attributes[["arr"]], list("a", "c"))

  # Out-of-range index is silent
  node$append_array_attribute("arr", "a")
  expect_silent(node$delete_attribute("arr/99"))
  expect_equal(node$attributes[["arr"]], list("a", "c", "a"))

  # Field inside array element
  node$delete_attribute('arr')
  node$append_array_attribute("arr", list(a = 1L, b = 2L))
  node$append_array_attribute("arr", list(a = 3L, b = 4L))
  node$delete_attribute("arr/1/b")
  expect_null(node$attributes[["arr"]][[1L]][["b"]])
  expect_equal(node$attributes[["arr"]][[1L]][["a"]], 1L)   # untouched
  expect_equal(node$attributes[["arr"]][[2L]], list(a = 3L, b = 4L))  # untouched

  # Deeply nested through multiple arrays
  node$append_array_attribute("outer", list(inner = list(list(x = 1L, y = 2L),
                                                         list(x = 3L, y = 4L))))
  node$delete_attribute("outer/1/inner/1/y")
  expect_null(node$attributes[["outer"]][[1L]][["inner"]][[1L]][["y"]])
  expect_equal(node$attributes[["outer"]][[1L]][["inner"]][[1L]][["x"]], 1L)
  expect_equal(node$attributes[["outer"]][[1L]][["inner"]][[2L]], list(x = 3L, y = 4L))

  # Last attribute removes attributes entry
  node$delete_attribute("to_keep")
  node$delete_attribute("a")
  node$delete_attribute("arr")
  node$delete_attribute("outer")
  expect_null(node$metadata[["attributes"]])
})

test_that("round-trip: set then delete restores original state", {
  z <- as_zarr(array(runif(10), c(5, 2)), 'my_data')
  node <- z[['/my_data']]

  original <- node$attributes
  node$set_attribute("tmp/nested", "value")
  node$delete_attribute("tmp")
  expect_equal(node$attributes, original)

  # meta_dirty flag: set on write, cleared on save
  # Assumes access to private$.meta_dirty via node$.__enclos_env__$private
  p <- node$.__enclos_env__$private
  expect_true(p$.meta_dirty)
  node$set_attribute("x", 1L)
  expect_true(p$.meta_dirty)
  node$save()
  expect_false(p$.meta_dirty)
})
