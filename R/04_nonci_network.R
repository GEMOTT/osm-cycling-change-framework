# ================================================================
# 04_nonci_network.R
# Build a NONCI pool by taking baseline road classes (from 2023 lines)
# and excluding/cutting anything within tol_m of CI in either 2015 or 2023.
#
# Inputs:
#   l23                               # OSM lines (follow-up snapshot), with highway tag
#   cyc15_n, cyc23_n                  # cleaned CI networks
#   tol_m, min_len
#   crs_work, crs_wgs
#   proc_dir, city_tag, ver15, ver23
#   normalize_lines_safe()
#
# Outputs (cached RDS in proc_dir):
#   {city_tag}_{ver15}_{ver23}_nonci_work_tol{tol_m}m_min{min_len}m.rds
#   {city_tag}_{ver15}_{ver23}_general_nonci_tol{tol_m}m_min{min_len}m.rds
#   (optionally reuses or writes CI buffers:)
#   {city_tag}_{ver15}_buf_tol{tol_m}m.rds
#   {city_tag}_{ver23}_buf_tol{tol_m}m.rds
#
# Objects (in memory):
#   nonci1523, general1523_n, buf15, buf23, buf_any
# ================================================================


reuse_cached <- TRUE  # set FALSE to force rebuild

# ---- cache paths ------------------------------------------------------------
rds_nonci_1523  <- file.path(proc_dir, sprintf("%s_%s_%s_nonci_work_tol%sm_min%sm.rds",
                                               city_tag, ver15, ver23, tol_m, min_len))
rds_nonciW_1523 <- file.path(proc_dir, sprintf("%s_%s_%s_general_nonci_tol%sm_min%sm.rds",
                                               city_tag, ver15, ver23, tol_m, min_len))

# optional: reuse per-year CI buffers if present
rds_buf23 <- file.path(proc_dir, sprintf("%s_%s_buf_tol%sm.rds", city_tag, ver23, tol_m))
rds_buf15 <- file.path(proc_dir, sprintf("%s_%s_buf_tol%sm.rds", city_tag, ver15, tol_m))

# ---- FAST PATH --------------------------------------------------------------
if (reuse_cached && file.exists(rds_nonci_1523) && file.exists(rds_nonciW_1523)) {
  nonci1523     <- readRDS(rds_nonci_1523)
  general1523_n <- readRDS(rds_nonciW_1523)
  message(
    "Non-CI 2015&2023 (loaded) — rows: ", nrow(nonci1523),
    " | km: ", round(sum(as.numeric(st_length(nonci1523)))/1000, 1)
  )
} else {
  
  # ---- 1) Base roads (same filter you used) ---------------------------------
  base_roads <- c(
    "primary","secondary","tertiary","unclassified",
    "residential","primary_link","secondary_link",
    "tertiary_link","living_street","pedestrian"
  )
  
  # Build the base from 2023 snapshot in work CRS
  base23 <- l23 |>
    sf::st_transform(crs_work) |>
    sf::st_make_valid() |>
    dplyr::filter(.data$highway %in% base_roads) |>
    normalize_lines_safe()
  
  if (!inherits(base23, "sf") || nrow(base23) == 0) {
    stop(sprintf(
      "04_nonci_network: base23 is empty or not sf after filtering. Check base_roads vs l23$highway and snapshot/input. n=%s",
      if (inherits(base23, "sf")) nrow(base23) else "NA"
    ))
  }
  
  
  # ---- 2) Build or load CI buffers for each year ----------------------------
  # 2023 buffer
  if (file.exists(rds_buf23)) {
    buf23 <- readRDS(rds_buf23)
    if (sf::st_crs(buf23) != sf::st_crs(base23)) buf23 <- sf::st_transform(buf23, sf::st_crs(base23))
  } else {
    ci23_geom <- sf::st_transform(cyc23_n, sf::st_crs(base23)) |> sf::st_geometry()
    buf23 <- sf::st_buffer(sf::st_union(ci23_geom), tol_m) |> sf::st_make_valid()
    
    try(saveRDS(buf23, rds_buf23), silent = TRUE)
  }
  
  # 2015 buffer
  if (file.exists(rds_buf15)) {
    buf15 <- readRDS(rds_buf15)
    if (sf::st_crs(buf15) != sf::st_crs(base23)) buf15 <- sf::st_transform(buf15, sf::st_crs(base23))
  } else {
    ci15_geom <- sf::st_transform(cyc15_n, sf::st_crs(base23)) |> sf::st_geometry()
    buf15 <- sf::st_buffer(sf::st_union(ci15_geom), tol_m) |> sf::st_make_valid()
    try(saveRDS(buf15, rds_buf15), silent = TRUE)
  }
  
  # Union of both buffers = any CI in 2015 or 2023
  buf_any <- sf::st_union(sf::st_make_valid(buf15), sf::st_make_valid(buf23))
  
  # ---- 3) Remove streets that overlap ANY CI in 2015 or 2023 ----------------
  touch_any <- lengths(sf::st_intersects(base23, buf_any, sparse = TRUE)) > 0
  keep_any  <- base23[!touch_any, , drop = FALSE]  # fully outside both buffers
  cut_any   <- if (any(touch_any)) sf::st_difference(base23[touch_any, , drop = FALSE], buf_any) else base23[0,]
  
  cut_any <- normalize_lines_safe(cut_any)
  
  # Combine and drop tiny fragments if requested
  nonci1523 <- dplyr::bind_rows(keep_any, cut_any)
  if (nrow(nonci1523) && min_len > 0) {
    nonci1523 <- nonci1523[as.numeric(sf::st_length(nonci1523)) >= min_len, , drop = FALSE]
  }
  
  # ---- 4) WGS84 for mapping -------------------------------------------------
  general1523_n <- nonci1523 |>
    sf::st_transform(crs_wgs) |>
    sf::st_make_valid() |>
    sf::st_simplify(dTolerance = 2)
  
  # ---- 5) Save caches -------------------------------------------------------
  try(saveRDS(nonci1523,     rds_nonci_1523),  silent = TRUE)
  try(saveRDS(general1523_n, rds_nonciW_1523), silent = TRUE)
  
  # ---- 6) Log ---------------------------------------------------------------
  message(
    "Non-CI 2015&2023 built — rows: ", nrow(nonci1523),
    " | km: ", round(sum(as.numeric(sf::st_length(nonci1523)))/1000, 1)
  )
}