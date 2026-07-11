# 5. Parallel processing

Reading large Zarr arrays from remote stores can be slow when many
chunks or shards need to be fetched sequentially. The `zarr` package
supports parallel chunk and shard fetching via the `future` ecosystem,
which can significantly reduce elapsed time for large selections over
HTTP stores or high-throughput local storage systems.

> Parallel processing in `zarr` is opt-in and requires the `future` and
> `future.apply` packages to be installed. Install them with
> `install.packages(c("future", "future.apply"))`.

## How it works

When reading a Zarr array, the package must fetch and decode one or more
chunks (for regular arrays) or one or more shard files (for sharded
arrays). By default these fetches happen sequentially — one after the
other. When a parallel `future` plan is active and the number of chunks
or shards to fetch exceeds a configurable threshold, the package
switches to parallel fetching: all required chunks or shards are fetched
and decoded concurrently, and the results are assembled into the output
array once all workers have finished.

The parallel and sequential paths produce identical results. The only
difference is elapsed time.

## Setting up a parallel plan

Parallelism is controlled entirely by the `future` package. You set a
“plan” that tells `future` how many workers to use and how to run them.
The most common plan for local parallel execution is `multisession`,
which starts a separate R process for each worker:

``` r

library(future)

# Use 4 parallel workers
plan(multisession, workers = 4)
```

Once a parallel plan is active, all subsequent `zarr` read operations
that meet the threshold (see below) will automatically use parallel
fetching. No other changes to your code are needed.

To return to sequential execution:

``` r

plan(sequential)
```

## A worked example

Here we read from the GeoTESSERA satellite imagery store, a publicly
accessible sharded Zarr v3 store over HTTP. Each shard file is tens of
megabytes, making it a good candidate for parallel fetching when a
selection spans multiple shards.

``` r

library(zarr)
library(future)

z   <- open_zarr("https://dl2.geotessera.org/zarr/v2/store.zarr/utm31/rgb")
arr <- z[["/"]]

# Sequential read spanning 4 shards
plan(sequential)
system.time(r1 <- arr[9, 1, 4000:8200, 44000:50000])
#    user  system elapsed
#   4.283   0.384   9.615

# Parallel read of the same selection
plan(multisession, workers = 4)
system.time(r2 <- arr[9, 1, 4000:8200, 44000:50000])
#    user  system elapsed
#   0.550   0.251   9.247

# Results are identical
identical(r1, r2)
#> [1] TRUE
```

In this example the elapsed time improvement is modest because the
bottleneck is network bandwidth — all workers share the same internet
connection. On a faster connection, or when reading from a
high-throughput local storage system such as a RAID array, the gains are
more pronounced. The user time (CPU time) reduction from 4.3s to 0.6s
confirms that decoding is being parallelised effectively.

## The parallel threshold

Starting a parallel task has a fixed overhead — serialising objects,
sending them to workers, collecting results. For small arrays with only
a few chunks this overhead can exceed the time saved by parallelism,
making parallel execution *slower* than sequential. This is illustrated
here with a small 6-chunk array:

``` r

z   <- open_zarr("https://raw.githubusercontent.com/R-CF/zarr/main/inst/extdata/africa.zarr/tas")
arr <- z[["/"]]

plan(sequential)
system.time(r1 <- arr[])
#    user  system elapsed
#   0.036   0.005   0.248

plan(multisession, workers = 4)
system.time(r2 <- arr[])
#    user  system elapsed
#   0.053   0.019   0.758
```

To avoid this, `zarr` only uses parallel fetching when the number of
chunks or shards to fetch exceeds a threshold. The default threshold is:

``` r

zarr_options()$parallel_threshold
#> [1] 20
```

You can adjust this to suit your data and environment. The right value
depends on several factors:

- **Chunk or shard size** — larger chunks take longer to fetch and
  decode, so parallelism pays off with fewer of them. For sharded stores
  with heavy compression, a threshold of 2–4 may be appropriate.
- **Network latency and bandwidth** — on a high-latency connection
  (e.g. cloud storage accessed from a home connection) parallelism helps
  even for moderate chunk counts. On a low-latency local network it
  matters less.
- **Storage throughput** — on a RAID system or NVMe array, parallel
  reads can saturate the storage bandwidth; on a single spinning disk
  they may not help.

To set a lower threshold for a sharded store where each shard is large:

``` r

zarr_options(key = "parallel_threshold", value = 2L)
```

To effectively disable parallel fetching regardless of the active plan
(while keeping `future` loaded for other purposes), set a very high
value:

``` r

zarr_options(key = "parallel_threshold", value = .Machine$integer.max)
```

## What is parallelised

Parallel fetching applies to both regular chunked arrays and sharded
arrays:

- **Regular arrays** — each chunk is fetched and decoded in a separate
  worker. The number of concurrent workers is capped by your `future`
  plan (e.g. `workers = 4` means at most 4 chunks are fetched
  simultaneously).
- **Sharded arrays** — each shard file is fetched and decoded in a
  separate worker. Within each worker, the shard index is read first,
  followed by a single coalesced byte-range request covering all
  required inner chunks. The inner chunks are then decoded sequentially
  within the worker.

In both cases, **assembly of the results into the output array is always
sequential** — results from workers are collected and placed into the
output array one at a time. This is safe by design and ensures
correctness regardless of the order in which workers complete.

## Caching behaviour

The `zarr` package caches decoded chunks and shards to speed up repeated
or overlapping reads in sequential mode. When parallel fetching is
active, each worker operates on its own independent copy of the relevant
IO objects and the decoded results are not written back to the main
session’s cache. This means:

- The cache is not populated by parallel reads.
- A subsequent read of the same data in the same session will re-fetch
  from the store if a parallel plan is active.

If you expect to make many overlapping reads of the same data, you may
get better overall performance by switching to a sequential plan and
benefiting from the cache:

``` r

# First read: fetch from store and populate cache
plan(sequential)
r1 <- arr[1:100, 1:100, 1]

# Second overlapping read: served from cache, near-instant
r2 <- arr[1:50, 1:50, 1]
```

## Notes on worker setup

**Package availability** — each worker loads the `zarr` package
automatically. If `zarr` has compiled code (which it does, for the array
assembly step), the package must be installed — not just loaded via
`devtools::load_all()` — for workers to use it. During development, run
`devtools::install()` before starting a parallel plan, and reset the
plan after each reinstall:

``` r

devtools::install()
plan(sequential)
plan(multisession, workers = 4)
```

**Windows compatibility** — `plan(multisession)` works on all platforms
including Windows. `plan(multicore)` (fork-based) is not available on
Windows and is not recommended for use with `zarr`.

**Number of workers** — as a starting point, set `workers` to the number
of physical cores on your machine. Beyond that, additional workers
compete for the same network bandwidth or storage throughput and may not
help. For HTTP stores the optimal number of workers is often 2–4
regardless of core count.
