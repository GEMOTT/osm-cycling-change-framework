
# 1) One robust midpoint per line
points_on_lines <- function(x){
  if (!inherits(x,"sf") || !nrow(x))
    return(sf::st_sf(id = integer(0), geometry = sf::st_sfc(crs = sf::st_crs(x))))
  g <- sf::st_geometry(x)
  crs_in <- sf::st_crs(x)
  pts <- lapply(seq_len(nrow(x)), function(i){
    gi <- g[i]; if (sf::st_is_empty(gi)) return(sf::st_point())
    gi <- sf::st_make_valid(gi)
    gi1 <- try(suppressWarnings(sf::st_line_merge(gi)), silent = TRUE)
    if (inherits(gi1, "try-error") || !inherits(gi1, "sfc_LINESTRING")) {
      parts <- try(suppressWarnings(sf::st_cast(gi, "LINESTRING")), silent = TRUE)
      if (inherits(parts, "try-error") || length(parts) == 0) return(sf::st_point())
      gi1 <- parts[which.max(as.numeric(sf::st_length(parts)))]
    }
    p <- try(sf::st_line_sample(gi1, sample = 0.5), silent = TRUE)
    if (inherits(p, "try-error") || length(p) == 0) {
      p <- try(sf::st_point_on_surface(gi1), silent = TRUE)
      if (inherits(p, "try-error")) p <- sf::st_centroid(gi1)
    }
    p <- suppressWarnings(sf::st_cast(p, "POINT"))
    if (length(p) == 0 || !inherits(p[[1]], "sfg")) p <- sf::st_point()
    p[[1]]
  })
  sf::st_as_sf(data.frame(id = seq_len(nrow(x))),
               geometry = sf::st_sfc(pts, crs = crs_in))
}

# 2) Points -> lon/lat + GSV link
to_lonlat_tbl <- function(pts_sf){
  stopifnot(inherits(pts_sf, "sf"))
  if (!nrow(pts_sf))
    return(dplyr::tibble(lon=numeric(), lat=numeric(), gsv_link=character()))
  wgs <- sf::st_transform(pts_sf, 4326)
  xy  <- sf::st_coordinates(wgs)
  out <- sf::st_drop_geometry(wgs)
  out$lon <- xy[,1]; out$lat <- xy[,2]
  out$gsv_link <- paste0("https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=",
                         out$lat, ",", out$lon)
  out
}

# 3) Columns for manual validation
add_validation_cols <- function(df){
  df$present_2015    <- NA
  df$present_2023    <- NA
  df$verifiable_2015 <- NA
  df$verifiable_2023 <- NA
  df$notes           <- NA_character_
  df
}

# 4) Bind-safe coercion
coerce_for_bind <- function(df){
  chr <- c("class","interval","gsv_link","notes","source")
  num <- c("lon","lat")
  log <- c("present_2015","present_2023","verifiable_2015","verifiable_2023")
  for (v in chr) if (v %in% names(df)) df[[v]] <- as.character(df[[v]])
  for (v in num) if (v %in% names(df)) df[[v]] <- as.numeric(df[[v]])
  for (v in log) if (v %in% names(df)) df[[v]] <- as.logical(df[[v]])
  df
}

# 5) Core sampler: **fixed cap per tract**
#    - Intersect candidate lines with each tract
#    - Drop tiny fragments
#    - Length-weighted sample up to n_per per tract
sample_lines_by_tract <- function(lines_sf, tracts_sf, n_per, replace = FALSE, min_len = 0){
  if (!inherits(lines_sf,"sf") || !nrow(lines_sf)) {
    out <- lines_sf[0, , drop = FALSE]
    out$tract_id <- character(0); out$stratum <- factor()[0]
    return(out)
  }
  L <- sf::st_transform(lines_sf, sf::st_crs(tracts_sf))
  hits  <- sf::st_intersects(tracts_sf, L)
  picks <- vector("list", nrow(tracts_sf))
  
  for (i in seq_len(nrow(tracts_sf))) {
    idx <- hits[[i]]; if (!length(idx)) next
    cand <- suppressWarnings(sf::st_intersection(L[idx, , drop = FALSE], tracts_sf[i, ]))
    cand <- suppressWarnings(sf::st_collection_extract(cand, "LINESTRING", warn = FALSE))
    cand <- cand[!sf::st_is_empty(cand), , drop = FALSE]
    if (min_len > 0)
      cand <- cand[as.numeric(sf::st_length(cand)) >= min_len, , drop = FALSE]
    if (!nrow(cand)) next
    
    # Up to n_per per **this** tract
    draw_with_replacement <- isTRUE(replace) && nrow(cand) < n_per
    k <- if (draw_with_replacement) n_per else min(n_per, nrow(cand))
    lens <- as.numeric(sf::st_length(cand)); lens[!is.finite(lens)] <- 0
    prob <- if (sum(lens) > 0) lens / sum(lens) else NULL
    
    piece <- cand[sample(seq_len(nrow(cand)), k, replace = draw_with_replacement, prob = prob), , drop = FALSE]
    piece$tract_id <- tracts_sf$tract_id[i]
    piece$stratum  <- tracts_sf$stratum[i]
    picks[[i]] <- piece
  }
  dplyr::bind_rows(picks)
}

