# 20-results-setup

# Parameters (keeps your values if already defined)
if (!exists("crs_work")) crs_work <- 25831
if (!exists("tol_m"))    tol_m    <- 10

# Helpers

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


# 24-pick-excel

FILE <- "outputs/barcelona_samples_2015_2023_joined_results_20251103.xlsx"

norm_presence_final <- function(x){
  x <- tolower(trimws(as.character(x)))
  dplyr::case_when(
    x %in% c("1") ~ 1L,
    x %in% c("0") ~ 0L,
    TRUE          ~ NA_integer_
  )
}

safe_read_exact <- function(path, sheet_name){
  
  df <- tryCatch(
    readxl::read_xlsx(
      path,
      sheet = sheet_name,
      skip  = 1,               # skip the group header row
      .name_repair = "minimal"
    ),
    error = function(e) tibble::tibble()
  )
  
  # Empty sheet case
  if (!nrow(df)) {
    return(tibble::tibble(
      tract_id      = character(),
      stratum       = character(),
      joined_result = NA,
      usable        = logical()
    ))
  }
  
  # 1) Clean names and fix blanks
  nm <- trimws(names(df))
  bad <- which(is.na(nm) | nm == "")
  if (length(bad)) {
    nm[bad] <- paste0("X", bad)
  }
  names(df) <- nm
  
  # 2) Drop duplicate names (keep first occurrence)
  nm <- names(df)
  dup <- duplicated(nm)
  if (any(dup)) {
    df <- df[, !dup, drop = FALSE]
  }
  nm <- names(df)
  
  # 3) Drop summary rows if there is a tract_id column
  if ("tract_id" %in% nm) {
    df <- df %>% dplyr::filter(!is.na(tract_id))
  }
  
  # 4) Find the joined_result column
  jr_name <- dplyr::case_when(
    "joined_result"  %in% nm ~ "joined_result",
    "joined_results" %in% nm ~ "joined_results",
    TRUE ~ NA_character_
  )
  
  if (is.na(jr_name)) {
    df$joined_result <- NA
  } else {
    df$joined_result <- df[[jr_name]]
  }
  
  # ensure stratum exists (will be filled by fill_stratum if missing)
  if (!"stratum" %in% names(df)) {
    df$stratum <- NA_character_
  }
  
  df %>%
    dplyr::mutate(
      tract_id = as.character(tract_id),
      stratum  = as.character(stratum)
    ) %>%
    # *** CRUCIAL CHANGE: keep only rows with a non-NA joined_result ***
    dplyr::filter(!is.na(joined_result)) %>%
    dplyr::mutate(
      usable = TRUE   # all remaining rows are usable by definition
    )
  
}

# 25-validation-stratum-summary

# -------- 0) Pick Excel (reuse FILE if already defined) ----------------------
if (!exists("FILE")) {
  pat  <- paste0("^", city_tag, "_samples_2015_2023_\\d{8}-\\d{4}\\.xlsx$")
  cand <- list.files("outputs", pattern = pat, full.names = TRUE)
  stopifnot(length(cand) > 0)
  FILE <- cand[which.max(file.info(cand)$mtime)]
}

# -------- 1) Stratum lookup (same as before) ---------------------------------
get_stratum_lookup <- function(){
  tr <- if (exists("tracts_work")) tracts_work else if (exists("tracts")) tracts else NULL
  if (is.null(tr)) return(NULL)
  
  nm <- names(tr)
  id_col <- dplyr::case_when(
    "tract_id"    %in% nm ~ "tract_id",
    "CUSEC"       %in% nm ~ "CUSEC",
    "codi_seccio" %in% nm ~ "codi_seccio",
    TRUE ~ nm[1]
  )
  
  has_stratum <- "stratum" %in% nm
  dens_col <- if ("density_class"    %in% nm) "density_class" else if ("dens_class" %in% nm) "dens_class" else NA
  cent_col <- if ("centrality_class" %in% nm) "centrality_class" else if ("centr_class"%in% nm) "centr_class" else NA
  
  out <- tr %>% st_drop_geometry() %>% as_tibble()
  
  if (!has_stratum && !is.na(dens_col) && !is.na(cent_col)) {
    out <- out %>%
      mutate(
        density_class    = if (is.numeric(.data[[dens_col]])) ntile(.data[[dens_col]], 3) else .data[[dens_col]],
        centrality_class = if (is.numeric(.data[[cent_col]])) ntile(.data[[cent_col]], 3) else .data[[cent_col]],
        stratum = paste0("D", density_class, "_C", centrality_class)
      )
  }
  
  if (!("stratum" %in% names(out))) return(NULL)
  
  out %>%
    transmute(
      tract_id = as.character(.data[[id_col]]),
      stratum  = as.character(stratum)
    ) %>%
    distinct()
}

