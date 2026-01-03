# ================================================================
# 07_export_excel.R
# Export coder workbooks for manual validation (coder1 and coder2).
#
# Inputs:  samples_tbl
# Outputs: outdir/<city>_samples_2015_2023_coder1.xlsx and coder2.xlsx
# ================================================================

# --- setup -------------------------------------------------------

# which coders to prepare workbooks for
coders <- c(1, 2)

# flag to force rebuild if you really want to regenerate the Excels
rebuild_excels <- FALSE

mk_outfile <- function(city_tag, coder_id){
  file.path(
    outdir,
    paste0(city_tag, "_samples_2015_2023_coder", coder_id, ".xlsx")
  )
}

# --- validations: presence coding -------------------------------------------
PRESENCE_LIST <- c("1","0","NA")  # 1 = visible, 0 = absent, NA = not verifiable

# --- helpers -----------------------------------------------------
mk_gsv_cbll <- function(lat, lon, heading = NA_real_) {
  paste0(
    "https://www.google.com/maps?layer=c&cbll=",
    sprintf("%.6f,%.6f", lat, lon),
    ifelse(is.na(heading), "", sprintf("&cbp=12,%.0f,0,0,0", heading))
  )
}

# Ensure correct structure and order of columns, matching the template
ensure_export_cols <- function(df){
  # prefer existing link in 'gsv_link', else 'gsv_url', else create cbll
  if (!"gsv_link" %in% names(df)) {
    if ("gsv_url" %in% names(df)) df$gsv_link <- df$gsv_url else df$gsv_link <- NA_character_
  }
  need_link <- is.na(df$gsv_link) | !nzchar(df$gsv_link)
  if (any(need_link) && all(c("lat","lon") %in% names(df))) {
    df$gsv_link[need_link] <- mk_gsv_cbll(
      df$lat[need_link], df$lon[need_link],
      if ("heading" %in% names(df)) df$heading[need_link] else NA_real_
    )
  }
  
  # clean id: 1..N
  df$id <- seq_len(nrow(df))
  
  # make sure all validation columns exist
  for (nm in c(
    "pres24","mon24","pres23","mon23",
    "pres22","mon22",
    "pres16","mon16","pres15","mon15",
    "pres14","mon14",
    "notes","pres_fu","pres_bl","match"
  )) {
    if (!nm %in% names(df)) df[[nm]] <- NA
  }
  
  # clickable label col
  if (!"GSV" %in% names(df)) df$GSV <- NA_character_
  
  # normalise ids as character
  if ("tract_id" %in% names(df)) df$tract_id <- as.character(df$tract_id)
  if ("stratum"  %in% names(df)) df$stratum  <- as.character(df$stratum)
  
  # exact order in export
  wanted <- c(
    "id","class","tract_id","stratum","lon","lat","gsv_link","GSV",
    "pres24","mon24","pres23","mon23",
    "pres22","mon22",
    "pres16","mon16","pres15","mon15",
    "pres14","mon14",
    "notes","pres_fu","pres_bl","match"
  )
  for (nm in setdiff(wanted, names(df))) df[[nm]] <- NA
  df[, wanted, drop = FALSE]
}