# 15-feasibility-diagnostic

feasibility_diagnostic <- function(
    sampled_tracts,
    added,
    removed,
    nonci_lines,
    crs_work,
    PERTRACT_ADD   = 2L,
    PERTRACT_REM   = 2L,
    PERTRACT_NONCI = 1L,
    MIN_LEN_M      = 15L,
    TRACTS_PER_STRATUM = 6L
) {
  
  tracts <- sf::st_transform(sampled_tracts, crs_work)
  if (!"stratum" %in% names(tracts)) tracts$stratum <- factor("all")
  
  count_hits_strict <- function(lines, tracts_sf, min_len_m = 0L){
    if (!inherits(lines, "sf") || !nrow(lines)) return(integer(nrow(tracts_sf)))
    L <- sf::st_transform(lines, sf::st_crs(tracts_sf))
    vapply(seq_len(nrow(tracts_sf)), function(i){
      piece <- suppressWarnings(sf::st_intersection(L, tracts_sf[i, ]))
      piece <- suppressWarnings(sf::st_collection_extract(piece, "LINESTRING", warn = FALSE))
      if (!nrow(piece)) return(0L)
      if (min_len_m > 0) {
        piece <- piece[as.numeric(sf::st_length(piece)) >= min_len_m, , drop = FALSE]
      }
      nrow(piece)
    }, integer(1))
  }
  
  by_tract <- tracts |>
    dplyr::mutate(
      n_add    = count_hits_strict(added,          tracts, MIN_LEN_M),
      n_remove = count_hits_strict(removed,        tracts, MIN_LEN_M),
      n_nonci  = count_hits_strict(nonci_lines,    tracts, MIN_LEN_M)
    ) |>
    sf::st_drop_geometry()
  
  raw_sum <- function(v) sum(v, na.rm = TRUE)
  cap_sum <- function(v, cap) sum(pmin(v, cap), na.rm = TRUE)
  
  feasibility <- by_tract |>
    dplyr::group_by(stratum) |>
    dplyr::summarise(
      ADD_available            = raw_sum(n_add),
      ADD_available_capped     = cap_sum(n_add,    PERTRACT_ADD),
      REMOVE_available         = raw_sum(n_remove),
      REMOVE_available_capped  = cap_sum(n_remove, PERTRACT_REM),
      NONCI_available          = raw_sum(n_nonci),
      NONCI_available_capped   = cap_sum(n_nonci,  PERTRACT_NONCI),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      ADD_target    = TRACTS_PER_STRATUM * PERTRACT_ADD,
      REMOVE_target = TRACTS_PER_STRATUM * PERTRACT_REM,
      NONCI_target  = TRACTS_PER_STRATUM * PERTRACT_NONCI
    ) |>
    dplyr::select(
      stratum,
      ADD_target,    ADD_available,    ADD_available_capped,
      REMOVE_target, REMOVE_available, REMOVE_available_capped,
      NONCI_target,  NONCI_available,  NONCI_available_capped
    ) |>
    dplyr::arrange(stratum)
  
  totals <- feasibility |>
    dplyr::summarise(stratum = "TOTAL", dplyr::across(-stratum, ~sum(.x, na.rm = TRUE)))
  
  dplyr::bind_rows(feasibility, totals)
}