strata_lkp <- get_stratum_lookup()

fill_stratum <- function(df){
  if (is.null(strata_lkp) || !"tract_id" %in% names(df)) {
    df %>% mutate(stratum = coalesce(stratum, "All"))
  } else {
    df %>%
      left_join(strata_lkp, by = "tract_id", suffix = c("", ".lkp")) %>%
      mutate(stratum = coalesce(stratum, stratum.lkp, "All")) %>%
      select(-any_of("stratum.lkp"))
  }
}

# -------- 2) Helper to read ONE sheet ----------------------------------------
read_sheet <- function(sheet_name, class_label){
  
  df <- tryCatch(
    readxl::read_xlsx(
      FILE,
      sheet = sheet_name,
      skip  = 1,          # skip header row
      .name_repair = "minimal"
    ),
    error = function(e) tibble::tibble()
  )
  
  if (!nrow(df)) {
    return(tibble::tibble(
      id            = numeric(),
      tract_id      = character(),
      stratum       = character(),
      joined_result = NA,
      class         = character()
    ))
  }
  
  # 1) fix blank / NA column names
  nm <- trimws(names(df))
  bad <- which(is.na(nm) | nm == "")
  if (length(bad)) nm[bad] <- paste0("X", bad)
  names(df) <- nm
  
  # 2) ensure required columns exist
  if (!"tract_id" %in% names(df)) df$tract_id <- NA_character_
  if (!"stratum"  %in% names(df)) df$stratum  <- NA_character_
  
  if (!"joined_result" %in% names(df)) {
    if ("joined_results" %in% names(df)) {
      df$joined_result <- df$joined_results
    } else {
      df$joined_result <- NA
    }
  }
  
  df %>%
    # drop summary rows at bottom (no tract_id)
    filter(!is.na(tract_id)) %>%
    mutate(
      tract_id      = as.character(tract_id),
      stratum       = as.character(stratum),
      class         = class_label
    )
}

# -------- 3) Read three sheets and fill stratum ------------------------------
add_tbl   <- safe_read_exact(FILE, "ADD")    %>% fill_stratum() %>% mutate(class = "ADD")
rem_tbl   <- safe_read_exact(FILE, "REMOVE") %>% fill_stratum() %>% mutate(class = "REMOVE")
nonci_tbl <- safe_read_exact(FILE, "NONCI")  %>% fill_stratum() %>% mutate(class = "NONCI")


all_strata <- sort(unique(c(add_tbl$stratum, rem_tbl$stratum, nonci_tbl$stratum)))
if (!length(all_strata)) all_strata <- "All"

# all rows here are usable (NA joined_result already removed)
usable_tbl <- dplyr::bind_rows(add_tbl, rem_tbl, nonci_tbl)

# quick diagnostic if you want to check:
# usable_tbl %>% count(class)

summary_stratum_class <- usable_tbl %>%
  count(stratum, class, name = "n") %>%
  complete(
    stratum = all_strata,
    class   = c("ADD", "REMOVE", "NONCI"),
    fill    = list(n = 0L)
  ) %>%
  pivot_wider(names_from = class, values_from = n, values_fill = 0L)

wanted_cols <- c("stratum","ADD", "REMOVE","NONCI")
for (cc in setdiff(wanted_cols, names(summary_stratum_class))) {
  summary_stratum_class[[cc]] <- 0L
}

