# Create an in-memory Zarr store with string arrays to test that functionality
z_strings <- local({
  # Create an in-memory Zarr store
  z <- create_zarr()

  # Add a scalar array, simple string, fill_value ''
  ab <- define_array('string', 1L)
  ab$remove_codec('blosc')
  ab$fill_value <- ''
  arr <- z$add_array('/', 'scalar1d', ab)
  arr$write('x', selection = list(1L))

  # Add a 1d array with ASCII strings
  ab$shape <- 6L
  arr <- z$add_array('/', 'names1d', ab)
  arr$write(c("alpha", "beta", "gamma", "delta", "epsilon", "zeta"), selection = list(1L:6L))

  # String matrix with ASCII strings
  ab$shape <- c(3L, 4L)
  ab$chunk_shape <- c(2L, 2L)
  ab$fill_value <- 'N/A'
  arr <- z$add_array('/', 'grid2d', ab)
  cols <- paste0('c', 1:4)
  strings <- paste0('r', 1:3, rep(cols, each = 3))
  dim(strings) <- c(3, 4)
  arr$write(strings, selection = list(1L:3L, 1L:4L))

  # Unicode strings
  strings <- c(
    "\u00e9l\u00e8ve",                          # élève
    "\u4e2d\u6587",                             # 中文
    "\U0001f331",                               # 🌱
    "\u0645\u0631\u062d\u0628\u0627",           # مرحبا
    "caf\u00e9"                                 # café
  )
  ab$shape <- 5L
  ab$fill_value <- ''
  arr <- z$add_array('/', 'unicode1d', ab)
  arr$write(strings, selection = list(1L:5L))

  # Sparse vector, second chunk not written
  ab$shape <- 10L
  ab$chunk_shape <- 5L
  ab$fill_value <- 'missing'
  arr <- z$add_array('/', 'sparse1d', ab)
  arr$write(letters[1:5], selection = list(1L:5L))

  z
})
