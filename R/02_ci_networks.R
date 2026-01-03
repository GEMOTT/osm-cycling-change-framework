# ================================================================
# 02_ci_networks.R
# Build cleaned cycling-infrastructure (CI) line networks for baseline and follow-up.
#
# Inputs:
#   gpkg15, gpkg23, lyr15, lyr23      # OSM line layers from 01 (GeoPackages + layer names)
#   proc_dir, city_tag, ver15, ver23  # for deterministic output names
#   crs_work                          # projected CRS used for metric operations
#   CI tag rules (utils_ci)           # functions/logic defining what counts as CI
#   prep_lines(), snap_like(), etc.   # geometry hygiene helpers (if used)
#   .cache()                          # caching helper (if enabled)
#
# Outputs (in memory):
#   cyc15_n, cyc23_n                  # cleaned CI networks (sf)
#
# Outputs (cached RDS in proc_dir, if enabled):
#   {city_tag}_{ver15}_cyc_n.rds
#   {city_tag}_{ver23}_cyc_n.rds
# ================================================================

# Reads the raw OSM lines (outputs from Script 01)
l15 <- sf::st_read(gpkg15, layer = lyr15, quiet = TRUE)
l23 <- sf::st_read(gpkg23, layer = lyr23, quiet = TRUE)

# Defines cache paths for the cleaned cycling networks
rds_cyc15 <- file.path(proc_dir, sprintf("%s_%s_cyc_n.rds", city_tag, ver15))
rds_cyc23 <- file.path(proc_dir, sprintf("%s_%s_cyc_n.rds", city_tag, ver23))

# Builds the cleaned cycling infrastructure network (with caching)
cyc23_n <- .cache(
  rds_cyc23,
  build = function() {
    core <- l23 |>
      pick_cycle_infra() |>
      sf::st_transform(crs_work) |>
      normalize_lines_safe()
    
    core_ll  <- sf::st_transform(core, 4326)
    core_ndc <- drop_onroad_near_cycleway(core_ll, tol_m = 15, prop_in_buf = 0.5, min_in_buf_m = 20)
    
    # return in crs_work if the rest of your validation expects metric CRS
    sf::st_transform(core_ndc, crs_work)
  },
  inputs = gpkg23
)

cyc15_n <- .cache(
  rds_cyc15,
  build = function() {
    core <- l15 |>
      pick_cycle_infra() |>
      sf::st_transform(crs_work) |>
      normalize_lines_safe()
    
    core_ll  <- sf::st_transform(core, 4326)
    core_ndc <- drop_onroad_near_cycleway(core_ll, tol_m = 15, prop_in_buf = 0.5, min_in_buf_m = 20)
    
    sf::st_transform(core_ndc, crs_work)
  },
  inputs = gpkg15
)
