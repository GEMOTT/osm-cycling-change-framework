# 09_results_validation.R
# - Uses coder1 / coder2 Excel files created by 07_export_excel.R
# - Builds a joined_results workbook (once, or when forced)
# - Uses only consens as ground truth for metrics
# - A row is usable when consens_bl and consens_fu are both 0/1

# -------------------------------------------------------------------
# 0) File paths and options
# -------------------------------------------------------------------

if (!exists("city_tag")) {
  stop("city_tag must be defined before running 09_results_validation.R")
}

coder1_file <- file.path(outdir, paste0(city_tag, "_samples_2015_2023_coder1.xlsx"))
coder2_file <- file.path(outdir, paste0(city_tag, "_samples_2015_2023_coder2.xlsx"))
joined_file <- file.path(outdir, paste0(city_tag, "_samples_2015_2023_joined_results.xlsx"))

# Set to TRUE only when you want to rebuild joined_file from coder Excels
rebuild_joined <- TRUE

# -------------------------------------------------------------------
# 1) Helpers to read coder sheets and build joined sheets
# -------------------------------------------------------------------

norm01 <- function(x) {
  # Normalise "0"/"1"/"NA"/TRUE/FALSE/blank to 0/1/NA_integer_
  x <- tolower(trimws(as.character(x)))
  dplyr::case_when(
    x %in% c("1", "true")  ~ 1L,
    x %in% c("0", "false") ~ 0L,
    TRUE                   ~ NA_integer_
  )
}

