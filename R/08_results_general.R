# 20-results-setup

# Geometry hygiene (prevents micro-slivers & odd empties)
prep_lines <- function(x, crs){
  x |>
    sf::st_make_valid() |>
    sf::st_zm(drop = TRUE, what = "ZM") |>
    sf::st_transform(crs) |>
    sf::st_set_precision(1e3) |>     # 1 mm precision in a meter CRS
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

# 21-added-removed-ensure

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

# Recompute only if missing
if (!exists("added") || !inherits(added,"sf")) {
  cyc15_buf <- sf::st_buffer(sf::st_geometry(cyc15_n), tol_m) |> sf::st_union()
  added <- sf::st_difference(sf::st_geometry(cyc23_n), cyc15_buf) |>
    sf::st_collection_extract("LINESTRING", warn = FALSE) |>
    sf::st_sf(crs = crs_work)
  added <- added[!sf::st_is_empty(added), , drop = FALSE]
}
if (!exists("removed") || !inherits(removed,"sf")) {
  cyc23_buf <- sf::st_buffer(sf::st_geometry(cyc23_n), tol_m) |> sf::st_union()
  removed <- sf::st_difference(sf::st_geometry(cyc15_n), cyc23_buf) |>
    sf::st_collection_extract("LINESTRING", warn = FALSE) |>
    sf::st_sf(crs = crs_work)
  removed <- removed[!sf::st_is_empty(removed), , drop = FALSE]
}

# 22-tab-consistency

# assumes chunks 01 (len_km helper) and 02 (added/removed + cyc15_n/cyc23_n) ran
tot_2015   <- len_km(cyc15_n)
tot_2023   <- len_km(cyc23_n)
km_added   <- len_km(added)
km_removed <- len_km(removed)

consistency <- tibble::tibble(
  Metric = c("Total 2015 (km)", "Total 2023 (km)", "Net growth (km)",
             "Added (km)", "Removed (km)", "Added − Removed (km)",
             "Gap: (Added−Removed) − Net"),
  Value  = c(round(tot_2015,1), round(tot_2023,1), round(tot_2023 - tot_2015,1),
             round(km_added,1), round(km_removed,1), round(km_added - km_removed,1),
             round((km_added - km_removed) - (tot_2023 - tot_2015), 1))
)

# 23-strata-table

# ---- Ensure change layers exist (build if needed) ----------------------------
if (!exists("added") || !inherits(added, "sf") || !exists("removed") || !inherits(removed, "sf")) {
  stopifnot(exists("cyc15_n"), exists("cyc23_n"), exists("tol_m"))
  crs_work <- sf::st_crs(cyc23_n)
  cyc15_buf <- sf::st_buffer(sf::st_union(sf::st_geometry(cyc15_n)), tol_m)
  cyc23_buf <- sf::st_buffer(sf::st_union(sf::st_geometry(cyc23_n)), tol_m)
  added <- sf::st_difference(sf::st_geometry(cyc23_n), cyc15_buf) |>
    sf::st_collection_extract("LINESTRING", warn = FALSE) |>
    sf::st_sf(crs = crs_work)
  removed <- sf::st_difference(sf::st_geometry(cyc15_n), cyc23_buf) |>
    sf::st_collection_extract("LINESTRING", warn = FALSE) |>
    sf::st_sf(crs = crs_work)
  added   <- added[!sf::st_is_empty(added), , drop = FALSE]
  removed <- removed[!sf::st_is_empty(removed), , drop = FALSE]
}

# ---- Pick a tract layer & harmonise CRS -------------------------------------
tract_layer <- if (exists("tracts_work")) tracts_work else
  if (exists("tracts"))      tracts else
    if (exists("barcelona_tracts")) barcelona_tracts else
      stop("No tract layer found (tracts_work / tracts / barcelona_tracts).")

tracts_work <- sf::st_transform(tract_layer, sf::st_crs(added))

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
    dplyr::mutate(tract_id = as.character(.data[[id_col]]),
                  km = as.numeric(sf::st_length(geometry))/1000) |>
    sf::st_drop_geometry() |>
    dplyr::group_by(tract_id) |>
    dplyr::summarise(km = sum(km, na.rm = TRUE), .groups = "drop")
}

add_tr <- length_by_tract(added,   tracts_work, id_col) |> dplyr::mutate(Change = "Added")
rem_tr <- length_by_tract(removed, tracts_work, id_col) |> dplyr::mutate(Change = "Removed")
tr_dist <- dplyr::bind_rows(add_tr, rem_tr)

tr_km <- tr_dist |>
  tidyr::pivot_wider(names_from = Change, values_from = km,
                     values_fill = list(km = 0), values_fn = list(km = sum)) |>
  dplyr::mutate(Added = dplyr::coalesce(Added, 0),
                Removed = dplyr::coalesce(Removed, 0))

# ---- Build tracts_plot (for strata) -----------------------------------------
tracts_plot <- tracts_work |>
  dplyr::mutate(tract_id = as.character(.data[[id_col]])) |>
  dplyr::left_join(tr_km, by = "tract_id") |>
  dplyr::mutate(Added = dplyr::coalesce(Added, 0), Removed = dplyr::coalesce(Removed, 0))

# ---- Create/fetch 'stratum' -------------------------------------------------
nm <- names(tracts_plot)
pick <- function(nm_vec, cands){ hit <- intersect(cands, nm_vec); if (length(hit)) hit[1] else NA_character_ }
dens_col <- pick(nm, c("density_class","dens_class","dens_cat","density_cat","density_q","dens_q","density","dens"))
cent_col <- pick(nm, c("centrality_class","centr_class","centr_cat","centrality_cat","centrality_q","centr_q","centrality","centr"))

if ("stratum" %in% nm) {
  tracts_plot <- tracts_plot %>% dplyr::mutate(stratum = as.character(stratum))
} else if (!is.na(dens_col) && !is.na(cent_col)) {
  tracts_plot <- tracts_plot %>%
    dplyr::mutate(
      density_class    = if (is.numeric(.data[[dens_col]])) dplyr::ntile(.data[[dens_col]], 3) else as.character(.data[[dens_col]]),
      centrality_class = if (is.numeric(.data[[cent_col]])) dplyr::ntile(.data[[cent_col]], 3) else as.character(.data[[cent_col]]),
      stratum = paste0("D", density_class, "_C", centrality_class)
    )
} else {
  tracts_plot <- tracts_plot %>% dplyr::mutate(stratum = "All")
}

# ---- Summarise & print ------------------------------------------------------
stratum_summary <- tracts_plot %>%
  sf::st_drop_geometry() %>%
  dplyr::group_by(stratum) %>%
  dplyr::summarise(Added_km = sum(Added, na.rm = TRUE),
                   Removed_km = sum(Removed, na.rm = TRUE),
                   .groups = "drop") %>%
  dplyr::arrange(stratum)

tot_added   <- sum(stratum_summary$Added_km,   na.rm = TRUE)
tot_removed <- sum(stratum_summary$Removed_km, na.rm = TRUE)

stratum_out <- stratum_summary %>%
  dplyr::mutate(
    Added_pct   = if (tot_added   > 0) sprintf("%.1f%%", 100*Added_km/tot_added)   else "0.0%",
    Removed_pct = if (tot_removed > 0) sprintf("%.1f%%", 100*Removed_km/tot_removed) else "0.0%"
  ) %>%
  dplyr::mutate(dplyr::across(c(Added_km, Removed_km), ~round(.x, 1)))


