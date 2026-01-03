# ================================================================
# utils_ci.R
# Shared helpers for extracting and cleaning cycling infrastructure
# (CI) from OSM sf "lines" using tag-based rules.
#
# Inputs: OSM sf object of LINESTRING/MULTILINESTRING features ("lines") with tag columns
# Outputs: Helper functions (has_cycleway_vals, pick_cycle_infra, drop_onroad_near_cycleway)
# ================================================================

# Define which cycleway tag values count as “core” ci in this workflow.
CORE_VALS <- c("lane", "track", "opposite_lane", "opposite_track")

# For each feature, check whether any cycleway* tag column contains one of the target values (allowing multiple values separated by ";").
has_cycleway_vals <- function(x, vals = CORE_VALS) {
  cols <- names(x)[grepl("^cycleway($|:)", names(x), ignore.case = TRUE)]
  if (!length(cols)) return(rep(FALSE, nrow(x)))
  
  vals <- tolower(vals)
  out  <- rep(FALSE, nrow(x))
  
  for (cc in cols) {
    v <- tolower(trimws(as.character(x[[cc]])))
    v[is.na(v)] <- ""
    hit <- vapply(
      strsplit(v, ";", fixed = TRUE),
      function(parts) any(trimws(parts) %in% vals),
      logical(1)
    )
    out <- out | hit
  }
  out
}

# Select a conservative cycling-infrastructure subset: either explicit highway=cycleway, or anything with a qualifying cycleway* value (e.g., lane/track).
pick_cycle_infra <- function(x) {
  stopifnot(inherits(x, "sf"))
  if (!nrow(x)) return(x[0, ])
  
  highway    <- .get_chr(x, "highway")
  is_cyclewy <- !is.na(highway) & highway == "cycleway"
  has_lane   <- has_cycleway_vals(x, CORE_VALS)
  
  x[is_cyclewy | has_lane, , drop = FALSE]
}

# Reduce double-counting by dropping on-road lane segments when they largely overlap a mapped cycleway within a buffer (keeps true standalone on-road lanes).
drop_onroad_near_cycleway <- function(core_ll, tol_m = 15, prop_in_buf = 0.5, min_in_buf_m = 20) {
  stopifnot(inherits(core_ll, "sf"))
  if (!nrow(core_ll)) return(core_ll)
  
  highway    <- .get_chr(core_ll, "highway")
  is_cyclewy <- !is.na(highway) & highway == "cycleway"
  has_lane   <- has_cycleway_vals(core_ll, CORE_VALS)
  
  cyc <- core_ll[is_cyclewy, , drop = FALSE]
  onr <- core_ll[(!is_cyclewy) & has_lane, , drop = FALSE]
  
  if (!nrow(cyc) || !nrow(onr)) return(core_ll[is_cyclewy | has_lane, , drop = FALSE])
  
  cyc_m <- sf::st_transform(cyc, 3857)
  onr_m <- sf::st_transform(onr, 3857)
  
  buf <- sf::st_buffer(sf::st_union(sf::st_geometry(cyc_m)), tol_m)
  
  onr_m$.rid <- seq_len(nrow(onr_m))
  L <- as.numeric(sf::st_length(sf::st_geometry(onr_m)))
  
  inside <- suppressWarnings(sf::st_intersection(onr_m, buf))
  Lin <- rep(0, nrow(onr_m))
  if (nrow(inside)) {
    Lin_sum <- tapply(as.numeric(sf::st_length(sf::st_geometry(inside))), inside$.rid, sum)
    Lin[as.integer(names(Lin_sum))] <- as.numeric(Lin_sum)
  }
  
  share <- Lin / pmax(L, 1e-6)
  drop  <- (Lin >= min_in_buf_m) & (share >= prop_in_buf)
  
  rbind(cyc, onr[!drop, , drop = FALSE])
}