read_coder_sheet <- function(path, sheet_name, coder_prefix) {
  # coder_prefix is "c1" or "c2"
  
  if (is.null(path) || !file.exists(path)) {
    return(tibble::tibble(
      id                      = numeric(),
      class                   = character(),
      tract_id                = character(),
      stratum                 = character(),
      !!paste0(coder_prefix, "_bl") := integer(),
      !!paste0(coder_prefix, "_fu") := integer()
    ))
  }
  
  df <- tryCatch(
    readxl::read_xlsx(
      path,
      sheet = sheet_name,
      skip  = 1,                # skip group header row, read header at row 2
      .name_repair = "minimal"
    ),
    error = function(e) tibble::tibble()
  )
  
  if (!nrow(df)) {
    return(tibble::tibble(
      id                      = numeric(),
      class                   = character(),
      tract_id                = character(),
      stratum                 = character(),
      !!paste0(coder_prefix, "_bl") := integer(),
      !!paste0(coder_prefix, "_fu") := integer()
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
  
  # --- NEW: locate fused columns under old or new names ----------------------
  fu_col <- dplyr::case_when(
    "pres_fu"          %in% names(df) ~ "pres_fu",           # new template
    "present_followup" %in% names(df) ~ "present_followup",  # old template
    TRUE                               ~ NA_character_
  )
  bl_col <- dplyr::case_when(
    "pres_bl"          %in% names(df) ~ "pres_bl",           # new template
    "present_baseline" %in% names(df) ~ "present_baseline",  # old template
    TRUE                               ~ NA_character_
  )
  
  if (is.na(fu_col)) df$present_followup <- NA_integer_ else
    df$present_followup <- norm01(df[[fu_col]])
  
  if (is.na(bl_col)) df$present_baseline <- NA_integer_ else
    df$present_baseline <- norm01(df[[bl_col]])
  # ---------------------------------------------------------------------------
  
  df %>%
    dplyr::mutate(
      id       = as.numeric(id),
      class    = as.character(class),
      tract_id = as.character(tract_id),
      stratum  = as.character(stratum)
    ) %>%
    dplyr::select(id, class, tract_id, stratum,
                  present_baseline, present_followup) %>%
    dplyr::rename(
      !!paste0(coder_prefix, "_bl") := present_baseline,
      !!paste0(coder_prefix, "_fu") := present_followup
    )
}


build_joined_sheet_for_class <- function(sheet_name,
                                         coder1_file,
                                         coder2_file = NULL) {
  
  # coder prefixes -> short column names in joined sheet
  c1 <- read_coder_sheet(coder1_file, sheet_name, coder_prefix = "c1")
  c2 <- read_coder_sheet(coder2_file, sheet_name, coder_prefix = "c2")
  
  joined <- dplyr::full_join(
    c1, c2,
    by = c("id", "class", "tract_id", "stratum")
  ) %>%
    dplyr::arrange(class, id)
  
  # 1) Automatic coder CONSENSUS where BOTH coders coded AND agree
  joined <- joined %>%
    dplyr::mutate(
      consens_bl = dplyr::case_when(
        !is.na(c1_bl) & !is.na(c2_bl) & c1_bl == c2_bl ~ c1_bl,
        TRUE                                           ~ NA_integer_
      ),
      consens_fu = dplyr::case_when(
        !is.na(c1_fu) & !is.na(c2_fu) & c1_fu == c2_fu ~ c1_fu,
        TRUE                                           ~ NA_integer_
      )
    )
  
  # 2) Flag rows that still need consensus:
  #    any time consens_* is NA but at least one coder has given info
  joined <- joined %>%
    dplyr::mutate(
      needs_consens = dplyr::case_when(
        (is.na(consens_fu) & (!is.na(c1_fu) | !is.na(c2_fu))) |
          (is.na(consens_bl) & (!is.na(c1_bl) | !is.na(c2_bl))) ~ TRUE,
        TRUE                                                  ~ FALSE
      )
    )
  
  # 3) FINAL columns (what you actually use in the analysis)
  #    Default = coder consensus; you can override in Excel.
  joined <- joined %>%
    dplyr::mutate(
      fu_fin = consens_fu,
      bl_fin = consens_bl
    )
  
  # 4) Column for comments about the final decision
  if (!"fin_note" %in% names(joined)) {
    joined$fin_note <- NA_character_
  }
  
  # 5) Add an empty 'usable' column; we will fill it with an Excel formula later
  if (!"usable" %in% names(joined)) {
    joined$usable <- NA_integer_
  }
  
  # FINAL COLUMN ORDER (coders → consensus → flags → final → note → usable)
  base_order <- c(
    "id", "class", "tract_id", "stratum",
    "c1_fu", "c1_bl",
    "c2_fu", "c2_bl",
    "consens_fu", "consens_bl",
    "needs_consens",
    "fu_fin", "bl_fin",
    "usable",
    "fin_note"
  )
  
  
  joined %>%
    dplyr::select(dplyr::any_of(base_order))
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
    df_sh   <- joined_list[[sh]]
    n_rows  <- nrow(df_sh)
    
    openxlsx::addWorksheet(wb, sh)
    openxlsx::writeData(wb, sh, df_sh, startRow = 2, startCol = 1, colNames = TRUE)
    
    if (n_rows > 0) {
      nm      <- names(df_sh)
      col_fu  <- match("fu_fin",   nm)
      col_bl  <- match("bl_fin",   nm)
      col_use <- match("usable",   nm)
      
      if (any(is.na(c(col_fu, col_bl, col_use)))) {
        stop("Expected columns fu_fin, bl_fin, usable in joined sheet for ", sh)
      }
      
      C        <- openxlsx::int2col
      fu_col_l <- C(col_fu)
      bl_col_l <- C(col_bl)
      use_col  <- col_use
      
      # Add formula: usable = 1 if both final cols are non-blank, else ""
      for (r in seq_len(n_rows)) {
        excel_row <- r + 2  # because data start at row 3
        formula <- sprintf(
          'IF(AND(NOT(ISBLANK(%s%d)),NOT(ISBLANK(%s%d))),1,"")',
          fu_col_l, excel_row,
          bl_col_l, excel_row
        )
        openxlsx::writeFormula(
          wb, sh,
          x = formula,
          startCol = use_col,
          startRow = excel_row
        )
      }
    }
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
# 3) Stratum counts using consens-based usability
# -------------------------------------------------------------------

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
      tract_id = character(),
      stratum  = character()
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
  
  # 4) Ensure stratum exists
  if (!"stratum" %in% names(df)) {
    df$stratum <- NA_character_
  }
  
  # 5) Keep only usable rows (both final values filled)
  if (!all(c("bl_fin", "fu_fin") %in% names(df))) {
    stop("joined_results sheets must contain bl_fin and fu_fin.")
  }
  
  keep <- !is.na(df$bl_fin) & !is.na(df$fu_fin)
  
  df %>%
    dplyr::mutate(
      tract_id = as.character(tract_id),
      stratum  = as.character(stratum)
    ) %>%
    dplyr::filter(keep) %>%
    dplyr::select(tract_id, stratum)
}

# --- stratum lookup ------------------------------------------------

get_stratum_lookup <- function() {
  # 1) Pick which tracts object to use
  tr <- if (exists("barcelona_tracts")) {
    barcelona_tracts
  } else if (exists("tracts_work")) {
    tracts_work
  } else if (exists("tracts")) {
    tracts
  } else {
    return(NULL)
  }
  
  out <- tr |>
    sf::st_drop_geometry() |>
    tibble::as_tibble()
  
  nm <- names(out)
  
  # 2) Identify the tract ID column
  id_col <- dplyr::case_when(
    "tract_id"    %in% nm ~ "tract_id",
    "CUSEC"       %in% nm ~ "CUSEC",
    "codi_seccio" %in% nm ~ "codi_seccio",
    TRUE ~ nm[1]
  )
  
  # 3) Ensure we have a "stratum" column
  if (!"stratum" %in% nm) {
    
    if ("stratum_id" %in% nm) {
      # From your 11-tracts-stratify chunk
      out$stratum <- as.character(out$stratum_id)
      
    } else if (all(c("dens_stratum", "cent_stratum") %in% nm)) {
      # Rebuild from numeric classes if needed
      out$stratum <- paste0("D", out$dens_stratum, "_C", out$cent_stratum)
      
    } else {
      # Nothing to build from
      return(NULL)
    }
  }
  
  # 4) Keep only ID + stratum and normalise names
  out <- out[, c(id_col, "stratum"), drop = FALSE]
  names(out) <- c("tract_id", "stratum")
  
  dplyr::distinct(out)
}

strata_lkp <- get_stratum_lookup()

fill_stratum <- function(df) {
  if (is.null(strata_lkp) || !"tract_id" %in% names(df)) {
    df %>%
      dplyr::mutate(stratum = dplyr::coalesce(stratum, "All"))
  } else {
    df %>%
      dplyr::left_join(strata_lkp, by = "tract_id", suffix = c("", ".lkp")) %>%
      dplyr::mutate(stratum = dplyr::coalesce(stratum, stratum.lkp, "All")) %>%
      dplyr::select(-dplyr::any_of("stratum.lkp"))
  }
}



# read three sheets, fill stratum, build summary
add_tbl   <- safe_read_exact(FILE, "ADD")    %>% fill_stratum() %>% dplyr::mutate(class = "ADD")
rem_tbl   <- safe_read_exact(FILE, "REMOVE") %>% fill_stratum() %>% dplyr::mutate(class = "REMOVE")
nonci_tbl <- safe_read_exact(FILE, "NONCI")  %>% fill_stratum() %>% dplyr::mutate(class = "NONCI")

all_strata <- sort(unique(c(add_tbl$stratum, rem_tbl$stratum, nonci_tbl$stratum)))
if (!length(all_strata)) all_strata <- "All"

usable_tbl <- dplyr::bind_rows(add_tbl, rem_tbl, nonci_tbl)

summary_stratum_class <- usable_tbl %>%
  dplyr::count(stratum, class, name = "n") %>%
  tidyr::complete(
    stratum = all_strata,
    class   = c("ADD", "REMOVE", "NONCI"),
    fill    = list(n = 0L)
  ) %>%
  tidyr::pivot_wider(names_from = class, values_from = n, values_fill = 0L)

wanted_cols <- c("stratum","ADD", "REMOVE","NONCI")
for (cc in setdiff(wanted_cols, names(summary_stratum_class))) {
  summary_stratum_class[[cc]] <- 0L
}

summary_stratum_class <- usable_tbl %>%
  dplyr::count(stratum, class, name = "n") %>%
  tidyr::complete(
    stratum = all_strata,
    class   = c("ADD", "REMOVE", "NONCI"),
    fill    = list(n = 0L)
  ) %>%
  tidyr::pivot_wider(names_from = class, values_from = n, values_fill = 0L)

wanted_cols <- c("stratum", "ADD", "REMOVE", "NONCI")
for (cc in setdiff(wanted_cols, names(summary_stratum_class))) {
  summary_stratum_class[[cc]] <- 0L
}

summary_stratum_class <- summary_stratum_class %>%
  dplyr::select(dplyr::all_of(wanted_cols)) %>%
  dplyr::mutate(Total = REMOVE + ADD + NONCI) %>%
  dplyr::arrange(stratum) %>%
  # split "D1_C2" into "D" and "C"
  tidyr::separate(stratum, into = c("D", "C"), sep = "_", remove = FALSE)

# Add human–readable Description for each stratum
summary_stratum_class_full <- summary_stratum_class %>%
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
  ) %>%
  dplyr::select(
    stratum, Description, ADD, REMOVE, NONCI, Total
  )

# Add TOTAL row (with Description)
summary_stratum_class_full <- dplyr::bind_rows(
  summary_stratum_class_full,
  dplyr::summarise(
    summary_stratum_class_full,
    stratum     = "TOTAL",
    Description = "All strata combined",
    ADD         = sum(ADD,     na.rm = TRUE),
    REMOVE      = sum(REMOVE,  na.rm = TRUE),
    NONCI       = sum(NONCI,   na.rm = TRUE),
    Total       = sum(Total,   na.rm = TRUE)
  )
)

# -------------------------------------------------------------------
# 4) Validation metrics using ONLY consens
# -------------------------------------------------------------------

read_validation_sheet <- function(path, sheet_name) {
  
  df <- tryCatch(
    readxl::read_xlsx(
      path,
      sheet = sheet_name,
      skip  = 1,              # first row after the group header
      .name_repair = "minimal"
    ),
    error = function(e) tibble::tibble()
  )
  
  if (!nrow(df)) return(tibble::tibble())
  
  nm  <- trimws(names(df))
  bad <- which(is.na(nm) | nm == "")
  if (length(bad)) nm[bad] <- paste0("X", bad)
  names(df) <- nm
  
  nm  <- names(df)
  dup <- duplicated(nm)
  if (any(dup)) df <- df[, !dup, drop = FALSE]
  
  if ("tract_id" %in% names(df)) {
    df <- df %>% dplyr::filter(!is.na(tract_id))
  }
  
  maybe_num <- function(x) suppressWarnings(as.numeric(x))
  
  if (!"class" %in% names(df)) df$class <- sheet_name
  
  for (cc in c("bl_fin", "fu_fin")) {
    if (!cc %in% names(df)) df[[cc]] <- NA
  }
  
  df %>%
    dplyr::mutate(
      class  = as.character(class),
      bl_fin = maybe_num(bl_fin),
      fu_fin = maybe_num(fu_fin)
    )
  
}

add_df   <- read_validation_sheet(FILE, "ADD")
rem_df   <- read_validation_sheet(FILE, "REMOVE")
nonci_df <- read_validation_sheet(FILE, "NONCI")

all_df <- dplyr::bind_rows(add_df, rem_df, nonci_df)

# ---  build ground truth: ONLY consens --------------------------

all_df <- all_df %>%
  dplyr::mutate(
    baseline_truth = bl_fin,
    followup_truth = fu_fin,
    real_change = dplyr::case_when(
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
  dplyr::filter(usable, real_change != "UNKNOWN")



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

t_class <- tibble::tibble(
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