summary_stratum_class <- summary_stratum_class %>%
  select(all_of(wanted_cols)) %>%
  mutate(Total = REMOVE + ADD + NONCI) %>%
  arrange(stratum)

summary_stratum_class_full <- bind_rows(
  summary_stratum_class,
  summarise(
    summary_stratum_class,
    stratum = "TOTAL",
    ADD     = sum(ADD,     na.rm = TRUE),
    REMOVE  = sum(REMOVE,  na.rm = TRUE),
    NONCI   = sum(NONCI,   na.rm = TRUE),
    Total   = sum(Total,   na.rm = TRUE)
  )
)

# 26-validation-metrics

FILE <- "outputs/barcelona_samples_2015_2023_joined_results_20251103.xlsx"

# --- helper: read full validation sheet (one of ADD / REMOVE / NONCI) --------
read_validation_sheet <- function(path, sheet_name) {
  
  df <- tryCatch(
    readxl::read_xlsx(
      path,
      sheet = sheet_name,
      skip  = 1,              # first row after the big header
      .name_repair = "minimal"
    ),
    error = function(e) tibble::tibble()
  )
  
  if (!nrow(df)) return(tibble::tibble())
  
  # 1) Clean names and fix blanks / duplicates
  nm  <- trimws(names(df))
  bad <- which(is.na(nm) | nm == "")
  if (length(bad)) nm[bad] <- paste0("X", bad)
  names(df) <- nm
  
  nm  <- names(df)
  dup <- duplicated(nm)
  if (any(dup)) df <- df[, !dup, drop = FALSE]
  
  # 2) Drop summary rows (no tract_id)
  if ("tract_id" %in% names(df)) {
    df <- df %>% filter(!is.na(tract_id))
  }
  
  # 3) Make sure the expected columns exist (or NA)
  maybe_num <- function(x) suppressWarnings(as.numeric(x))
  
  if (!"class" %in% names(df)) df$class <- sheet_name
  
  for (cc in c("evt_present_baseline", "evt_present_followup",
               "vgp_present_baseline", "vgp_present_followup",
               "consensus", "joined_result")) {
    if (!cc %in% names(df)) df[[cc]] <- NA
  }
  
  df %>%
    mutate(
      class                = as.character(class),
      evt_present_baseline = maybe_num(evt_present_baseline),
      evt_present_followup = maybe_num(evt_present_followup),
      vgp_present_baseline = maybe_num(vgp_present_baseline),
      vgp_present_followup = maybe_num(vgp_present_followup),
      consensus            = maybe_num(consensus),
      joined_result        = maybe_num(joined_result)
    )
}

# --- 1) Read all three sheets -------------------------------------------------
add_df   <- read_validation_sheet(FILE, "ADD")
rem_df   <- read_validation_sheet(FILE, "REMOVE")
nonci_df <- read_validation_sheet(FILE, "NONCI")

all_df <- bind_rows(add_df, rem_df, nonci_df)

# --- 2) Build ground truth: baseline / follow-up & real change ----------------
all_df <- all_df %>%
  mutate(
    # baseline: prefer VGP, then EVT
    baseline_truth = coalesce(vgp_present_baseline, evt_present_baseline),
    # follow-up: prefer consensus if present, else VGP, else EVT
    followup_truth = case_when(
      !is.na(consensus) ~ consensus,
      TRUE              ~ coalesce(vgp_present_followup, evt_present_followup)
    ),
    real_change = case_when(
      !is.na(baseline_truth) & !is.na(followup_truth) &
        baseline_truth == 0 & followup_truth == 1 ~ "ADD",
      !is.na(baseline_truth) & !is.na(followup_truth) &
        baseline_truth == 1 & followup_truth == 0 ~ "REMOVE",
      !is.na(baseline_truth) & !is.na(followup_truth) &
        baseline_truth == followup_truth          ~ "NO_CHANGE",
      TRUE                                        ~ "UNKNOWN"
    ),
    usable = !is.na(joined_result)
  ) %>%
  filter(usable, real_change != "UNKNOWN")


