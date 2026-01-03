# ================================================================
# 03_change_detection.R
# Detect CI changes between snapshots (ADD and REMOVE) using a tolerance buffer
# and a minimum segment length filter; flag likely realignments (ADD near REMOVE).
#
# Inputs:
#   cyc15_n, cyc23_n, tol_m, min_len
#   city_tag, ver15, ver23, proc_dir
#   rds_cyc15, rds_cyc23, .cache(), len_ok(), crs_work
#
# Outputs (cached RDS in proc_dir):
#   {city_tag}_{ver15}_buf_tol{tol_m}m_epsgXXXX.rds
#   {city_tag}_{ver23}_buf_tol{tol_m}m_epsgXXXX.rds
#   {city_tag}_added_tol{tol_m}m_min{min_len}m_epsgXXXX.rds
#   {city_tag}_removed_tol{tol_m}m_min{min_len}m_epsgXXXX.rds
#
# Outputs (in memory only):
#   added_raw, removed_raw
#   added_eval, removed_eval
# ================================================================

# -----------------------------
# Cache paths (cache-bust by CRS)
# -----------------------------
epsg_work <- sf::st_crs(crs_work)$epsg
if (is.na(epsg_work)) epsg_work <- "NA"

rds_buf15 <- file.path(proc_dir, sprintf("%s_%s_buf_tol%sm_epsg%s.rds", city_tag, ver15, tol_m, epsg_work))
rds_buf23 <- file.path(proc_dir, sprintf("%s_%s_buf_tol%sm_epsg%s.rds", city_tag, ver23, tol_m, epsg_work))

rds_added  <- file.path(proc_dir, sprintf("%s_added_tol%sm_min%sm_epsg%s.rds",   city_tag, tol_m, min_len, epsg_work))
rds_removed<- file.path(proc_dir, sprintf("%s_removed_tol%sm_min%sm_epsg%s.rds", city_tag, tol_m, min_len, epsg_work))

# -----------------------------
# Work in metric CRS for ALL buffering/differencing
# -----------------------------
cyc15_m <- sf::st_transform(cyc15_n, crs_work)
cyc23_m <- sf::st_transform(cyc23_n, crs_work)

# -----------------------------
# Build (or load) tolerance buffers (metric) and FORCE CRS
# -----------------------------
buf15 <- .cache(
  rds_buf15,
  build = function() {
    g15 <- sf::st_union(sf::st_geometry(cyc15_m))
    b15 <- sf::st_buffer(g15, tol_m)
    sf::st_set_crs(b15, sf::st_crs(crs_work))
  },
  inputs = rds_cyc15
)

buf23 <- .cache(
  rds_buf23,
  build = function() {
    g23 <- sf::st_union(sf::st_geometry(cyc23_m))
    b23 <- sf::st_buffer(g23, tol_m)
    sf::st_set_crs(b23, sf::st_crs(crs_work))
  },
  inputs = rds_cyc23
)

# Guard against legacy cached buffers with wrong CRS
if (sf::st_crs(buf15) != sf::st_crs(crs_work)) buf15 <- sf::st_transform(buf15, crs_work)
if (sf::st_crs(buf23) != sf::st_crs(crs_work)) buf23 <- sf::st_transform(buf23, crs_work)

# -----------------------------
# Helper: turn st_difference geometry into an sf of LINESTRINGs (metric)
# -----------------------------
process_difference <- function(diff_geom, crs) {
  if (length(diff_geom) == 0) return(sf::st_sf(geometry = sf::st_sfc(crs = crs)))
  
  g <- suppressWarnings(sf::st_collection_extract(diff_geom, "LINESTRING"))
  g <- suppressWarnings(sf::st_cast(g, "LINESTRING"))
  
  out <- sf::st_sf(geometry = g, crs = crs)
  out[as.numeric(sf::st_length(out)) > 0, , drop = FALSE]
}

# -----------------------------
# Compute changes (metric)
# -----------------------------
added <- .cache(
  rds_added,
  build = function() {
    x23  <- sf::st_union(sf::st_geometry(cyc23_m))
    diff <- sf::st_difference(x23, buf15)
    process_difference(diff, sf::st_crs(cyc23_m)) |>
      len_ok(min_len)
  },
  inputs = c(rds_cyc23, rds_buf15)
)

removed <- .cache(
  rds_removed,
  build = function() {
    x15  <- sf::st_union(sf::st_geometry(cyc15_m))
    diff <- sf::st_difference(x15, buf23)
    process_difference(diff, sf::st_crs(cyc15_m)) |>
      len_ok(min_len)
  },
  inputs = c(rds_cyc15, rds_buf23)
)

# -----------------------------
# Summary
# -----------------------------
message(
  "CI nets — 2015 segs: ", nrow(cyc15_n),
  " | 2023 segs: ", nrow(cyc23_n),
  " | Added segs: ", nrow(added),
  " | Removed segs: ", nrow(removed)
)

# -----------------------------
# REALIGN tagging (metric)
# -----------------------------
tag_realign_between_add_rem <- function(a, b, d = 15) {
  a_m <- sf::st_transform(a, crs_work)
  b_m <- sf::st_transform(b, crs_work)
  lengths(sf::st_is_within_distance(a_m, b_m, dist = d)) > 0
}

removed$REALIGN <- tag_realign_between_add_rem(removed, added, d = 15)
added$REALIGN   <- tag_realign_between_add_rem(added,   removed, d = 15)

# Keep raw layers (canonical outputs of differencing)
added_raw   <- added
removed_raw <- removed

# Evaluation pool (drop realignments etc.)
added_eval   <- subset(added_raw,   !REALIGN)
removed_eval <- subset(removed_raw, !REALIGN)
