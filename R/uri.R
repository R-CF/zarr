# This file contains utility functions to encode and decode file paths using
# RFC 8089 and RFC 3986. These functions support UTF-8 characters for both
# encoding and decoding.

# Encode a single path segment, but keep Windows drive letters intact
.percent_encode_segment <- function(x, is_first = FALSE, is_windows = FALSE) {
  if (is_first && is_windows && grepl("^[A-Za-z]:$", x)) x  # keep the colon
  else utils::URLencode(x, reserved = TRUE)
}

# Convert local path -> RFC 8089 file URL
path_to_uri <- function(path) {
  is_windows <- .Platform$OS.type == "windows"
  if (!is_windows)
    path <- path.expand(path)  # tilde expansion

  is_abs <- if (is_windows)
    grepl("^[A-Za-z]:", path) || startsWith(path, "/") || startsWith(path, "//")
  else
    startsWith(path, "/")

  if (!is_abs) {
    # Relative path
    parts <- strsplit(path, "/", fixed = TRUE)[[1L]]
    parts <- parts[nzchar(parts)]
    enc <- vapply(seq_along(parts), function(i)
      .percent_encode_segment(parts[i], is_first = (i == 1L), is_windows), "")
    return(sprintf("file:%s", paste(enc, collapse = "/")))
  }

  path <- normalizePath(path, winslash = "/", mustWork = FALSE)

  if (is_windows) {
    # UNC path
    if (grepl("^//", path)) {
      parts <- strsplit(sub("^//", "", path), "/", fixed = TRUE)[[1L]]
      parts <- parts[nzchar(parts)]
      authority <- parts[1L]
      rest <- character(0L)
      if (length(parts) > 1L) {
        rest <- paste(vapply(parts[-1L], .percent_encode_segment, "", is_windows), collapse = "/")
      }
      return(sprintf("file://%s/%s", authority, rest))
    }
    # Drive letter
    if (grepl("^[A-Za-z]:", path)) {
      parts <- strsplit(path, "/", fixed = TRUE)[[1]]
      parts <- parts[nzchar(parts)]
      enc <- vapply(seq_along(parts), function(i)
        .percent_encode_segment(parts[i], is_first = (i == 1L), is_windows), "")
      return(sprintf("file:///%s", paste(enc, collapse = "/")))
    }
  }

  # Unix absolute
  parts <- strsplit(path, "/", fixed = TRUE)[[1L]]
  parts <- parts[nzchar(parts)]
  enc <- vapply(parts, .percent_encode_segment, "")
  return(sprintf("file:///%s", paste(enc, collapse = "/")))
}

# Decode
uri_to_path <- function(url) {
  if(!startsWith(url, "file:"))
    return(url)

  u <- sub("^file:", "", url)
  is_windows <- .Platform$OS.type == "windows"

  # Relative
  if (!startsWith(u, "/") && !grepl("^//", u)) {
    parts <- strsplit(u, "/", fixed = TRUE)[[1L]]
    parts <- parts[nzchar(parts)]
    parts <- vapply(parts, utils::URLdecode, "")
    return(paste(parts, collapse = .Platform$file.sep))
  }

  # UNC
  if (is_windows && startsWith(u, "//")) {
    parts <- strsplit(sub("^//", "", u), "/", fixed = TRUE)[[1L]]
    parts <- parts[nzchar(parts)]
    parts <- vapply(parts, utils::URLdecode, "")
    return(sprintf("//%s", paste(parts, collapse = "/")))
  }

  # Absolute
  path <- sub("^/*", "", u)
  parts <- strsplit(path, "/", fixed = TRUE)[[1L]]
  parts <- parts[nzchar(parts)]
  parts <- vapply(parts, utils::URLdecode, "")

  if (is_windows && grepl("^[A-Za-z]:$", parts[1L]))
    paste(parts, collapse = "/")
  else
    paste0("/", paste(parts, collapse = "/"))
}
