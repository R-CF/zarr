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

is_valid_uri <- function(uri) {
  if (!is.character(uri) || length(uri) != 1L) return(FALSE)

  # RFC 3986 Appendix B decomposition regex
  m <- regmatches(uri, regexec(
    "^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\\?([^#]*))?(#(.*))?$",
    uri, perl = TRUE
  ))[[1L]]

  if (length(m) == 0L) return(FALSE)

  scheme    <- m[3L]   # e.g. "https"
  authority <- m[5L]   # e.g. "user@host:port"
  path      <- m[6L]   # e.g. "/a/b/c"
  query     <- m[8L]   # e.g. "key=val"
  fragment  <- m[10L]  # e.g. "section1"

  # -- scheme (required): ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
  if (!grepl("^[A-Za-z][A-Za-z0-9+\\-\\.]*$", scheme))
    return(FALSE)

  # Allowed percent-encoded triplet
  pct   <- "%[0-9A-Fa-f]{2}"
  # Unreserved characters
  unreserved <- "A-Za-z0-9\\-._~"
  # Sub-delimiters
  sub_delims <- "!$&'()*+,;="

  # -- authority (optional): [ userinfo "@" ] host [ ":" port ]
  if (nchar(m[4L]) > 0L) {  # authority component was present (leading // existed)
    auth <- authority

    # Strip userinfo if present
    if (grepl("@", auth, fixed = TRUE)) {
      userinfo <- sub("@[^@]*$", "", auth)
      auth     <- sub("^.*@", "", auth)
      valid_userinfo_char <- paste0("[", unreserved, sub_delims, ":]")
      if (!grepl(sprintf("^(%s|%s)*$", valid_userinfo_char, pct), userinfo, perl = TRUE))
        return(FALSE)
    }

    # Strip port if present
    if (grepl(":[0-9]*$", auth))
      auth <- sub(":[0-9]*$", "", auth)

    # host: IP-literal, IPv4, or reg-name
    ip_literal <- "^\\[.*\\]$"
    ipv4       <- "^([0-9]{1,3}\\.){3}[0-9]{1,3}$"
    reg_name   <- sprintf("^([%s%s]|%s)*$", unreserved, sub_delims, pct)

    if (!grepl(ip_literal, auth, perl = TRUE) &&
        !grepl(ipv4,       auth, perl = TRUE) &&
        !grepl(reg_name,   auth, perl = TRUE))
      return(FALSE)
  }

  # -- path: pchar = unreserved / pct-encoded / sub-delims / ":" / "@"
  pchar    <- sprintf("[%s%s:@]|%s", unreserved, sub_delims, pct)
  path_rx  <- sprintf("^(%s|/)*$", pchar)
  if (!grepl(path_rx, path, perl = TRUE))
    return(FALSE)

  # -- query: *( pchar / "/" / "?" )
  qf_rx <- sprintf("^(%s|[/?])*$", pchar)
  if (nchar(query) > 0L && !grepl(qf_rx, query, perl = TRUE))
    return(FALSE)

  # -- fragment: same grammar as query
  if (nchar(fragment) > 0L && !grepl(qf_rx, fragment, perl = TRUE))
    return(FALSE)

  TRUE
}
