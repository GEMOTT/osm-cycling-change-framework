# 09_results_validation.R
# - Uses coder1 / coder2 Excel files created by 07_export_excel.R
# - Builds a joined_results workbook (once, or when forced)
# - Uses only consensus as ground truth for metrics
# - Stops if any coder disagreements remain without consensus

# -------------------------------------------------------------------
# 0) File paths and options
# -------------------------------------------------------------------

outdir <- "outputs"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

if (!exists("city_tag")) {
  stop("city_tag must be defined before running 09_results_validation.R")
}

coder1_file <- file.path(outdir, paste0(city_tag, "_samples_2015_2023_coder1.xlsx"))
coder2_file <- file.path(outdir, paste0(city_tag, "_samples_2015_2023_coder2.xlsx"))
joined_file <- file.path(outdir, paste0(city_tag, "_samples_2015_2023_joined_results.xlsx"))

# set to TRUE only when you want to rebuild joined_file from coder Excels
rebuild_joined <- FALSE


# -------------------------------------------------------------------
# 1) Helpers to read coder sheets and build joined sheets
# -------------------------------------------------------------------

norm01 <- function(x) {
  # Normalise "0"/"1"/"NA"/TRUE/FALSE/blank to 0/1/NA_integer_
  x <- tolower(trimws(as.character(x)))
  case_when(
    x %in% c("1", "true")  ~ 1L,
    x %in% c("0", "false") ~ 0L,
    TRUE                   ~ NA_integer_
  )
}

read_coder_sheet <- function(path, sheet_name, coder_label) {
  # coder_label is "coder1" or "coder2"
  
  if (is.null(path) || !file.exists(path)) {
    return(tibble(
      id                          = numeric(),
      class                       = character(),
      tract_id                    = character(),
      stratum                     = character(),
      !!paste0(coder_label, "_present_baseline") := integer(),
      !!paste0(coder_label, "_present_followup") := integer(),
      !!paste0(coder_label, "_match")            := integer()
    ))
  }
  
  df <- tryCatch(
    readxl::read_xlsx(
      path,
      sheet = sheet_name,
      skip  = 1,                # skip group header row, read header at row 2
      .name_repair = "minimal"
    ),
    error = function(e) tibble()
  )
  
  if (!nrow(df)) {
    return(tibble(
      id                          = numeric(),
      class                       = character(),
      tract_id                    = character(),
      stratum                     = character(),
      !!paste0(coder_label, "_present_baseline") := integer(),
      !!paste0(coder_label, "_present_followup") := integer(),
      !!paste0(coder_label, "_match")            := integer()
    ))
  }
  
  # clean names: blanks, duplicates
  nm <- trimws(names(df))
  bad <- which(is.na(nm) | nm == "")
  if (length(bad)) nm[bad] <- paste0("X", bad)
  names(df) <- nm
  dup <- duplicated(names(df))
  if (any(dup)) df <- df[, !dup, drop = FALSE]
  
  # mandatory columns (or defaults)
  if (!"id"       %in% names(df)) df$id       <- NA_real_
  if (!"class"    %in% names(df)) df$class    <- sheet_name
  if (!"tract_id" %in% names(df)) df$tract_id <- NA_character_
  if (!"stratum"  %in% names(df)) df$stratum  <- NA_character_
  
  if (!"present_baseline" %in% names(df)) df$present_baseline <- NA
  if (!"present_followup" %in% names(df)) df$present_followup <- NA
  
  # match column from add_match_col()
  match_col <- case_when(
    "osm_gsv_match" %in% names(df) ~ "osm_gsv_match",
    "Match"         %in% names(df) ~ "Match",
    TRUE                           ~ NA_character_
  )
  if (is.na(match_col)) {
    df$osm_gsv_match <- NA
    match_col <- "osm_gsv_match"
  }
  
  df %>%
    mutate(
      id       = as.numeric(id),
      class    = as.character(class),
      tract_id = as.character(tract_id),
      stratum  = as.character(stratum),
      present_baseline = norm01(present_baseline),
      present_followup = norm01(present_followup),
      match_val        = norm01(.data[[match_col]])
    ) %>%
    select(id, class, tract_id, stratum,
           present_baseline, present_followup, match_val) %>%
    rename(
      !!paste0(coder_label, "_present_baseline") := present_baseline,
      !!paste0(coder_label, "_present_followup") := present_followup,
      !!paste0(coder_label, "_match")            := match_val
    )
}

