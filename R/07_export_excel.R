
# --- setup -------------------------------------------------------
suppressPackageStartupMessages({
  library(openxlsx); library(sf); library(dplyr)
})

outdir <- "outputs"; dir.create(outdir, FALSE, TRUE)
outfile <- file.path(
  outdir,
  paste0(city_tag, "_samples_2015_2023_", format(Sys.time(), "%Y%m%d-%H%M"), ".xlsx")
)
wb <- openxlsx::createWorkbook()

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
  
  # presence fields (include 2016 and 2022)
  for (nm in c("present_2014","present_2015","present_2016",
               "present_2022","present_2023","present_2024")) {
    if (!nm %in% names(df)) df[[nm]] <- NA
  }
  
  # clickable label column
  if (!"GSV" %in% names(df)) df$GSV <- NA_character_
  
  # normalise id fields
  if ("tract_id" %in% names(df)) df$tract_id <- as.character(df$tract_id)
  if ("stratum"  %in% names(df)) df$stratum  <- as.character(df$stratum)
  
  # FINAL ORDER (follow-up first, then baseline, then notes)
  wanted <- c(
    "id","class","tract_id","stratum","lon","lat","gsv_link","GSV",
    "present_2023","present_2024","present_2022",
    "present_2015","present_2014","present_2016",
    "notes"
  )
  for (nm in setdiff(wanted, names(df))) df[[nm]] <- NA
  df[, wanted, drop = FALSE]
}

add_fused_formula_cols <- function(wb, sheet, n_rows, header_row = 2, na_token = '"NA"'){
  hdr <- openxlsx::readWorkbook(wb, sheet = sheet, rows = header_row, colNames = FALSE)
  nm  <- as.character(hdr[1, ])
  
  required <- c("present_2023","present_2024","present_2022",
                "present_2015","present_2014","present_2016","notes")
  miss <- setdiff(required, nm)
  if (length(miss)) stop("Missing expected columns on sheet '", sheet, "': ", paste(miss, collapse = ", "))
  
  i23 <- match("present_2023", nm); i24 <- match("present_2024", nm); i22 <- match("present_2022", nm)
  i15 <- match("present_2015", nm); i14 <- match("present_2014", nm); i16 <- match("present_2016", nm)
  inotes <- match("notes", nm)
  
  # insert immediately AFTER 'notes'
  col_fu <- inotes + 1
  col_bl <- inotes + 2
  
  openxlsx::writeData(
    wb, sheet,
    x = data.frame(present_followup = NA, present_baseline = NA),
    startCol = col_fu, startRow = header_row, colNames = TRUE
  )
  
  C   <- openxlsx::int2col
  c23 <- C(i23); c24 <- C(i24); c22 <- C(i22)
  c15 <- C(i15); c14 <- C(i14); c16 <- C(i16)
  
  r1 <- header_row + 1
  rN <- header_row + n_rows
  
  if (n_rows > 0) {
    # Build the template strings ONCE, then sprintf per row
    tmpl_fu <- paste0(
      'IF(OR(%1$s%2$d=1,%1$s%2$d="1",%1$s%2$d=0,%1$s%2$d="0"),%1$s%2$d,',
      'IF(OR(%3$s%2$d=1,%3$s%2$d="1",%3$s%2$d=0,%3$s%2$d="0"),%3$s%2$d,',
      'IF(OR(%4$s%2$d=1,%4$s%2$d="1",%4$s%2$d=0,%4$s%2$d="0"),%4$s%2$d,%5$s)))'
    )
    tmpl_bl <- paste0(
      'IF(OR(%1$s%2$d=1,%1$s%2$d="1",%1$s%2$d=0,%1$s%2$d="0"),%1$s%2$d,',
      'IF(OR(%3$s%2$d=1,%3$s%2$d="1",%3$s%2$d=0,%3$s%2$d="0"),%3$s%2$d,',
      'IF(OR(%4$s%2$d=1,%4$s%2$d="1",%4$s%2$d=0,%4$s%2$d="0"),%4$s%2$d,%5$s)))'
    )
    
    for (r in r1:rN) {
      f_fu <- sprintf(tmpl_fu, c23, r, c24, c22, na_token)
      f_bl <- sprintf(tmpl_bl, c15, r, c14, c16, na_token)
      openxlsx::writeFormula(wb, sheet, x = f_fu, startCol = col_fu, startRow = r)
      openxlsx::writeFormula(wb, sheet, x = f_bl, startCol = col_bl, startRow = r)
    }
  }
  
  # header styling and widths
  sty_head <- openxlsx::createStyle(fgFill = "#E2F0D9", textDecoration = "bold")
  openxlsx::addStyle(wb, sheet, style = sty_head, rows = header_row, cols = c(col_fu, col_bl), gridExpand = TRUE)
  openxlsx::setColWidths(wb, sheet, cols = c(col_fu, col_bl), widths = 18)
}

