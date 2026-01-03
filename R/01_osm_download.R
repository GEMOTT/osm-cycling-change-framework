# ================================================================
# 01_osm_download.R
# Download OSM "lines" for two snapshots and clip to the city perimeter.
#
# Inputs:  city_tag/city_name, ver_code_15/ver_code_23, proc_dir, FORCE_* flags
# Outputs: proc_dir/<city>_<ver>_lines.gpkg (x2), proc_dir/<city>_perimeter.gpkg
# ================================================================

# -------------------- PATHS --------------------------------------------------
# Files (on disk):
#   gpkg15/gpkg23: GeoPackages that store clipped OSM "lines" for each snapshot
#   perim_file:    GeoPackage that stores the city perimeter polygon
#
# Layers (inside each GeoPackage):
#   lyr15/lyr23: layer names inside gpkg15/gpkg23
#   perim_lyr:   layer name inside perim_file

gpkg15 <- file.path(proc_dir, paste0(city_tag, "_", ver15, "_lines.gpkg"))
gpkg23 <- file.path(proc_dir, paste0(city_tag, "_", ver23, "_lines.gpkg"))

lyr15  <- paste0(city_tag, "_", ver15, "_lines")
lyr23  <- paste0(city_tag, "_", ver23, "_lines")

perim_file <- file.path(proc_dir, paste0(city_tag, "_perimeter.gpkg"))
perim_lyr  <- paste0(city_tag, "_perimeter")

# -------------------- HELPERS ------------------------------------------------

read_or_build_perimeter <- function(force = FALSE) {
  if (!force && file.exists(perim_file)) {
    message("↪ Using cached perimeter: ", basename(perim_file))
    return(
      st_read(perim_file, layer = perim_lyr, quiet = TRUE) |>
        st_transform(crs_wgs)
    )
  }
  
  message("→ Building perimeter for ", city_name, " …")
  
  # Get OSM boundary for the city
  bb <- osmdata::getbb(paste0(city_name, ", Spain"))
  od <- osmdata::opq(bb) |>
    add_osm_feature("boundary",    "administrative") |>
    add_osm_feature("admin_level", "8") |>
    add_osm_feature("name",        city_name) |>
    osmdata::osmdata_sf()
  
  perim <- od$osm_multipolygons
  if (is.null(perim) || nrow(perim) == 0) perim <- od$osm_polygons
  
  # Prefer the wikidata code for Barcelona, otherwise take largest polygon
  if ("wikidata" %in% names(perim) && any(perim$wikidata == "Q1492")) {
    perim <- perim[perim$wikidata == "Q1492", ]
  } else {
    perim <- perim[which.max(st_area(st_transform(perim, crs_work))), ]
  }
  
  # Dissolve perimeter for clean clipping
  perim <- perim |>
    st_make_valid() |>
    st_transform(crs_work) |>
    st_union() |>
    st_cast("MULTIPOLYGON") |>
    st_transform(crs_wgs)
  
  st_write(
    perim, perim_file,
    layer  = perim_lyr,
    driver = "GPKG",
    append = FALSE,
    quiet  = TRUE
  )
  
  message("✓ Saved perimeter: ", basename(perim_file))
  perim
}

fetch_crop_write <- function(version_code,
                             perimeter,
                             out_gpkg,
                             out_layer,
                             force = FALSE) {
  if (!force && file.exists(out_gpkg)) {
    message("↪ Using cached: ", basename(out_gpkg))
    return(invisible(out_gpkg))
  }
  
  message("→ Downloading Spain lines @ ", version_code, " …")
  
  ln <- oe_get(
    place         = "spain",
    version       = version_code,
    layer         = "lines",
    boundary      = st_bbox(perimeter),
    boundary_type = "clipsrc",
    extra_tags    = c(
      "highway", "cycleway","cycleway:left","cycleway:right","cycleway:both",
      "bicycle","bicycle_road","oneway:bicycle","segregated"
    ),
    quiet         = FALSE
  )
  
  # Guard: oe_get() should return sf (avoid st_geometry_type() crashing)
  if (!inherits(ln, "sf")) {
    stop(sprintf("oe_get() did not return an sf object. ver=%s", version_code))
  }
  
  # Keep lines only
  is_line <- st_geometry_type(ln) %in% c("LINESTRING","MULTILINESTRING")
  ln <- ln[is_line, ]
  
  # Clear failure message (and correct context)
  if (nrow(ln) == 0) {
    stop(sprintf(
      "OSM download/clip returned 0 features. Check: internet, perimeter bbox/CRS, snapshot code. ver=%s, gpkg=%s, layer=%s",
      version_code, out_gpkg, out_layer
    ))
  }
  
  # Clip lines using dissolved perimeter
  ln <- st_intersection(st_make_valid(ln), st_make_valid(perimeter))
  
  message("→ Writing ", basename(out_gpkg), " (", nrow(ln), " features) …")
  
  st_write(
    ln, out_gpkg,
    layer  = out_layer,
    driver = "GPKG",
    append = FALSE,
    quiet  = TRUE
  )
  
  invisible(out_gpkg)
}

# -------------------- RUN ----------------------------------------------------

city_perimeter <- read_or_build_perimeter(force = FORCE_PERIM)

invisible(fetch_crop_write(ver_code_15, city_perimeter, gpkg15, lyr15,
                           force = FORCE_DOWNLOAD))
invisible(fetch_crop_write(ver_code_23, city_perimeter, gpkg23, lyr23,
                           force = FORCE_DOWNLOAD))

message(
  "\nStatus:\n",
  if (file.exists(gpkg15)) "✓ " else "✗ ", basename(gpkg15), " [", lyr15, "]\n",
  if (file.exists(gpkg23)) "✓ " else "✗ ", basename(gpkg23), " [", lyr23, "]"
)
