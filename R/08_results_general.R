# ================================================================
# 08_results_general.R
# Read joined results and produce descriptive summaries / QC tables.
#
# Inputs:  joined_results workbook (from 09, or existing)
# Outputs: summary tables / prints (and optional saved tables/figures)
# ================================================================

# Geometry hygiene (prevents micro-slivers and odd empties)
prep_lines <- function(x, crs){
  x |>
    sf::st_make_valid() |>
    sf::st_zm(drop = TRUE, what = "ZM") |>
    sf::st_transform(crs) |>
    sf::st_set_precision(1e3) |>     # 1 mm precision in a metre CRS
    sf::st_snap_to_grid(1e-3) |>     # snap to that precision grid
    suppressWarnings(sf::st_cast("MULTILINESTRING")) |>
    sf::st_line_merge() |>
    suppressWarnings(sf::st_cast("LINESTRING"))
}

# Optional: gently snap 'a' toward 'b' to reduce pseudo-changes
snap_like <- function(a, b, tol){
  if (!requireNamespace("lwgeom", quietly = TRUE)) return(a)
  lwgeom::st_snap(a, b, tolerance = tol)
}

# 21-added-removed-ensure ------------------------------------------------------

# Ensure 2015/2023 CI networks exist (use your objects if already built)
if (!exists("cyc15_n")) {
  src15 <- if (exists("cyc15")) cyc15 else if (exists("l15")) l15 else stop("Need cyc15 or l15")
  if (exists("pick_cycle_strict")) src15 <- pick_cycle_strict(src15)
  cyc15_n <- to_lines_work(src15, crs_work)
}
if (!exists("cyc23_n")) {
  src23 <- if (exists("cyc23")) cyc23 else if (exists("l23")) l23 else stop("Need cyc23 or l23")
  if (exists("pick_cycle_strict")) src23 <- pick_cycle_strict(src23)
  cyc23_n <- to_lines_work(src23, crs_work)
}

# NOTE: 03_change_detection.R is the authoritative source for 'added' and 'removed'.
# Here we ONLY use them. If missing, we compute local fallbacks for reporting/QC only.

added_use   <- if (exists("added")   && inherits(added, "sf"))   added   else NULL
removed_use <- if (exists("removed") && inherits(removed, "sf")) removed else NULL

if (is.null(added_use)) {
  message("08_results_general: 'added' not found. Recomputing locally for reporting/QC only.")
  cyc15_buf <- sf::st_buffer(sf::st_union(sf::st_geometry(cyc15_n)), tol_m)
  added_use <- sf::st_difference(sf::st_geometry(cyc23_n), cyc15_buf) |>
    sf::st_collection_extract("LINESTRING", warn = FALSE) |>
    sf::st_sf(crs = crs_work)
  added_use <- added_use[!sf::st_is_empty(added_use), , drop = FALSE]
}

if (is.null(removed_use)) {
  message("08_results_general: 'removed' not found. Recomputing locally for reporting/QC only.")
  cyc23_buf <- sf::st_buffer(sf::st_union(sf::st_geometry(cyc23_n)), tol_m)
  removed_use <- sf::st_difference(sf::st_geometry(cyc15_n), cyc23_buf) |>
    sf::st_collection_extract("LINESTRING", warn = FALSE) |>
    sf::st_sf(crs = crs_work)
  removed_use <- removed_use[!sf::st_is_empty(removed_use), , drop = FALSE]
}

# 23-strata-table (full network) ----------------------------------------------

# ---- Pick a tract layer and harmonise CRS (prefer already-prepared layer) ---
tract_layer <- if (exists("tracts_work")) tracts_work else
  if (exists("barcelona_tracts"))  barcelona_tracts else
    if (exists("tracts"))          tracts else
      stop("No tract layer found (tracts_work / barcelona_tracts / tracts).")

tracts_work <- sf::st_transform(tract_layer, sf::st_crs(added_use))

# tract id column (set explicitly if you prefer)
id_col <- dplyr::case_when(
  "tract_id"     %in% names(tracts_work) ~ "tract_id",
  "CUSEC"        %in% names(tracts_work) ~ "CUSEC",
  "codi_seccio"  %in% names(tracts_work) ~ "codi_seccio",
  TRUE ~ names(tracts_work)[1]
)

# ---- Faster length-by-tract using spatial index ------------------------------
length_by_tract <- function(geom, tr, id_col){
  if (!inherits(geom,"sf") || !nrow(geom)) {
    return(tr |> sf::st_drop_geometry() |>
             dplyr::transmute(tract_id = as.character(.data[[!!id_col]]), km = 0) |>
             dplyr::slice(0))
  }
  tr_id <- tr |> dplyr::select(all_of(id_col))
  idx   <- sf::st_intersects(tr_id, geom, sparse = TRUE)
  rows  <- which(lengths(idx) > 0)
  if (!length(rows)) {
    return(tr |> sf::st_drop_geometry() |>
             dplyr::transmute(tract_id = as.character(.data[[!!id_col]]), km = 0) |>
             dplyr::slice(0))
  }
  inter <- suppressWarnings(sf::st_intersection(tr_id[rows, ], geom))
  if (!nrow(inter)) {
    return(tr |> sf::st_drop_geometry() |>
             dplyr::transmute(tract_id = as.character(.data[[!!id_col]]), km = 0) |>
             dplyr::slice(0))
  }
  inter |>
    dplyr::mutate(
      tract_id = as.character(.data[[id_col]]),
      km       = as.numeric(sf::st_length(geometry)) / 1000
    ) |>
    sf::st_drop_geometry() |>
    dplyr::group_by(tract_id) |>
    dplyr::summarise(km = sum(km, na.rm = TRUE), .groups = "drop")
}

