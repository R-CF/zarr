# Tests for the convention agents and for domain registration.

# ==== zarr_convention (base class) ============================================

test_that("convention base class exposes its identity", {
  cv <- zarr_convention$new("test", "https://example.org/schema.json", "0000-1111")
  expect_equal(cv$name, "test")
  expect_equal(cv$schema, "https://example.org/schema.json")
  expect_equal(cv$uuid, "0000-1111")
  cv$spec <- "https://example.org/spec"
  cv$description <- "A test convention"
  expect_equal(cv$spec, "https://example.org/spec")
  expect_equal(cv$description, "A test convention")
  expect_null(cv$set())
  expect_equal(cv$as_list(), list())
  expect_null(cv$clear())
})

test_that("register() adds a full or brief entry to zarr_conventions", {
  cv <- zarr_convention_uom$new()
  atts <- cv$register(list(other = 1))
  expect_equal(atts$other, 1)
  expect_length(atts$zarr_conventions, 1L)
  expect_equal(atts$zarr_conventions[[1L]],
               list(schema_url = cv$schema, spec_url = cv$spec, uuid = cv$uuid,
                    name = "uom", description = cv$description))

  brief <- zarr_convention_ref$new()$register(list(), brief = TRUE)
  expect_equal(names(brief$zarr_conventions[[1L]]), c("schema_url", "name"))
})

test_that("register() does not add the same convention twice", {
  uom <- zarr_convention_uom$new()
  ref <- zarr_convention_ref$new()
  atts <- uom$register(list())
  atts <- ref$register(atts)
  atts <- uom$register(atts)
  expect_length(atts$zarr_conventions, 2L)
})

test_that("zarr_conventions() lists the supported conventions", {
  cv <- zarr_conventions()
  expect_s3_class(cv, "data.frame")
  expect_setequal(cv$name, c("ref", "uom"))
  expect_equal(cv$uuid[cv$name == "uom"], zarr_convention_uom$new()$uuid)
})

# ==== zarr_convention_uom =====================================================

test_that("uom defaults to unity in UCUM 2.2", {
  expect_equal(zarr_convention_uom$new()$as_list(), list(ucum = list(version = "2.2", unit = "1")))
})

test_that("uom set() with unit only keeps the default version", {
  uom <- zarr_convention_uom$new()
  uom$set("K")
  expect_equal(uom$as_list(), list(ucum = list(version = "2.2", unit = "K")))
})

test_that("uom set() with all arguments, then clear()", {
  uom <- zarr_convention_uom$new()
  uom$set("m/s", "2.1", "wind speed")
  expect_equal(uom$as_list(),
               list(ucum = list(version = "2.1", unit = "m/s"), description = "wind speed"))
  uom$clear()
  expect_equal(uom$as_list(), list(ucum = list(version = "2.2", unit = "1")))
})

test_that("uom set() validates its arguments", {
  uom <- zarr_convention_uom$new()
  expect_error(uom$set(1), "`unit` must be a character string")
  expect_error(uom$set("K", ""), "`version` must be a character string")
  expect_error(uom$set("K", "2.2", 3), "`description` must be a character string")
})

# ==== zarr_convention_ref =====================================================

test_that("ref with a node only", {
  ref <- zarr_convention_ref$new()
  ref$set("../lat")
  expect_equal(ref$as_list(), list(node = "../lat"))
})

test_that("ref with node, uri and attribute", {
  ref <- zarr_convention_ref$new()
  ref$set("/grp/lat", uri = "https://example.org/other.zarr", attribute = "/units")
  expect_equal(ref$as_list(),
               list(uri = "https://example.org/other.zarr", node = "/grp/lat", attribute = "/units"))
})

test_that("ref accepts escaped JSON pointer tokens", {
  ref <- zarr_convention_ref$new()
  ref$set("lat", attribute = "/a~1b/c~0d")
  expect_equal(ref$as_list()$attribute, "/a~1b/c~0d")
  expect_equal(ref$.__enclos_env__$private$parse_json_pointer("/a~1b/c~0d"), c("a/b", "c~d"))
  expect_equal(ref$.__enclos_env__$private$parse_json_pointer(""), character(0))
})

test_that("ref set() validates its arguments", {
  ref <- zarr_convention_ref$new()
  expect_error(ref$set(""), "`node` must be a character string")
  expect_error(ref$set("lat", uri = 1), "`uri` must be a character string")
  expect_error(ref$set("lat", attribute = "units"), "must be empty or start with")
  expect_error(ref$set("lat", attribute = "/a~2"), "Invalid reference token")
  expect_error(ref$set("lat", attribute = 1), "single character string")
})

test_that("ref as_list() requires a node, also after clear()", {
  ref <- zarr_convention_ref$new()
  expect_error(ref$as_list(), "`node` field must be set")
  ref$set("lat", uri = "https://example.org/a.zarr")
  ref$clear()
  expect_error(ref$as_list(), "`node` field must be set")
})

# ==== Domains =================================================================

# A domain that claims every group called "special" and leaves everything else
# to the generic classes.
special_group <- R6::R6Class("special_group",
  inherit = zarr_group,
  public = list(
    initialize = function(name, metadata, parent) {
      super$initialize(name, metadata, parent, no_create_check = TRUE)
      private$.domain <- "special"
    }
  )
)
special_domain <- R6::R6Class("special_domain",
  inherit = zarr_domain,
  public = list(
    initialize = function() super$initialize("special"),
    build = function(name, metadata, parent, store) {
      if (name == "special" && metadata$node_type == "group")
        special_group$new(name, metadata, parent)
      else FALSE
    }
  )
)

test_that("domain base class properties", {
  d <- special_domain$new()
  expect_equal(d$name, "special")
  expect_true(d$can_read)
  expect_true(d$can_write)
})

test_that("registered domain builds the nodes it claims", {
  fn <- tempfile(fileext = ".zarr")
  z <- create_zarr(fn)
  z$add_group("/", "special")
  z$add_group("/", "plain")

  zarr_register_domain(special_domain$new())
  on.exit(zarr_unregister_domain("special"))
  expect_true("special" %in% names(zarr_domains()))

  z2 <- open_zarr(fn)
  expect_s3_class(z2[["/special"]], "special_group")
  expect_false(inherits(z2[["/plain"]], "special_group"))
  expect_output(print(z2[["/special"]]), "Domain   : special")
})

test_that("unregistered domain no longer builds nodes", {
  fn <- tempfile(fileext = ".zarr")
  create_zarr(fn)$add_group("/", "special")
  zarr_register_domain(special_domain$new())
  zarr_unregister_domain("special")
  expect_false("special" %in% names(zarr_domains()))
  expect_false(inherits(open_zarr(fn)[["/special"]], "special_group"))
})

test_that("zarr_register_domain() ignores objects that are not domains", {
  n <- length(zarr_domains())
  zarr_register_domain(list(name = "fake"))
  expect_length(zarr_domains(), n)
})
