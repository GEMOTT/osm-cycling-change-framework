# ================================================================
# 03b_change_detection_sensitivity.R
# Sensitivity checks for geometric change-detection parameters.
#
# Run after:
#   00_setup.R
#   utils_core.R
#   01_osm_download.R
#   utils_ci.R
#   02_ci_networks.R
#
# Outputs:
#   outputs/sensitivity/change_detection_sensitivity.xlsx
#   outputs/sensitivity/change_detection_sensitivity.csv
# ================================================================

sens_dir <- file.path(outdir, "sensitivity")
dir.create(sens_dir, recursive = TRUE, showWarnings = FALSE)

epsg_work <- sf::st_crs(crs_work)$epsg
if (is.na(epsg_work)) epsg_work <- "NA"

cyc15_m <- sf::st_transform(cyc15_n, crs_work)
cyc23_m <- sf::st_transform(cyc23_n, crs_work)

process_difference_sens <- function(diff_geom, crs) {
  if (length(diff_geom) == 0) return(sf::st_sf(geometry = sf::st_sfc(crs = crs)))
  g <- suppressWarnings(sf::st_collection_extract(diff_geom, "LINESTRING"))
  g <- suppressWarnings(sf::st_cast(g, "LINESTRING"))
  out <- sf::st_sf(geometry = g, crs = crs)
  out[as.numeric(sf::st_length(out)) > 0, , drop = FALSE]
}

tag_realign_sens <- function(a, b, d) {
  if (!nrow(a) || !nrow(b)) return(rep(FALSE, nrow(a)))
  lengths(sf::st_is_within_distance(a, b, dist = d)) > 0
}

run_change_sens <- function(diff_tol_m = 10, min_seg_m = 10, realign_m = 15) {
  
  buf15 <- sf::st_union(sf::st_geometry(cyc15_m)) |>
    sf::st_buffer(diff_tol_m) |>
    sf::st_make_valid()
  
  buf23 <- sf::st_union(sf::st_geometry(cyc23_m)) |>
    sf::st_buffer(diff_tol_m) |>
    sf::st_make_valid()
  
  added <- sf::st_difference(sf::st_union(sf::st_geometry(cyc23_m)), buf15) |>
    process_difference_sens(sf::st_crs(cyc23_m)) |>
    len_ok(min_seg_m)
  
  removed <- sf::st_difference(sf::st_union(sf::st_geometry(cyc15_m)), buf23) |>
    process_difference_sens(sf::st_crs(cyc15_m)) |>
    len_ok(min_seg_m)
  
  added$REALIGN <- tag_realign_sens(added, removed, realign_m)
  removed$REALIGN <- tag_realign_sens(removed, added, realign_m)
  
  added_eval <- added[!added$REALIGN, , drop = FALSE]
  removed_eval <- removed[!removed$REALIGN, , drop = FALSE]
  
  tibble::tibble(
    diff_tol_m = diff_tol_m,
    min_seg_m = min_seg_m,
    realign_m = realign_m,
    added_raw_n = nrow(added),
    removed_raw_n = nrow(removed),
    added_eval_n = nrow(added_eval),
    removed_eval_n = nrow(removed_eval),
    added_realign_n = sum(added$REALIGN),
    removed_realign_n = sum(removed$REALIGN),
    added_eval_km = sum(as.numeric(sf::st_length(added_eval))) / 1000,
    removed_eval_km = sum(as.numeric(sf::st_length(removed_eval))) / 1000,
    net_eval_km = added_eval_km - removed_eval_km
  )
}

# Baseline + one-at-a-time sensitivity checks
sens_grid <- tibble::tribble(
  ~scenario,              ~diff_tol_m, ~min_seg_m, ~realign_m,
  "baseline",             10,          10,         15,
  "diff_buffer_5m",        5,          10,         15,
  "diff_buffer_15m",      15,          10,         15,
  "min_segment_5m",       10,           5,         15,
  "min_segment_20m",      10,          20,         15,
  "realign_10m",          10,          10,         10,
  "realign_20m",          10,          10,         20
)

sens_results <- purrr::pmap_dfr(
  sens_grid,
  \(scenario, diff_tol_m, min_seg_m, realign_m) {
    message("Running sensitivity: ", scenario)
    run_change_sens(diff_tol_m, min_seg_m, realign_m) |>
      dplyr::mutate(scenario = scenario, .before = 1)
  }
)

baseline <- sens_results |>
  dplyr::filter(scenario == "baseline") |>
  dplyr::slice(1)

sens_results <- sens_results |>
  dplyr::mutate(
    added_eval_km = round(added_eval_km, 1),
    removed_eval_km = round(removed_eval_km, 1),
    net_eval_km = round(net_eval_km, 1),
    delta_added_km = round(added_eval_km - baseline$added_eval_km, 1),
    delta_removed_km = round(removed_eval_km - baseline$removed_eval_km, 1),
    delta_net_km = round(net_eval_km - baseline$net_eval_km, 1)
  )

readr::write_csv(
  sens_results,
  file.path(sens_dir, "change_detection_sensitivity.csv")
)

openxlsx::write.xlsx(
  sens_results,
  file.path(sens_dir, "change_detection_sensitivity.xlsx"),
  overwrite = TRUE
)

# Clean table for Supplement S5
# Clean table for Supplement S5
sens_table_s5 <- sens_results |>
  dplyr::mutate(
    Scenario = dplyr::case_when(
      scenario == "baseline" ~ "Baseline (10 m buffer, 10 m minimum segment, 15 m realignment)",
      scenario == "diff_buffer_5m" ~ "Buffer = 5 m",
      scenario == "diff_buffer_15m" ~ "Buffer = 15 m",
      scenario == "min_segment_5m" ~ "Minimum segment = 5 m",
      scenario == "min_segment_20m" ~ "Minimum segment = 20 m",
      scenario == "realign_10m" ~ "Realignment = 10 m",
      scenario == "realign_20m" ~ "Realignment = 20 m",
      TRUE ~ scenario
    )
  ) |>
  dplyr::select(
    Scenario,
    added_eval_km,
    removed_eval_km,
    net_eval_km,
    delta_added_km,
    delta_removed_km,
    delta_net_km,
    added_eval_n,
    removed_eval_n
  ) |>
  dplyr::rename(
    `Added (km)` = added_eval_km,
    `Removed (km)` = removed_eval_km,
    `Net change (km)` = net_eval_km,
    `Δ added (km)` = delta_added_km,
    `Δ removed (km)` = delta_removed_km,
    `Δ net change (km)` = delta_net_km,
    `Added segments (n)` = added_eval_n,
    `Removed segments (n)` = removed_eval_n
  )

supp_dir <- here::here("supplements")
dir.create(supp_dir, recursive = TRUE, showWarnings = FALSE)

openxlsx::write.xlsx(
  sens_table_s5,
  file.path(supp_dir, "S5_change_detection_sensitivity.xlsx"),
  overwrite = TRUE
)

sens_table_s5

# RAW totals (should match Table 1)
# raw_added_km <- sum(as.numeric(sf::st_length(added))) / 1000
# raw_removed_km <- sum(as.numeric(sf::st_length(removed))) / 1000
# raw_net_km <- raw_added_km - raw_removed_km
# 
# tibble::tibble(
#   check = "raw_consistency",
#   added_km = round(raw_added_km, 1),
#   removed_km = round(raw_removed_km, 1),
#   net_km = round(raw_net_km, 1)
# )