# -------------------------------------------------------------------
# Fused presence formulas: pres_fu (follow-up) and pres_bl (baseline)
# Layout after ensure_export_cols:
#   I  pres24   J  mon24
#   K  pres23   L  mon23
#   M  pres22   N  mon22
#   O  pres16   P  mon16
#   Q  pres15   R  mon15
#   S  pres14   T  mon14
#   V  pres_fu  W  pres_bl  X  match
# -------------------------------------------------------------------
add_fused_formula_cols <- function(wb, sheet, n_rows, header_row = 2){
  if (n_rows == 0) return(invisible(NULL))
  
  r1 <- header_row + 1
  rN <- header_row + n_rows
  
  # follow-up fused:
  # 1) if pres24 and pres23 both empty:
  #       use pres22 if available, else ""
  # 2) if only one of pres24/pres23 is filled: use that
  # 3) if both filled: choose year whose month is closer to January
  tmpl_fu <- paste0(
    'IF(AND(I%1$d="",K%1$d=""),',
    'IF(M%1$d<>"",M%1$d,""),',
    'IF(AND(I%1$d<>"",K%1$d=""),I%1$d,',
    'IF(AND(I%1$d="",K%1$d<>""),K%1$d,',
    'IF(ABS(J%1$d-1)<=ABS(13-L%1$d),I%1$d,K%1$d))))'
  )
  
  # baseline fused:
  # 1) if pres16 and pres15 both empty:
  #       use pres14 if available, else ""
  # 2) if only one of pres16/pres15 is filled: use that
  # 3) if both filled: choose year whose month is closer to January
  tmpl_bl <- paste0(
    'IF(AND(O%1$d="",Q%1$d=""),',
    'IF(S%1$d<>"",S%1$d,""),',
    'IF(AND(O%1$d<>"",Q%1$d=""),O%1$d,',
    'IF(AND(O%1$d="",Q%1$d<>""),Q%1$d,',
    'IF(ABS(P%1$d-1)<=ABS(13-R%1$d),O%1$d,Q%1$d))))'
  )
  
  col_fu <- 22  # V
  col_bl <- 23  # W
  
  for (r in r1:rN) {
    f_fu <- paste0("=", sprintf(tmpl_fu, r))
    f_bl <- paste0("=", sprintf(tmpl_bl, r))
    openxlsx::writeFormula(wb, sheet, x = f_fu, startCol = col_fu, startRow = r)
    openxlsx::writeFormula(wb, sheet, x = f_bl, startCol = col_bl, startRow = r)
  }
  
  # only widths, no colours
  openxlsx::setColWidths(wb, sheet, cols = c(col_fu, col_bl), widths = 13)
}

# -------------------------------------------------------------------
# Match column in X: comparison of class vs (pres_bl, pres_fu)
# Returns TRUE/FALSE (logical), which Excel may show as TRUE/FALSE
# -------------------------------------------------------------------
add_match_col <- function(wb, sheet, n_rows, header_row = 2) {
  if (n_rows == 0) return(invisible(NULL))
  
  r1 <- header_row + 1
  rN <- header_row + n_rows
  col_match <- 24  # X
  
  # use V (pres_fu), W (pres_bl), B (class)
  tmpl_match <- paste0(
    'IF(OR(V%1$d="",W%1$d=""),"",',
    'IF(B%1$d="ADD",AND(W%1$d=0,V%1$d=1),',
    'IF(B%1$d="REMOVE",AND(W%1$d=1,V%1$d=0),',
    'IF(B%1$d="NONCI",AND(W%1$d=0,V%1$d=0),""))))'
  )
  
  for (r in r1:rN) {
    f_match <- paste0("=", sprintf(tmpl_match, r))
    openxlsx::writeFormula(wb, sheet, x = f_match, startCol = col_match, startRow = r)
  }
  
  openxlsx::setColWidths(wb, sheet, cols = col_match, widths = 13)
}

