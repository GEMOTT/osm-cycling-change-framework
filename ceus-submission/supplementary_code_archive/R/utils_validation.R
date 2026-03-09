# ================================================================
# utils_validation.R
# Shared helpers for sampling lines/points and validation table preparation.
#
# Inputs:  sf lines + tracts
# Outputs: helper functions (points_on_lines, to_lonlat_tbl, etc.)
# ================================================================

# Creates one stable “midpoint-like” point per line for validation
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

# Converts points to a plain table with: lon/lat + GSV link
to_lonlat_tbl <- function(pts_sf){
  stopifnot(inherits(pts_sf, "sf"))
  if (!nrow(pts_sf))
    return(dplyr::tibble(lon=numeric(), lat=numeric(), gsv_link=character()))
  wgs <- sf::st_transform(pts_sf, crs_wgs)
  xy  <- sf::st_coordinates(wgs)
  out <- sf::st_drop_geometry(wgs)
  out$lon <- xy[,1]; out$lat <- xy[,2]
  out$gsv_link <- paste0("https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=",
                         out$lat, ",", out$lon)
  out
}

# Adds blank columns that coders fill manually
add_validation_cols <- function(df){
  df$present_2015    <- NA
  df$present_2023    <- NA
  df$verifiable_2015 <- NA
  df$verifiable_2023 <- NA
  df$notes           <- NA_character_
  df
}

# Ensures types are consistent before bind_rows()
coerce_for_bind <- function(df){
  chr <- c("class","interval","gsv_link","notes","source")
  num <- c("lon","lat")
  log <- c("present_2015","present_2023","verifiable_2015","verifiable_2023")
  for (v in chr) if (v %in% names(df)) df[[v]] <- as.character(df[[v]])
  for (v in num) if (v %in% names(df)) df[[v]] <- as.numeric(df[[v]])
  for (v in log) if (v %in% names(df)) df[[v]] <- as.logical(df[[v]])
  df
}