# quick sanity check (can be commented out later):
# all_df %>% count(class, real_change)

# --- 3) Confusion counts for ADD / REMOVE / pooled ----------------------------
count_ <- function(x) sum(x, na.rm = TRUE)

TP_add <- count_(all_df$class == "ADD"    & all_df$real_change == "ADD")
FP_add <- count_(all_df$class == "ADD"    & all_df$real_change != "ADD")
FN_add <- count_(all_df$class != "ADD"    & all_df$real_change == "ADD")

TP_rem <- count_(all_df$class == "REMOVE" & all_df$real_change == "REMOVE")
FP_rem <- count_(all_df$class == "REMOVE" & all_df$real_change != "REMOVE")
FN_rem <- count_(all_df$class != "REMOVE" & all_df$real_change == "REMOVE")

TP_T <- TP_add + TP_rem
FP_T <- count_(all_df$class %in% c("ADD","REMOVE") &
                 all_df$real_change == "NO_CHANGE")
FN_T <- count_(all_df$class == "NONCI" &
                 all_df$real_change %in% c("ADD","REMOVE"))

n_add_usable <- count_(all_df$class == "ADD")
n_rem_usable <- count_(all_df$class == "REMOVE")
n_tot_usable <- count_(all_df$class %in% c("ADD","REMOVE"))

# --- 4) Metrics & 95 % CIs ----------------------------------------------------
metric <- function(tp, fp, fn){
  precision <- ifelse(tp + fp > 0, tp / (tp + fp), NA_real_)
  recall    <- ifelse(tp + fn > 0, tp / (tp + fn), NA_real_)
  f1        <- ifelse(
    is.finite(precision + recall) & (precision + recall) > 0,
    2 * precision * recall / (precision + recall),
    NA_real_
  )
  list(precision = precision, recall = recall, f1 = f1)
}

p_ci <- function(x, n){
  if (is.na(x) || is.na(n) || n == 0) return(c(NA_real_, NA_real_))
  suppressWarnings(stats::prop.test(x, n, correct = FALSE)$conf.int)
}

m_add <- metric(TP_add, FP_add, FN_add)
m_rem <- metric(TP_rem, FP_rem, FN_rem)
m_tot <- metric(TP_T,   FP_T,   FN_T)

add_prec_ci <- p_ci(TP_add, TP_add + FP_add)
add_rec_ci  <- p_ci(TP_add, TP_add + FN_add)

rem_prec_ci <- p_ci(TP_rem, TP_rem + FP_rem)
rem_rec_ci  <- p_ci(TP_rem, TP_rem + FN_rem)

tot_prec_ci <- p_ci(TP_T,   TP_T   + FP_T)
tot_rec_ci  <- p_ci(TP_T,   TP_T   + FN_T)

fmt_ci <- function(est, ci) {
  if (is.finite(est) && all(is.finite(ci))) {
    sprintf("%.2f [%.2f-%.2f]", est, ci[1], ci[2])
  } else {
    "NA [NA-NA]"
  }
}

t_class <- tibble(
  Class            = c("ADD","REMOVE","Pooled"),
  `n (usable)`     = c(n_add_usable, n_rem_usable, n_tot_usable),
  TP               = c(TP_add, TP_rem, TP_T),
  FP               = c(FP_add, FP_rem, FP_T),
  FN               = c(FN_add, FN_rem, FN_T),
  `Precision (95% CI)` = c(
    fmt_ci(m_add$precision, add_prec_ci),
    fmt_ci(m_rem$precision, rem_prec_ci),
    fmt_ci(m_tot$precision, tot_prec_ci)
  ),
  `Recall (95% CI)` = c(
    fmt_ci(m_add$recall, add_rec_ci),
    fmt_ci(m_rem$recall, rem_rec_ci),
    fmt_ci(m_tot$recall, tot_rec_ci)
  ),
  F1 = sprintf("%.2f", c(m_add$f1, m_rem$f1, m_tot$f1))
)

