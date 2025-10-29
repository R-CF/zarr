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

# This function takes a prefix and turns it into a path that points to the same
# object as the prefix.
.prefix2path <- function(path) {
  paste0('/', sub('/$', '', path))
}