add_tr  <- length_by_tract(added_use,   tracts_work, id_col) |> dplyr::mutate(Change = "Added")
rem_tr  <- length_by_tract(removed_use, tracts_work, id_col) |> dplyr::mutate(Change = "Removed")
tr_dist <- dplyr::bind_rows(add_tr, rem_tr)

tr_km <- tr_dist |>
  tidyr::pivot_wider(
    names_from  = Change,
    values_from = km,
    values_fill = list(km = 0),
    values_fn   = list(km = sum)
  ) |>
  dplyr::mutate(
    Added   = dplyr::coalesce(Added,   0),
    Removed = dplyr::coalesce(Removed, 0)
  )

# ---- Build tracts_plot (for strata, full network) ---------------------------
tracts_plot <- tracts_work |>
  dplyr::mutate(tract_id = as.character(.data[[id_col]])) |>
  dplyr::left_join(tr_km, by = "tract_id") |>
  dplyr::mutate(
    Added   = dplyr::coalesce(Added,   0),
    Removed = dplyr::coalesce(Removed, 0)
  )

# ---- Create/fetch 'stratum' -------------------------------------------------
nm   <- names(tracts_plot)
pick <- function(nm_vec, cands){
  hit <- intersect(cands, nm_vec)
  if (length(hit)) hit[1] else NA_character_
}

dens_col <- pick(nm, c("density_class","dens_class","dens_cat","density_cat",
                       "density_q","dens_q","density","dens","dens_stratum"))
cent_col <- pick(nm, c("centrality_class","centr_class","centr_cat","centrality_cat",
                       "centrality_q","centr_q","centrality","centr","cent_stratum"))

if ("stratum" %in% nm) {
  tracts_plot <- tracts_plot |>
    dplyr::mutate(stratum = as.character(stratum))
} else if (!is.na(dens_col) && !is.na(cent_col)) {
  tracts_plot <- tracts_plot |>
    dplyr::mutate(
      density_class    = if (is.numeric(.data[[dens_col]])) dplyr::ntile(.data[[dens_col]], 3) else as.character(.data[[dens_col]]),
      centrality_class = if (is.numeric(.data[[cent_col]])) dplyr::ntile(.data[[cent_col]], 3) else as.character(.data[[cent_col]]),
      stratum = paste0("D", density_class, "_C", centrality_class)
    )
} else {
  tracts_plot <- tracts_plot |>
    dplyr::mutate(stratum = "All")
}

# ---- Summarise by stratum (full network) ------------------------------------
stratum_summary <- tracts_plot |>
  sf::st_drop_geometry() |>
  dplyr::group_by(stratum) |>
  dplyr::summarise(
    Added_km   = sum(Added,   na.rm = TRUE),
    Removed_km = sum(Removed, na.rm = TRUE),
    .groups    = "drop"
  ) |>
  dplyr::arrange(stratum)

# Totals for Table 2 (strata distribution)
tot_added_strata   <- sum(stratum_summary$Added_km,   na.rm = TRUE)
tot_removed_strata <- sum(stratum_summary$Removed_km, na.rm = TRUE)

# Main table by stratum (Table 2)
stratum_out <- stratum_summary |>
  dplyr::mutate(
    Added_pct   = if (tot_added_strata   > 0) 100 * Added_km   / tot_added_strata   else 0,
    Removed_pct = if (tot_removed_strata > 0) 100 * Removed_km / tot_removed_strata else 0
  ) |>
  dplyr::mutate(
    dplyr::across(c(Added_km, Removed_km, Added_pct, Removed_pct), ~ round(.x, 0))
  ) |>
  dplyr::mutate(
    Description = dplyr::case_when(
      stratum == "D1_C1" ~ "Low density, peripheral",
      stratum == "D1_C2" ~ "Low density, intermediate",
      stratum == "D1_C3" ~ "Low density, central",
      stratum == "D2_C1" ~ "Medium density, peripheral",
      stratum == "D2_C2" ~ "Medium density, intermediate",
      stratum == "D2_C3" ~ "Medium density, central",
      stratum == "D3_C1" ~ "High density, peripheral",
      stratum == "D3_C2" ~ "High density, intermediate",
      stratum == "D3_C3" ~ "High density, central",
      TRUE               ~ NA_character_
    )
  ) |>
  dplyr::select(stratum, Description, Added_km, Removed_km, Added_pct, Removed_pct)

stratum_out_full <- dplyr::bind_rows(
  stratum_out,
  tibble::tibble(
    stratum      = "TOTAL",
    Description  = "All strata combined",
    Added_km     = round(tot_added_strata,   1),
    Removed_km   = round(tot_removed_strata, 1),
    Added_pct    = if (tot_added_strata   > 0) 100 else 0,
    Removed_pct  = if (tot_removed_strata > 0) 100 else 0
  )
)

# 22-tab-consistency (network-level check, should be close to zero) -----------

tot_2015 <- len_km(cyc15_n)
tot_2023 <- len_km(cyc23_n)

# Use the change layers directly (not intersection totals)
km_added   <- len_km(added_use)
km_removed <- len_km(removed_use)

consistency <- tibble::tibble(
  Metric   = c(
    "Total 2015",
    "Total 2023",
    "Net growth",
    "Added",
    "Removed",
    "Added − Removed",
    "Gap: (Added − Removed) − Net"
  ),
  `Value (km)` = c(
    round(tot_2015, 1),
    round(tot_2023, 1),
    round(tot_2023 - tot_2015, 1),
    round(km_added, 1),
    round(km_removed, 1),
    round(km_added - km_removed, 1),
    round((km_added - km_removed) - (tot_2023 - tot_2015), 1)
  )
)