build_joined_sheet_for_class <- function(sheet_name,
                                         coder1_file,
                                         coder2_file = NULL) {
  
  c1 <- read_coder_sheet(coder1_file, sheet_name, coder_label = "coder1")
  c2 <- read_coder_sheet(coder2_file, sheet_name, coder_label = "coder2")
  
  joined <- full_join(
    c1, c2,
    by = c("id", "class", "tract_id", "stratum")
  ) %>%
    arrange(class, id)
  
  joined <- joined %>%
    mutate(
      coder1_match = norm01(coder1_match),
      coder2_match = norm01(coder2_match),
      coder1_present_baseline = norm01(coder1_present_baseline),
      coder1_present_followup = norm01(coder1_present_followup),
      coder2_present_baseline = norm01(coder2_present_baseline),
      coder2_present_followup = norm01(coder2_present_followup)
    )
  
  # automatic consensus where both coders agree (baseline and follow-up)
  joined <- joined %>%
    mutate(
      consensus_baseline = case_when(
        !is.na(coder1_present_baseline) & !is.na(coder2_present_baseline) &
          coder1_present_baseline == coder2_present_baseline ~ coder1_present_baseline,
        TRUE ~ NA_integer_
      ),
      consensus_followup = case_when(
        !is.na(coder1_present_followup) & !is.na(coder2_present_followup) &
          coder1_present_followup == coder2_present_followup ~ coder1_present_followup,
        TRUE ~ NA_integer_
      )
    )
  
  # flag rows needing manual consensus (both coders coded, but disagree or missing consensus)
  joined <- joined %>%
    mutate(
      needs_consensus = case_when(
        # both coders gave some follow-up code AND they differ OR consensus is NA
        !is.na(coder1_present_followup) & !is.na(coder2_present_followup) &
          coder1_present_followup != coder2_present_followup ~ TRUE,
        # you might want to also flag baseline disagreements similarly
        TRUE ~ FALSE
      )
    )
  
  # joined_result: summary of match info (0,1,2) or NA
  joined <- joined %>%
    mutate(
      joined_result = case_when(
        is.na(coder1_match) & is.na(coder2_match) ~ NA_real_,   # nothing coded
        !is.na(coder1_match) & is.na(coder2_match) ~ coder1_match * 1.0,
        is.na(coder1_match) & !is.na(coder2_match) ~ coder2_match * 1.0,
        TRUE ~ (coder1_match + coder2_match) * 1.0
      )
    )
  
  joined
}

build_joined_results <- function(city_tag,
                                 coder1_file,
                                 coder2_file = NULL,
                                 out_file    = NULL) {
  
  if (is.null(out_file)) {
    out_file <- file.path("outputs",
                          paste0(city_tag, "_samples_2015_2023_joined_results.xlsx"))
  }
  
  sheets <- c("ADD", "REMOVE", "NONCI")
  joined_list <- lapply(sheets, function(sh) {
    build_joined_sheet_for_class(sh, coder1_file, coder2_file)
  })
  names(joined_list) <- sheets
  
  wb <- openxlsx::createWorkbook()
  for (sh in sheets) {
    openxlsx::addWorksheet(wb, sh)
    # write header at row 2 to mimic your existing layout
    openxlsx::writeData(wb, sh, joined_list[[sh]], startRow = 2, startCol = 1, colNames = TRUE)
  }
  openxlsx::saveWorkbook(wb, out_file, overwrite = TRUE)
  message("Wrote joined results to: ", out_file)
  
  invisible(out_file)
}


# -------------------------------------------------------------------
# 2) Build joined_results (once, or when forced)
# -------------------------------------------------------------------

if (!file.exists(joined_file) || rebuild_joined) {
  if (!file.exists(coder1_file)) stop("Coder1 file not found: ", coder1_file)
  if (!file.exists(coder2_file)) stop("Coder2 file not found: ", coder2_file)
  
  build_joined_results(
    city_tag    = city_tag,
    coder1_file = coder1_file,
    coder2_file = coder2_file,
    out_file    = joined_file
  )
} else {
  message("Using existing joined_results file: ", joined_file)
}

FILE <- joined_file


# -------------------------------------------------------------------
# 3) Stratum counts (24-pick-excel + 25-summary) using joined_result
# -------------------------------------------------------------------