add_match_col <- function(wb, sheet, n_rows, header_row = 2, na_token = '"NA"') {
  if (n_rows == 0) return(invisible(NULL))
  
  hdr <- openxlsx::readWorkbook(wb, sheet = sheet, rows = header_row, colNames = FALSE)
  nm  <- as.character(hdr[1, ])
  
  i_class <- match("class", nm)
  i_fu    <- match("present_followup", nm)
  i_bl    <- match("present_baseline", nm)
  
  if (any(is.na(c(i_class, i_fu, i_bl)))) {
    stop("Missing 'class', 'present_followup' or 'present_baseline' on sheet '", sheet, "'.")
  }
  
  C       <- openxlsx::int2col
  c_class <- C(i_class)
  c_fu    <- C(i_fu)
  c_bl    <- C(i_bl)
  
  # add match column at the end
  col_match <- length(nm) + 1
  openxlsx::writeData(
    wb, sheet,
    x = data.frame(osm_gsv_match = NA),
    startCol = col_match, startRow = header_row,
    colNames = TRUE
  )
  
  r1 <- header_row + 1
  rN <- header_row + n_rows
  
  # Template (for sprintf):
  # %1$s = follow-up col, %2$s = baseline col, %3$d = row, %4$s = class col
  tmpl_match <- paste0(
    'IF(OR(%1$s%3$d="NA",%2$s%3$d="NA",%1$s%3$d="",%2$s%3$d=""),',
    na_token, ',',
    'OR(',
    'AND(%4$s%3$d="ADD",ROUND(%1$s%3$d,0)=1,ROUND(%2$s%3$d,0)=0),',
    'AND(%4$s%3$d="REMOVE",ROUND(%1$s%3$d,0)=0,ROUND(%2$s%3$d,0)=1),',
    'AND(%4$s%3$d="NONCI",ROUND(%1$s%3$d,0)=0,ROUND(%2$s%3$d,0)=0)',
    '))'
  )
  
  for (r in r1:rN) {
    f_match <- sprintf(tmpl_match, c_fu, c_bl, r, c_class)
    openxlsx::writeFormula(wb, sheet, x = f_match, startCol = col_match, startRow = r)
  }
  
  sty_head <- openxlsx::createStyle(fgFill = "#E2F0D9", textDecoration = "bold")
  openxlsx::addStyle(wb, sheet, style = sty_head, rows = header_row, cols = col_match, gridExpand = TRUE)
  openxlsx::setColWidths(wb, sheet, cols = col_match, widths = 18)
}



