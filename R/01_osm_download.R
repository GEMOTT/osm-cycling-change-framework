
suppressPackageStartupMessages({
  library(sf); library(osmextract); library(osmdata); library(dplyr)
})

# -------------------- PARAMETERS ---------------------------------------------
city_tag <- "barcelona"
ver15    <- "15"
ver23    <- "23"
ver_code_15 <- "160101"
ver_code_23 <- "240101"
FORCE_DOWNLOAD <- FALSE
FORCE_PERIM    <- FALSE

# -------------------- PATHS --------------------------------------------------
dir_city <- "data/processed"
if (!dir.exists(dir_city)) dir.create(dir_city, recursive = TRUE)

gpkg15 <- file.path(dir_city, paste0(city_tag, "_", ver15, "_lines.gpkg"))
gpkg23 <- file.path(dir_city, paste0(city_tag, "_", ver23, "_lines.gpkg"))
lyr15  <- paste0(city_tag, "_", ver15, "_lines")
lyr23  <- paste0(city_tag, "_", ver23, "_lines")

perim_file <- file.path(dir_city, paste0(city_tag, "_perimeter.gpkg"))
perim_lyr  <- "barcelona_perimeter"

# -------------------- HELPERS -------------------------------------------------
gpkg_has_layer <- function(path, layer){
  if (!file.exists(path)) return(FALSE)
  lyr_ok <- tryCatch(layer %in% sf::st_layers(path)$name, error = function(e) FALSE)
  if (!lyr_ok) return(FALSE)
  n <- tryCatch(nrow(sf::st_read(path, layer = layer, quiet = TRUE)), error = function(e) 0)
  n > 0
}

read_or_build_perimeter <- function(force = FALSE){
  if (!force && gpkg_has_layer(perim_file, perim_lyr)) {
    message("↪ Using cached perimeter: ", basename(perim_file))
    return(st_read(perim_file, layer = perim_lyr, quiet = TRUE) |> st_transform(4326))
  }
  message("→ Building perimeter for Barcelona …")
  bb <- osmdata::getbb("Barcelona, Spain")
  od <- osmdata::opq(bb) |>
    add_osm_feature("boundary","administrative") |>
    add_osm_feature("admin_level","8") |>
    add_osm_feature("name","Barcelona") |>
    osmdata::osmdata_sf()
  perim <- od$osm_multipolygons
  if (is.null(perim) || nrow(perim) == 0) perim <- od$osm_polygons
  if ("wikidata" %in% names(perim) && any(perim$wikidata == "Q1492"))
    perim <- perim[perim$wikidata == "Q1492", ] else perim <- perim[which.max(st_area(perim)), ]
  
  # --- CHANGE 1: dissolve perimeter for clean clipping ---
  perim <- perim |>
    st_make_valid() |>
    st_transform(25831) |>
    st_union() |>
    st_cast("MULTIPOLYGON") |>
    st_transform(4326)
  
  st_write(perim, perim_file, layer = perim_lyr, driver = "GPKG", append = FALSE, quiet = TRUE)
  message("✓ Saved perimeter: ", basename(perim_file))
  perim
}

fetch_crop_write <- function(version_code, perimeter, out_gpkg, out_layer, force = FALSE){
  if (!force && gpkg_has_layer(out_gpkg, out_layer)) {
    message("↪ Using cached: ", basename(out_gpkg)); return(invisible(out_gpkg))
  }
  message("→ Downloading Spain lines @ ", version_code, " …")
  ln <- oe_get(
    place   = "spain",
    version = version_code,
    layer   = "lines",
    boundary = st_bbox(perimeter),
    boundary_type = "clipsrc",
    extra_tags = c(
      "cycleway","cycleway:left","cycleway:right","cycleway:both",
      "bicycle","bicycle_road","oneway:bicycle","segregated"
    ),
    quiet = FALSE
  )
  
  # keep lines only
  is_line <- st_geometry_type(ln) %in% c("LINESTRING","MULTILINESTRING")
  ln <- ln[is_line, ]
  stopifnot(nrow(ln) > 0)
  
  # --- CHANGE 2: single clean clip using dissolved perimeter ---
  ln <- st_intersection(st_make_valid(ln), st_make_valid(perimeter))
  
  message("→ Writing ", basename(out_gpkg), " (", nrow(ln), " features) …")
  st_write(ln, out_gpkg, layer = out_layer, driver = "GPKG", append = FALSE, quiet = TRUE)
  invisible(out_gpkg)
}

# -------------------- RUN -----------------------------------------------------
city_perimeter <- read_or_build_perimeter(force = FORCE_PERIM)

invisible(fetch_crop_write(ver_code_15, city_perimeter, gpkg15, lyr15, force = FORCE_DOWNLOAD))
invisible(fetch_crop_write(ver_code_23, city_perimeter, gpkg23, lyr23, force = FORCE_DOWNLOAD))

message("\nStatus:\n",
        if (gpkg_has_layer(gpkg15, lyr15)) "✓ " else "✗ ", basename(gpkg15), " [", lyr15, "]\n",
        if (gpkg_has_layer(gpkg23, lyr23)) "✓ " else "✗ ", basename(gpkg23), " [", lyr23, "]")