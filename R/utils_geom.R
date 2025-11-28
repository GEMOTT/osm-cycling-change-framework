
.cache <- function(path, build, inputs = NULL, reuse = TRUE) {
  up_to_date <- file.exists(path) &&
    (is.null(inputs) || max(file.mtime(inputs)) <= file.mtime(path))
  if (reuse && up_to_date) return(readRDS(path))  # skip recomputation
  obj <- build()                                  # compute fresh
  saveRDS(obj, path)                               # save for next time
  obj
}

# Lowercase-safe accessor
.get_chr <- function(x, col){
  nm <- names(x); n <- nrow(x)
  if (col %in% nm) tolower(as.character(x[[col]])) else rep(NA_character_, n)
}

# Safer line normalizer (won’t choke on POINT / GEOMETRYCOLLECTION)
normalize_lines_safe <- function(x){
  if (!inherits(x, "sf") || !nrow(x)) return(x[0, ])
  x <- sf::st_make_valid(x)
  # pull out only the line components from any collections
  x <- suppressWarnings(sf::st_collection_extract(x, "LINESTRING", warn = FALSE))
  # keep only line-like
  keep <- sf::st_geometry_type(x) %in% c("LINESTRING","MULTILINESTRING")
  x <- x[keep, , drop = FALSE]
  if (!nrow(x)) return(x[0, ])
  # explode MULTILINESTRING → LINESTRING; drop empties
  x <- suppressWarnings(sf::st_cast(x, "LINESTRING"))
  x <- x[!sf::st_is_empty(x), , drop = FALSE]
  sf::st_make_valid(x)
}

# length filter for sf LINESTRINGs
len_ok <- function(x, min_len) {
  if (!inherits(x, "sf") || !nrow(x)) return(x)
  x[as.numeric(sf::st_length(x)) >= min_len, , drop = FALSE]
}

# normalise to lines in a working CRS (safe on collections/empties)
to_lines_work <- function(x, crs) {
  x |>
    sf::st_make_valid() |>
    sf::st_zm(drop = TRUE, what = "ZM") |>
    sf::st_transform(crs) |>
    suppressWarnings(sf::st_collection_extract("LINESTRING", warn = FALSE)) |>
    suppressWarnings(sf::st_cast("LINESTRING")) |>
    (\(y) y[!sf::st_is_empty(sf::st_geometry(y)), , drop = FALSE])()
}

len_km <- function(x, crs_m = 25831) {
  if (!inherits(x,"sf") || !nrow(x)) return(0)
  x_m <- sf::st_transform(x, crs_m)
  round(sum(as.numeric(sf::st_length(x_m)), na.rm = TRUE) / 1000, 1)
}

as_wgs_lines <- function(x){
  if (!inherits(x, "sf") || !nrow(x)) return(NULL)
  x <- sf::st_make_valid(x)
  keep <- sf::st_geometry_type(x) %in% c("LINESTRING","MULTILINESTRING","GEOMETRYCOLLECTION")
  x <- x[keep, , drop = FALSE]
  if (!nrow(x)) return(NULL)
  x <- suppressWarnings(sf::st_collection_extract(x, "LINESTRING", warn = FALSE))
  x <- suppressWarnings(sf::st_cast(x, "LINESTRING"))
  x <- x[!sf::st_is_empty(sf::st_geometry(x)), , drop = FALSE]
  sf::st_transform(x, 4326)
}

get_boundary_wgs <- function(){
  b <- NULL
  if (exists("city_perimeter") && inherits(city_perimeter,"sf") && nrow(city_perimeter)) {
    b <- city_perimeter
  } else if (exists("tracts") && inherits(tracts,"sf") && nrow(tracts)) {
    b <- sf::st_union(tracts) |> sf::st_as_sf()
  } else if (exists("barcelona_tracts") && inherits(barcelona_tracts,"sf") && nrow(barcelona_tracts)) {
    b <- sf::st_union(barcelona_tracts) |> sf::st_as_sf()
  } else {
    return(NULL)
  }
  
  b <- sf::st_make_valid(b)
  b <- sf::st_cast(b, "MULTIPOLYGON", warn = FALSE)
  polys <- sf::st_cast(b, "POLYGON", warn = FALSE)
  rings <- sf::st_sfc(lapply(sf::st_geometry(polys), sf::st_exterior_ring), crs = sf::st_crs(polys))
  bnd  <- sf::st_as_sf(data.frame(id = seq_along(rings)), geometry = rings)
  sf::st_transform(bnd, 4326)
}
