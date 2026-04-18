# Check the name of a node before setting it.
# From the Zarr specification, the following constraints apply to node names:
# * must not be the empty string (""), except for the root node
# * must not be a string composed only of period characters, e.g. "." or ".."
# * must not start with the reserved prefix "__".
#
# Only punctuation characters in the set [-, _, .] are allowed.  As an extension
# to the Zarr specification, characters and numbers can be any UTF-8 code point.
# When portability is an issue, restrict characters and numbers to the set
# [A-Za-z0-9].
.is_valid_node_name <- function(name) {
  nzchar(name) > 0L &&
  !grepl('^\\.*$', name) &&
  !grepl('^__', name) &&
  grepl("^[\\p{L}\\p{M}\\p{N}\\._-]+$", name, perl = TRUE)
}

# This function takes a path and turns it into a key by stripping the leading /
.path2key <- function(path) {
  substr(path, 2L, 10000L)
}

# This function takes a path and turns it into a prefix that points to the same
# object as the path.
.path2prefix <- function(path) {
  paste0(substr(path, 2L, 10000L), '/')
}

# This function takes a prefix and turns it into a key that points to the same
# object as the prefix.
.prefix2key <- function(prefix) {
  sub('/$', '', prefix)
}

# This function takes a prefix and turns it into a path that points to the same
# object as the prefix.
.prefix2path <- function(prefix) {
  paste0('/', sub('/$', '', prefix))
}

.size_string <- function(size_in_bytes) {
  if (size_in_bytes < 1024) {
    return(paste(size_in_bytes, "Bytes"))
  } else if (size_in_bytes < 1048576) {
    return(paste(round(size_in_bytes / 1024, 2), "KB"))
  } else if (size_in_bytes < 1073741824) {
    return(paste(round(size_in_bytes / 1048576, 2), "MB"))
  } else {
    return(paste(round(size_in_bytes / 1073741824, 2), "GB"))
  }
}

#' Convert a list into a data.frame while shortening long strings. List elements
#' are pasted together.
#' @param list A `list` with data to print, usually metadata.
#' @param width Maximum width of character entries. If entries are longer than
#'   width - 3, they are truncated and then '...' added.
#' @return data.frame with slim columns
#' @noRd
.slim.data.frame <- function(list, width = 50L) {
  maxw <- width - 3L
  len <- length(list)
  if (len) {
    out <- vector('character', len)
    for (i in seq(len)) {
      c <- list[[i]]
      c <- paste(c, collapse = ", ")
      if (nchar(c) > width)
        c <- paste0(substring(c, 1, maxw), '...')
      out[i] <- c
    }
    out <- data.frame(name = names(list), value = out)
    out
  } else data.frame()
}

#' Test if vectors `x` and `y` have near-identical values.
#' @noRd
.near <- function(x, y) {
  abs(x - y) <= max(Zarr.options$eps * max(abs(x), abs(y)), 1e-12)
}

#' Determines the protocol to be used with a specified store location.
#' @noRd
.protocol <- function(loc) {
  if (grepl('^http(s)?://', loc, ignore.case = TRUE))
    'http'
  else
    'local'
}

#' Register a Zarr domain for this session
#' @param domain An instance of a class descending from `zarr_domain`.
#' @return Nothing.
#' @export
zarr_register_domain <- function(domain) {
  if (inherits(domain, "zarr_domain"))
    Zarr.domains[[domain$name]] <- domain
}

#' Unregister a Zarr domain from this session
#' @param domain The name of the `zarr_domain` to unregister.
#' @return Nothing.
#' @export
zarr_unregister_domain <- function(domain) {
  if (is.character(domain))
    rm(list = domain, envir = Zarr.domains, inherits = FALSE)
}

#' List the Zarr domains registered in this session
#' @return A list with instances of `zarr_domain` descendant classes.
#' @export
zarr_domains <- function() {
  as.list(Zarr.domains)
}

#' Build a Zarr node
#'
#' This function polls the registered domains to see if they want to claim and
#' build the indicated node in the Zarr hierarchy. If no domain claims the node
#' a generic Zarr group or array is created.
#' @param name Character, the name of the node to be created.
#' @param metadata List, the metadata of the node to be created.
#' @param parent A `zarr_node`, the parent of the node to be created. `NULL` for
#'   the root node.
#' @param store The `zarr_store` where the node is stored.
#' @return The newly created node, either from a domain or a generic
#'   `zarr_group` or `zarr_array`.
#' @noRd
.buildNode <- function(name, metadata, parent, store) {
  for (d in zarr_domains()) {
    node <- d$build(name, metadata, parent, store)
    if (inherits(node, 'zarr_node')) return(node)
  }

  # Fallback: return generic node
  if (metadata$node_type == 'group')
    zarr_group$new(name, metadata, parent, store)
  else
    zarr_array$new(name, metadata, parent, store)
}
