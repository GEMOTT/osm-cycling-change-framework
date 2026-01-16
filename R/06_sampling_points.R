# ================================================================
# 06_sampling_points.R
# Sample lines per tract (ADD/REMOVE/NONCI) and convert to one point per line.
#
# Inputs:  added, removed, general1523_n, sampled_tracts, crs_work
# Outputs: samples_tbl (for Excel export), plus QC summaries
# ================================================================

# Helper

# 5) Core sampler: **fixed cap per tract**
#    - Intersect candidate lines with each tract
#    - Drop tiny fragments
#    - Length-weighted sample up to n_per per tract
sample_lines_by_tract <- function(lines_sf, tracts_sf, n_per, replace = FALSE, min_len = 0){
  if (!inherits(lines_sf,"sf") || !nrow(lines_sf)) {
    out <- lines_sf[0, , drop = FALSE]
    out$tract_id <- character(0); out$stratum <- factor()[0]
    return(out)
  }
  L <- sf::st_transform(lines_sf, sf::st_crs(tracts_sf))
  hits  <- sf::st_intersects(tracts_sf, L)
  picks <- vector("list", nrow(tracts_sf))
  
  for (i in seq_len(nrow(tracts_sf))) {
    idx <- hits[[i]]; if (!length(idx)) next
    cand <- suppressWarnings(sf::st_intersection(L[idx, , drop = FALSE], tracts_sf[i, ]))
    cand <- suppressWarnings(sf::st_collection_extract(cand, "LINESTRING", warn = FALSE))
    cand <- cand[!sf::st_is_empty(cand), , drop = FALSE]
    if (min_len > 0)
      cand <- cand[as.numeric(sf::st_length(cand)) >= min_len, , drop = FALSE]
    if (!nrow(cand)) next
    
    # Up to n_per per **this** tract
    draw_with_replacement <- isTRUE(replace) && nrow(cand) < n_per
    k <- if (draw_with_replacement) n_per else min(n_per, nrow(cand))
    lens <- as.numeric(sf::st_length(cand)); lens[!is.finite(lens)] <- 0
    prob <- if (sum(lens) > 0) lens / sum(lens) else NULL
    
    piece <- cand[sample(seq_len(nrow(cand)), k, replace = draw_with_replacement, prob = prob), , drop = FALSE]
    piece$tract_id <- tracts_sf$tract_id[i]
    piece$stratum  <- tracts_sf$stratum[i]
    picks[[i]] <- piece
  }
  dplyr::bind_rows(picks)
}


set.seed(1234)

# --- basic checks (CI_STABLE stuff removed) ----------------------------------
stopifnot(exists("added_eval"), exists("removed_eval"), exists("crs_work"))
stopifnot(exists("sampled_tracts"))
stopifnot(exists("general1523_n"), inherits(general1523_n, "sf"), nrow(general1523_n) > 0)

# ensure 'tract_id'
normalize_tract_id <- function(s){
  nm  <- names(s); nml <- tolower(nm)
  candidates <- c("tract_id","tractid","geoid","geoid10","geoid20","id","code","name","objectid","fid")
  hit <- which(nml %in% candidates)
  if (length(hit) > 0) s$tract_id <- as.character(s[[ nm[hit[1]] ]]) else s$tract_id <- sprintf("tract_%04d", seq_len(nrow(s)))
  s
}
sampled_tracts <- normalize_tract_id(sampled_tracts)
stopifnot("tract_id" %in% names(sampled_tracts))

PERTRACT_ADD    <- 2
PERTRACT_REM    <- 2
PERTRACT_NONCI  <- 1
FORCE_QUOTA     <- FALSE
MIN_LEN_M       <- 15

# CRS + strata
tracts <- sf::st_transform(sampled_tracts, crs_work)
if (!"stratum" %in% names(tracts)) {
  tracts$stratum <- factor("all")
} else {
  tracts$stratum <- droplevels(as.factor(tracts$stratum))
}

# GENERAL pool (NONCI lines created upstream)
noncycle23 <- sf::st_transform(general1523_n, crs_work)

# --- picks: strictly per-tract caps; no top-ups ------------------------------
added_by_tr   <- sample_lines_by_tract(added_eval,      tracts, PERTRACT_ADD,   replace = FORCE_QUOTA, min_len = MIN_LEN_M)
removed_by_tr <- sample_lines_by_tract(removed_eval,    tracts, PERTRACT_REM,   replace = FORCE_QUOTA, min_len = MIN_LEN_M)
general_by_tr <- sample_lines_by_tract(noncycle23, tracts, PERTRACT_NONCI, replace = FORCE_QUOTA, min_len = MIN_LEN_M)