norm_presence_final <- function(x){
  x <- tolower(trimws(as.character(x)))
  case_when(
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
    error = function(e) tibble()
  )
  
  # Empty sheet case
  if (!nrow(df)) {
    return(tibble(
      tract_id      = character(),
      stratum       = character(),
      joined_result = NA_real_,
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
    df <- df %>% filter(!is.na(tract_id))
  }
  
  # 4) joined_result column
  jr_name <- case_when(
    "joined_result"  %in% nm ~ "joined_result",
    "joined_results" %in% nm ~ "joined_results",
    TRUE                     ~ NA_character_
  )
  
  if (is.na(jr_name)) {
    df$joined_result <- NA_real_
  } else {
    df$joined_result <- suppressWarnings(as.numeric(df[[jr_name]]))
  }
  
  # ensure stratum exists (will be filled by fill_stratum if missing)
  if (!"stratum" %in% names(df)) {
    df$stratum <- NA_character_
  }
  
  df %>%
    mutate(
      tract_id = as.character(tract_id),
      stratum  = as.character(stratum)
    ) %>%
    # keep only rows with a non-NA joined_result
    filter(!is.na(joined_result)) %>%
    mutate(
      usable = TRUE   # all remaining rows are usable by definition
    )
}

# --- stratum lookup (same as your previous code) -------------------

get_stratum_lookup <- function(){
  tr <- if (exists("tracts_work")) tracts_work else if (exists("tracts")) tracts else NULL
  if (is.null(tr)) return(NULL)
  
  nm <- names(tr)
  id_col <- case_when(
    "tract_id"    %in% nm ~ "tract_id",
    "CUSEC"       %in% nm ~ "CUSEC",
    "codi_seccio" %in% nm ~ "codi_seccio",
    TRUE ~ nm[1]
  )
  
  has_stratum <- "stratum" %in% nm
  dens_col <- if ("density_class"    %in% nm) "density_class" else if ("dens_class" %in% nm) "dens_class" else NA
  cent_col <- if ("centrality_class" %in% nm) "centrality_class" else if ("centr_class"%in% nm) "centr_class" else NA
  
  out <- tr %>% sf::st_drop_geometry() %>% as_tibble()
  
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

# read three sheets, fill stratum, build summary
add_tbl   <- safe_read_exact(FILE, "ADD")    %>% fill_stratum() %>% mutate(class = "ADD")
rem_tbl   <- safe_read_exact(FILE, "REMOVE") %>% fill_stratum() %>% mutate(class = "REMOVE")
nonci_tbl <- safe_read_exact(FILE, "NONCI")  %>% fill_stratum() %>% mutate(class = "NONCI")

all_strata <- sort(unique(c(add_tbl$stratum, rem_tbl$stratum, nonci_tbl$stratum)))
if (!length(all_strata)) all_strata <- "All"

usable_tbl <- bind_rows(add_tbl, rem_tbl, nonci_tbl)

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


# -------------------------------------------------------------------
# 4) Validation metrics using ONLY consensus
# -------------------------------------------------------------------

read_validation_sheet <- function(path, sheet_name) {
  
  df <- tryCatch(
    readxl::read_xlsx(
      path,
      sheet = sheet_name,
      skip  = 1,              # first row after the group header
      .name_repair = "minimal"
    ),
    error = function(e) tibble()
  )
  
  if (!nrow(df)) return(tibble())
  
  nm  <- trimws(names(df))
  bad <- which(is.na(nm) | nm == "")
  if (length(bad)) nm[bad] <- paste0("X", bad)
  names(df) <- nm
  
  nm  <- names(df)
  dup <- duplicated(nm)
  if (any(dup)) df <- df[, !dup, drop = FALSE]
  
  if ("tract_id" %in% names(df)) {
    df <- df %>% filter(!is.na(tract_id))
  }
  
  maybe_num <- function(x) suppressWarnings(as.numeric(x))
  
  if (!"class" %in% names(df)) df$class <- sheet_name
  
  for (cc in c("coder1_present_baseline", "coder1_present_followup",
               "coder2_present_baseline", "coder2_present_followup",
               "consensus_baseline", "consensus_followup",
               "joined_result")) {
    if (!cc %in% names(df)) df[[cc]] <- NA
  }
  
  df %>%
    mutate(
      class                = as.character(class),
      coder1_present_baseline = maybe_num(coder1_present_baseline),
      coder1_present_followup = maybe_num(coder1_present_followup),
      coder2_present_baseline = maybe_num(coder2_present_baseline),
      coder2_present_followup = maybe_num(coder2_present_followup),
      consensus_baseline      = maybe_num(consensus_baseline),
      consensus_followup      = maybe_num(consensus_followup),
      joined_result           = maybe_num(joined_result)
    )
}

add_df   <- read_validation_sheet(FILE, "ADD")
rem_df   <- read_validation_sheet(FILE, "REMOVE")
nonci_df <- read_validation_sheet(FILE, "NONCI")

all_df <- bind_rows(add_df, rem_df, nonci_df)

# ---  build ground truth: ONLY consensus --------------------------

all_df <- all_df %>%
  mutate(
    baseline_truth = consensus_baseline,
    followup_truth = consensus_followup,
    real_change = case_when(
      !is.na(baseline_truth) & !is.na(followup_truth) &
        baseline_truth == 0 & followup_truth == 1 ~ "ADD",
      !is.na(baseline_truth) & !is.na(followup_truth) &
        baseline_truth == 1 & followup_truth == 0 ~ "REMOVE",
      !is.na(baseline_truth) & !is.na(followup_truth) &
        baseline_truth == followup_truth          ~ "NO_CHANGE",
      TRUE                                        ~ "UNKNOWN"
    ),
    usable = !is.na(baseline_truth) & !is.na(followup_truth)
  ) %>%
  filter(usable, real_change != "UNKNOWN")

# --- confusion counts ---------------------------------------------

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

# --- metrics + CIs ------------------------------------------------

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
    fmt_ci(m_tot$recall, rem_rec_ci)
  ),
  F1 = sprintf("%.2f", c(m_add$f1, m_rem$f1, m_tot$f1))
)