# ================================================================
# utils_ci.R
# Shared helpers for extracting and cleaning cycling infrastructure
# (CI) from OSM sf "lines" using tag-based rules.
#
# Inputs: OSM sf object of LINESTRING/MULTILINESTRING features ("lines") with tag columns
# Outputs: Helper functions (has_cycleway_vals, pick_cycle_infra, drop_onroad_near_cycleway)
# ================================================================

# --- value sets (strong+moderate only)
STRONG_VALS   <- c("track", "opposite_track")
MODERATE_VALS <- c("lane",  "opposite_lane")

# --- cycleway* column detection MUST match getting (^cycleway($|[:_]))
cycleway_cols <- function(x) {
  names(x)[grepl("^cycleway($|[:_])", names(x), ignore.case = TRUE)]
}

has_cycleway_vals <- function(x, vals) {
  cols <- cycleway_cols(x)
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

# --- classification MUST match getting:
# strong_ci if highway=cycleway OR has track/opposite_track
# moderate_ci if not strong, but has lane/opposite_lane
# classify_cycle_cat <- function(x) {
#   stopifnot(inherits(x, "sf"))
#   
#   if (!nrow(x)) {
#     x$cycle_cat <- character(0)
#     return(x)
#   }
#   
#   highway <- .get_chr(x, "highway")
#   is_cycleway_geom <- !is.na(highway) & highway == "cycleway"
#   
#   # OFF-ROAD / PEDESTRIAN INFRA: do NOT treat cycleway=lane/track as on-road CI
#   is_ped_infra <- !is.na(highway) & highway %in% c("footway", "path", "pedestrian")
#   
#   has_strong   <- has_cycleway_vals(x, STRONG_VALS)
#   has_moderate <- has_cycleway_vals(x, MODERATE_VALS)
#   
#   # Key line: ignore cycleway-tags on pedestrian infrastructure
#   has_strong[is_ped_infra]   <- FALSE
#   has_moderate[is_ped_infra] <- FALSE
#   
#   x$cycle_cat <- NA_character_
#   x$cycle_cat[is_cycleway_geom | has_strong] <- "strong_ci"
#   
#   sel <- is.na(x$cycle_cat)
#   x$cycle_cat[sel & has_moderate] <- "moderate_ci"
#   
#   x
# }

classify_cycle_cat <- function(x) {
  stopifnot(inherits(x, "sf"))

  if (!nrow(x)) {
    x$cycle_cat <- character(0)
    return(x)
  }

  highway <- .get_chr(x, "highway")
  is_cycleway_geom <- !is.na(highway) & highway == "cycleway"

  # OFF-ROAD / PEDESTRIAN INFRA: do NOT treat cycleway=lane/track as on-road CI
  is_ped_infra <- !is.na(highway) & highway %in% c("footway", "path", "pedestrian")

  has_strong   <- has_cycleway_vals(x, STRONG_VALS)
  has_moderate <- has_cycleway_vals(x, MODERATE_VALS)

  # Key line: ignore cycleway-tags on pedestrian infrastructure
  has_strong[is_ped_infra]   <- FALSE
  has_moderate[is_ped_infra] <- FALSE

  x$cycle_cat <- NA_character_
  x$cycle_cat[is_cycleway_geom | has_strong] <- "strong_ci"

  sel <- is.na(x$cycle_cat)
  x$cycle_cat[sel & has_moderate] <- "moderate_ci"

  x
}

# --- selector: strong+moderate only
pick_visible_ci <- function(x) {
  stopifnot(inherits(x, "sf"))
  if (!nrow(x)) return(x[0, ])
  
  x <- classify_cycle_cat(x)
  x[!is.na(x$cycle_cat), , drop = FALSE]
}

# --- NDC p1 FLAGGING (copy of getting ndc_pass_flag)
ndc_pass_flag <- function(core_ll,
                          ref_cat = "strong_ci",
                          target_cat = "moderate_ci",
                          tol_m = 15,
                          prop_in_buf = 0.5,
                          min_in_buf_m = 20,
                          crs_metric = get("crs_work", envir = .GlobalEnv),
                          pass_label = "p1") {
  
  stopifnot(inherits(core_ll, "sf"), "cycle_cat" %in% names(core_ll))
  
  if (!"ndc_keep" %in% names(core_ll)) core_ll$ndc_keep <- TRUE
  if (!"ndc_pass" %in% names(core_ll)) core_ll$ndc_pass <- NA_character_
  if (!"ndc_ref_cat" %in% names(core_ll)) core_ll$ndc_ref_cat <- NA_character_
  if (!"ndc_target_cat" %in% names(core_ll)) core_ll$ndc_target_cat <- NA_character_
  
  ref <- core_ll[core_ll$cycle_cat == ref_cat, , drop = FALSE]
  trg <- core_ll[core_ll$cycle_cat == target_cat & core_ll$ndc_keep, , drop = FALSE]
  if (!nrow(ref) || !nrow(trg)) return(core_ll)
  
  ref_m <- sf::st_transform(ref, crs_metric)
  trg_m <- sf::st_transform(trg, crs_metric)
  
  buf <- sf::st_buffer(sf::st_union(sf::st_geometry(ref_m)), tol_m)
  
  trg_m$.rid <- seq_len(nrow(trg_m))
  L <- as.numeric(sf::st_length(sf::st_geometry(trg_m)))
  
  inside <- suppressWarnings(sf::st_intersection(trg_m, buf))
  Lin <- rep(0, nrow(trg_m))
  if (nrow(inside)) {
    Lin_sum <- tapply(as.numeric(sf::st_length(sf::st_geometry(inside))), inside$.rid, sum)
    Lin[as.integer(names(Lin_sum))] <- as.numeric(Lin_sum)
  }
  
  share <- Lin / pmax(L, 1e-6)
  flag  <- (Lin >= min_in_buf_m) & (share >= prop_in_buf)
  
  if (any(flag)) {
    trg_idx_in_core <- which(core_ll$cycle_cat == target_cat & core_ll$ndc_keep)
    flag_idx <- trg_idx_in_core[flag]
    
    core_ll$ndc_keep[flag_idx]       <- FALSE
    core_ll$ndc_pass[flag_idx]       <- pass_label
    core_ll$ndc_ref_cat[flag_idx]    <- ref_cat
    core_ll$ndc_target_cat[flag_idx] <- target_cat
  }
  
  core_ll
}