# convert to points (1 per line)
added_pts   <- points_on_lines(added_by_tr)   |> dplyr::mutate(class = "ADD")
removed_pts <- points_on_lines(removed_by_tr) |> dplyr::mutate(class = "REMOVE")
nonci_pts   <- points_on_lines(general_by_tr) |> dplyr::mutate(class = "NONCI")

# keep only points within tract boundaries
keep_in <- function(pts, tracts, eps = 0.5){
  if (!inherits(pts,"sf") || !nrow(pts)) return(pts)
  if (sf::st_crs(pts) != sf::st_crs(tracts)) pts <- sf::st_transform(pts, sf::st_crs(tracts))
  M <- sf::st_is_within_distance(pts, tracts, dist = eps, sparse = FALSE)
  pts[apply(M, 1, any), , drop = FALSE]
}
added_pts   <- keep_in(added_pts,   tracts)
removed_pts <- keep_in(removed_pts, tracts)
nonci_pts   <- keep_in(nonci_pts,   tracts)

# sanity: one point per selected line
stopifnot(
  nrow(added_pts)   == nrow(added_by_tr),
  nrow(removed_pts) == nrow(removed_by_tr),
  nrow(nonci_pts)   == nrow(general_by_tr)
)

# tables for export
add_tbl <- to_lonlat_tbl(added_pts)   |> dplyr::mutate(interval="2015→2023", source="ADD_FLAG",    class="ADD")    |> add_validation_cols() |> coerce_for_bind()
rem_tbl <- to_lonlat_tbl(removed_pts) |> dplyr::mutate(interval="2015→2023", source="REMOVE_FLAG", class="REMOVE") |> add_validation_cols() |> coerce_for_bind()
gen_tbl <- to_lonlat_tbl(nonci_pts)   |> dplyr::mutate(interval="2015→2023", source="NONCI_2023",  class="NONCI")  |> add_validation_cols() |> coerce_for_bind()

# final stack
samples_tbl <- dplyr::bind_rows(add_tbl, rem_tbl, gen_tbl)

# give annotators a non-NA option for interiors/photos
if (!"imagery_class" %in% names(samples_tbl)) {
  samples_tbl$imagery_class <- factor("PENDING",
                                      levels = c("STREET","NONSTREET","PENDING"))
}
# ---------------------------------------------------------------------------


# quick counts
cat("\nCounts (lines → points):\n")
print(rbind(
  ADD     = c(lines = nrow(added_by_tr),   pts = nrow(added_pts)),
  REMOVE  = c(lines = nrow(removed_by_tr), pts = nrow(removed_pts)),
  NONCI   = c(lines = nrow(general_by_tr), pts = nrow(nonci_pts))
))

# --- Stratum sanity ----------------------------------------------------------
attach_stratum_to_pts <- function(pts, tracts){
  if (!inherits(pts,"sf") || !nrow(pts)) return(pts)
  p <- pts
  if (sf::st_crs(p) != sf::st_crs(tracts)) p <- sf::st_transform(p, sf::st_crs(tracts))
  sf::st_join(p, tracts[, c("tract_id","stratum")], left = TRUE, join = sf::st_within)
}

nonci_pts_s <- attach_stratum_to_pts(nonci_pts, tracts)
add_pts_s   <- attach_stratum_to_pts(added_pts,  tracts)
rem_pts_s   <- attach_stratum_to_pts(removed_pts, tracts)

by_stratum <- data.frame(
  STRATUM = levels(tracts$stratum),
  NONCI   = as.integer(table(factor(nonci_pts_s$stratum, levels(tracts$stratum)))),
  ADD     = as.integer(table(factor(add_pts_s$stratum,   levels(tracts$stratum)))),
  REMOVE  = as.integer(table(factor(rem_pts_s$stratum,  levels(tracts$stratum))))
)

cat("\nBy-stratum counts (POINTS):\n")
print(by_stratum)

# feasibility_diagnostic call (use the actual NONCI pool sampled from)
# feas <- feasibility_diagnostic(
#   sampled_tracts  = sampled_tracts,
#   added           = added,
#   removed         = removed,
#   nonci_lines     = noncycle23,
#   crs_work        = crs_work
# )
# 
# print(feas, n = Inf, width = Inf)