# -------------------------------------------------------------------
# Writer: make sheet look like coder template
#   - only coder-editable cols coloured:
#       * BLUE: pres24, mon24, pres23, mon23, pres16, mon16, pres15, mon15
#       * YELLOW: pres22, mon22, pres14, mon14
#       * GREEN: notes
#   - pres_fu, pres_bl, match: no colour
# -------------------------------------------------------------------
write_one <- function(wb, df, sheet, freeze_cols = 3){
  df <- ensure_export_cols(df)
  
  openxlsx::addWorksheet(
    wb, sheet, gridLines = TRUE,
    tabColour = switch(sheet, "ADD"="green","REMOVE"="red","NONCI"="orange","CI_STATIC"="blue","grey")
  )
  
  # headers at row 2, data from row 3
  openxlsx::writeData(wb, sheet, df, startRow = 2, startCol = 1,
                      colNames = TRUE, withFilter = FALSE)
  
  # clickable GSV (H column)
  if (nrow(df)) {
    openxlsx::writeFormula(
      wb, sheet,
      x = paste0('HYPERLINK("', df$gsv_link, '","Open GSV")'),
      startCol = 8,  # H
      startRow = 3
    )
  }
  
  openxlsx::setColWidths(wb, sheet, cols = 1:ncol(df), widths = 13)
  openxlsx::freezePane(wb, sheet, firstActiveRow = 3, firstActiveCol = freeze_cols + 1)
  
  # centre "Open GSV"
  style_center <- openxlsx::createStyle(halign = "center")
  openxlsx::addStyle(wb, sheet, style = style_center,
                     rows = 2:(nrow(df)+2), cols = 8, gridExpand = TRUE)
  
  # ----- row 1 group headers --------------------------------------------------
  group_style <- openxlsx::createStyle(
    fgFill = "#DCEBFA", textDecoration = "bold",
    halign = "center", valign = "center"
  )
  
  openxlsx::writeData(
    wb, sheet,
    x = matrix("", nrow = 1, ncol = ncol(df)),
    startRow = 1, startCol = 1, colNames = FALSE
  )
  
  # Follow-up block over I..N (pres24/23/22 + months)
  openxlsx::writeData(wb, sheet, x = "Follow-up", startRow = 1, startCol = 9, colNames = FALSE)
  openxlsx::mergeCells(wb, sheet, rows = 1, cols = 9:14)
  openxlsx::addStyle(wb, sheet, style = group_style,
                     rows = 1, cols = 9:14, gridExpand = TRUE)
  
  # Baseline block over O..T (pres16/15/14 + months)
  openxlsx::writeData(wb, sheet, x = "Baseline", startRow = 1, startCol = 15, colNames = FALSE)
  openxlsx::mergeCells(wb, sheet, rows = 1, cols = 15:20)
  openxlsx::addStyle(wb, sheet, style = group_style,
                     rows = 1, cols = 15:20, gridExpand = TRUE)
  
  # No special style for V..X
  
  # ----- overwrite header text to the exact names we want --------------------
  hdr <- c(
    "id","class","tract_id","stratum","lon","lat","gsv_link","GSV",
    "pres24","mon24","pres23","mon23",
    "pres22","mon22",
    "pres16","mon16","pres15","mon15",
    "pres14","mon14",
    "notes","pres_fu","pres_bl","match"
  )
  
  openxlsx::writeData(
    wb, sheet,
    x = matrix(hdr, nrow = 1),
    startRow = 2, startCol = 1, colNames = FALSE
  )
  
  # ----- header colours: ONLY coder-editable cols ----------------------------
  header_blue   <- openxlsx::createStyle(fgFill = "#DCEBFA", textDecoration = "bold")
  header_yellow <- openxlsx::createStyle(fgFill = "#FFF4C2", textDecoration = "bold")
  header_green  <- openxlsx::createStyle(fgFill = "#E4F8D2", textDecoration = "bold")
  
  # figure out positions by name (robust)
  nm <- hdr
  
  blue_cols <- which(nm %in% c(
    "pres24","mon24","pres23","mon23",
    "pres16","mon16","pres15","mon15"
  ))
  yellow_cols <- which(nm %in% c(
    "pres22","mon22","pres14","mon14"
  ))
  green_col <- which(nm == "notes")
  
  if (length(blue_cols)) {
    openxlsx::addStyle(wb, sheet, style = header_blue,
                       rows = 2, cols = blue_cols, gridExpand = TRUE)
  }
  if (length(yellow_cols)) {
    openxlsx::addStyle(wb, sheet, style = header_yellow,
                       rows = 2, cols = yellow_cols, gridExpand = TRUE)
  }
  if (length(green_col) == 1) {
    openxlsx::addStyle(wb, sheet, style = header_green,
                       rows = 2, cols = green_col, gridExpand = TRUE)
  }
  
  # ----- make data cells for coder inputs text-formatted ----------------------
  # I..T (9:20) are coder input fields
  input_cols <- 9:20
  sty_text <- openxlsx::createStyle(numFmt = "@")
  if (nrow(df) > 0) {
    openxlsx::addStyle(
      wb, sheet, style = sty_text,
      rows = 3:(nrow(df) + 2), cols = input_cols, gridExpand = TRUE
    )
    for (j in input_cols) {
      v <- df[[j]]
      v[!is.na(v)] <- as.character(v[!is.na(v)])
      v[is.na(v)]  <- ""
      openxlsx::writeData(wb, sheet, v,
                          startRow = 3, startCol = j, colNames = FALSE)
    }
  }
  
  # ----- fused presence + match formulas, no colour ---------------------------
  add_fused_formula_cols(wb, sheet, n_rows = nrow(df), header_row = 2)
  add_match_col(wb, sheet, n_rows = nrow(df), header_row = 2)
}




