# =========================
# VALIDATION: 02_ci_networks.R
# Replace build blocks so they call the getting-equivalent functions
# (strong+moderate only + NDC flagging then exclude flagged)
# =========================

# Local defaults (no setup changes required)
ENABLE_NDC       <- TRUE
NDC_TOL_M        <- 15
NDC_PROP_IN_BUF  <- 0.5
NDC_MIN_IN_BUF_M <- 20

# Reads the raw OSM lines (outputs from Script 01)
l15 <- sf::st_read(gpkg15, layer = lyr15, quiet = TRUE)
l23 <- sf::st_read(gpkg23, layer = lyr23, quiet = TRUE)

rds_cyc15 <- file.path(proc_dir, sprintf("%s_%s_cyc_n.rds", city_tag, ver15))
rds_cyc23 <- file.path(proc_dir, sprintf("%s_%s_cyc_n.rds", city_tag, ver23))

build_one <- function(lines_sf) {
  
  # 1) normalise in crs_work (same idea/order as getting)
  lines_m <- lines_sf |>
    sf::st_transform(crs_work) |>
    normalize_lines_safe()
  
  # 2) select strong+moderate only, and add cycle_cat
  core_m <- pick_visible_ci(lines_m)
  
  # 3) NDC p1 flagging in WGS, using crs_work for metric ops (same as getting)
  core_ll <- sf::st_transform(core_m, crs_wgs)
  
  if (isTRUE(ENABLE_NDC)) {
    core_ll$ndc_keep       <- TRUE
    core_ll$ndc_pass       <- NA_character_
    core_ll$ndc_ref_cat    <- NA_character_
    core_ll$ndc_target_cat <- NA_character_
    
    core_ll <- ndc_pass_flag(
      core_ll,
      ref_cat      = "strong_ci",
      target_cat   = "moderate_ci",
      tol_m        = NDC_TOL_M,
      prop_in_buf  = NDC_PROP_IN_BUF,
      min_in_buf_m = NDC_MIN_IN_BUF_M,
      crs_metric   = crs_work,
      pass_label   = "p1"
    )
  } else {
    core_ll$ndc_keep       <- NA
    core_ll$ndc_pass       <- NA_character_
    core_ll$ndc_ref_cat    <- NA_character_
    core_ll$ndc_target_cat <- NA_character_
  }
  
  # 4) EXCLUDE flagged (match getting EXCL_NDC)
  excl_ndc <- core_ll[is.na(core_ll$ndc_keep) | core_ll$ndc_keep, , drop = FALSE]
  
  # 5) back to metric CRS for the rest of validation
  sf::st_transform(excl_ndc, crs_work)
}

cyc23_n <- .cache(rds_cyc23, build = function() build_one(l23), inputs = gpkg23)
cyc15_n <- .cache(rds_cyc15, build = function() build_one(l15), inputs = gpkg15)