# writer: styles grouped headers, inputs, and adds computed finals after notes
write_one <- function(df, sheet, freeze_cols = 3){
  df <- ensure_export_cols(df)
  
  openxlsx::addWorksheet(
    wb, sheet, gridLines = TRUE,
    tabColour = switch(sheet, "ADD"="green","REMOVE"="red","NONCI"="orange","CI_STATIC"="blue","grey")
  )
  
  # Write headers at row 2 and data from row 3
  openxlsx::writeData(wb, sheet, df, startRow = 2, startCol = 1, colNames = TRUE, withFilter = FALSE)
  
  # clickable GSV (first data row is row 3)
  if (nrow(df)) {
    openxlsx::writeFormula(
      wb, sheet,
      x = paste0('HYPERLINK("', df$gsv_link, '","Open GSV")'),
      startCol = match("GSV", names(df)),
      startRow = 3
    )
  }
  
  # widths and freeze panes
  w <- rep("auto", ncol(df)); w[1] <- 12
  openxlsx::setColWidths(wb, sheet, cols = 1:ncol(df), widths = w)
  openxlsx::freezePane(wb, sheet, firstActiveRow = 3, firstActiveCol = freeze_cols + 1)
  
  # centre "Open GSV"
  gsv_col <- match("GSV", names(df))
  if (!is.na(gsv_col)) {
    openxlsx::setColWidths(wb, sheet, cols = gsv_col, widths = nchar("Open GSV") + 2)
    style_center <- openxlsx::createStyle(halign = "center")
    openxlsx::addStyle(wb, sheet, style = style_center, rows = 2:(nrow(df)+2), cols = gsv_col, gridExpand = TRUE)
  }
  
  # hide columns D–G (tract_id, stratum, lon, lat)
  openxlsx::setColWidths(wb, sheet, cols = 4:7, widths = 0)
  
  # ---- header styling for year windows --------------------------------------
  col_p14 <- match("present_2014", names(df))
  col_p15 <- match("present_2015", names(df))
  col_p16 <- match("present_2016", names(df))
  col_p22 <- match("present_2022", names(df))
  col_p23 <- match("present_2023", names(df))
  col_p24 <- match("present_2024", names(df))
  
  sty_main <- openxlsx::createStyle(fgFill = "#FFF2CC", textDecoration = "bold")
  sty_edge <- openxlsx::createStyle(fgFill = "#F2F2F2")
  
  if (!is.na(col_p15)) openxlsx::addStyle(wb, sheet, style = sty_main, rows = 2, cols = col_p15, gridExpand = TRUE)
  if (!is.na(col_p23)) openxlsx::addStyle(wb, sheet, style = sty_main, rows = 2, cols = col_p23, gridExpand = TRUE)
  if (!is.na(col_p14)) openxlsx::addStyle(wb, sheet, style = sty_edge, rows = 2, cols = col_p14, gridExpand = TRUE)
  if (!is.na(col_p16)) openxlsx::addStyle(wb, sheet, style = sty_edge, rows = 2, cols = col_p16, gridExpand = TRUE)
  if (!is.na(col_p22)) openxlsx::addStyle(wb, sheet, style = sty_edge, rows = 2, cols = col_p22, gridExpand = TRUE)
  if (!is.na(col_p24)) openxlsx::addStyle(wb, sheet, style = sty_edge, rows = 2, cols = col_p24, gridExpand = TRUE)
  
  # ---- top group header row (row 1) -----------------------------------------
  sty_group <- openxlsx::createStyle(fgFill = "#D9E1F2", textDecoration = "bold", halign = "center", valign = "center")
  
  # Follow-up group: 2023 over [present_2023, present_2024, present_2022]
  if (all(!is.na(c(col_p23, col_p24, col_p22)))) {
    openxlsx::writeData(wb, sheet, x = "2023", startRow = 1, startCol = col_p23, colNames = FALSE)
    openxlsx::mergeCells(wb, sheet, rows = 1, cols = col_p23:col_p22)
    openxlsx::addStyle(wb, sheet, style = sty_group, rows = 1, cols = col_p23:col_p22, gridExpand = TRUE)
  }
  
  # Baseline group: 2015 over [present_2015, present_2014, present_2016]
  if (all(!is.na(c(col_p15, col_p14, col_p16)))) {
    openxlsx::writeData(wb, sheet, x = "2015", startRow = 1, startCol = col_p15, colNames = FALSE)
    openxlsx::mergeCells(wb, sheet, rows = 1, cols = col_p15:col_p16)
    openxlsx::addStyle(wb, sheet, style = sty_group, rows = 1, cols = col_p15:col_p16, gridExpand = TRUE)
  }
  
  # ---- presence inputs: plain text, start empty (avoid LibreOffice 509) -----
  presence_cols <- grep("^present_(2014|2015|2016|2022|2023|2024)$", names(df))
  if (length(presence_cols)) {
    sty_text <- openxlsx::createStyle(numFmt = "@")
    openxlsx::addStyle(
      wb, sheet, style = sty_text,
      rows = 3:(nrow(df) + 2), cols = presence_cols, gridExpand = TRUE
    )
    # ensure blanks instead of NA for inputs
    for (j in presence_cols) {
      v <- df[[j]]
      v[!is.na(v)] <- as.character(v[!is.na(v)])
      v[is.na(v)]  <- ""
      openxlsx::writeData(wb, sheet, v, startRow = 3, startCol = j, colNames = FALSE)
    }
  }
  
  # ---- add the two calculated columns (after notes) --------------------------
  add_fused_formula_cols(wb, sheet, n_rows = nrow(df), header_row = 2, na_token = '"NA"')
  # ---- add OSM–GSV match flag at the end ------------------------------------
  add_match_col(wb, sheet, n_rows = nrow(df), header_row = 2, na_token = '"NA"')
  
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

# --- write workbook ----------------------------------------------------------
write_one(add_tbl, "ADD")
write_one(rem_tbl, "REMOVE")
write_one(gen_tbl, "NONCI")

openxlsx::saveWorkbook(wb, outfile, overwrite = TRUE)