# keep one tract_id and stratum on points
add_id_if_missing <- function(p, tr){
  if (!"tract_id" %in% names(p)) {
    if (sf::st_crs(p) != sf::st_crs(tr)) p <- sf::st_transform(p, sf::st_crs(tr))
    p <- sf::st_join(p, tr["tract_id"], join = sf::st_within, left = TRUE)
  }
  p
}

canon_id_stratum <- function(p, tr){
  co <- function(df, vars){
    v <- lapply(vars, \(x) if (x %in% names(df)) as.character(df[[x]]) else NA_character_)
    z <- v[[1]]; if (length(v)>1) for (k in 2:length(v)) z <- dplyr::coalesce(z, v[[k]])
    z[trimws(z)==""] <- NA_character_; z
  }
  p$tract_id <- co(p, c("tract_id","tract_id.x","tract_id.y"))
  p$stratum  <- co(p, c("stratum","stratum.x","stratum.y","stratum_id"))
  if (any(is.na(p$stratum)) && "tract_id" %in% names(p)) {
    lk <- sf::st_drop_geometry(tr)[,c("tract_id","stratum")]
    p  <- dplyr::left_join(p, lk, by="tract_id", suffix=c("",".lkp"))
    p$stratum <- dplyr::coalesce(p$stratum, p$stratum.lkp); p$stratum.lkp <- NULL
  }
  p[c("tract_id.x","tract_id.y","stratum.x","stratum.y","stratum_id")] <- NULL
  p$stratum <- as.character(p$stratum); p$tract_id <- as.character(p$tract_id)
  p
}

# --- rebuild export tables AFTER the joins -----------------------------------
added_pts   <- canon_id_stratum(add_id_if_missing(added_pts,   tracts), tracts)
removed_pts <- canon_id_stratum(add_id_if_missing(removed_pts, tracts), tracts)
nonci_pts   <- canon_id_stratum(add_id_if_missing(nonci_pts,   tracts), tracts)

# You already have these helpers in your project:
# - to_lonlat_tbl()
# - add_validation_cols()
# - coerce_for_bind()

mk_tbl <- function(p, src, cls){
  to_lonlat_tbl(p) |>
    dplyr::mutate(interval = "2015→2023", source = src, class = cls) |>
    add_validation_cols() |>
    coerce_for_bind()
}

add_tbl <- mk_tbl(added_pts,   "ADD",    "ADD")
rem_tbl <- mk_tbl(removed_pts, "REMOVE", "REMOVE")
gen_tbl <- mk_tbl(nonci_pts,   "NONCI",  "NONCI")

# --- write workbooks: one per coder -----------------------------------------
for (cd in coders) {
  outfile <- mk_outfile(city_tag, cd)
  
  if (file.exists(outfile) && !rebuild_excels) {
    message("Validation workbook for coder ", cd, " already exists, not overwriting: ", outfile)
  } else {
    message("Creating validation workbook for coder ", cd, ": ", outfile)
    wb <- openxlsx::createWorkbook()
    
    write_one(wb, add_tbl, "ADD")
    write_one(wb, rem_tbl, "REMOVE")
    write_one(wb, gen_tbl, "NONCI")
    
    # Optional: add a tiny info sheet with coder id
    openxlsx::addWorksheet(wb, "INFO")
    openxlsx::writeData(
      wb, "INFO",
      data.frame(
        city_tag = city_tag,
        coder_id = cd
      ),
      startRow = 1, startCol = 1
    )
    
    openxlsx::saveWorkbook(wb, outfile, overwrite = TRUE)
  }
}