
rds_tracts_proc  <- file.path(proc_dir, "barcelona_tracts_proc_25831.rds")

barcelona_tracts <- .cache(
  rds_tracts_proc,
  build = function(){
    
    # ---- load raw inputs ----
    tracts_geo <- readRDS("data/geo/BCN_seccion_censal_2015.rds")
    tracts_pop <- readRDS("data/pop/Population_Census_tract_2015_2022.rds")
    
    # Ensure expected ids exist
    stopifnot("CUSEC" %in% names(tracts_geo), all(c("GEOID","Year","Population") %in% names(tracts_pop)))
    
    # ---- coerce types + keep only needed years ----
    tracts_pop <- dplyr::mutate(tracts_pop, Year = as.character(Year))
    keep_years <- c("2015", "2022")
    tracts_pop <- dplyr::filter(tracts_pop, Year %in% keep_years)
    
    # ---- wide pop table ----
    tracts_pop_wide <- tidyr::pivot_wider(
      tracts_pop, names_from = Year, values_from = Population, names_prefix = "pop_"
    )
    
    # ---- join + geometry ----
    x <- dplyr::left_join(tracts_geo, tracts_pop_wide, by = c("CUSEC" = "GEOID")) |>
      dplyr::select(CUSEC, dplyr::starts_with("pop_"), geometry = dplyr::last_col())
    
    # ---- project once (UTM31N) ----
    x <- sf::st_transform(x, 25831)
    
    # ---- area + density (NA-safe) ----
    area_km2 <- as.numeric(sf::st_area(x)) / 1e6
    x <- dplyr::mutate(
      x,
      area_km2  = area_km2,
      dens_2015 = dplyr::if_else(area_km2 > 0, pop_2015 / area_km2, NA_real_),
      dens_2022 = dplyr::if_else(area_km2 > 0, pop_2022 / area_km2, NA_real_)
    )
    
    # ---- distance to Plaça Catalunya (planar) ----
    pc_pt <- sf::st_sfc(sf::st_point(c(431870, 4581450)), crs = 25831)  # already in same CRS
    ctr   <- sf::st_point_on_surface(sf::st_geometry(x))
    x$dist_centre_km <- as.numeric(sf::st_distance(ctr, pc_pt)) / 1000
    
    # optional snapshot
    if (!file.exists(gpkg_tracts_proc)) {
      sf::st_write(x, gpkg_tracts_proc, layer = "tracts", quiet = TRUE, append = FALSE)
    }
    x
  },
  inputs = c("data/geo/BCN_seccion_censal_2015.rds",
             "data/pop/Population_Census_tract_2015_2022.rds")
)

# 11-tracts-stratify

barcelona_tracts <- barcelona_tracts |>
  mutate(
    dens_stratum = ntile(dens_2022, 3),
    cent_stratum = ntile(-dist_centre_km, 3),
    stratum_id = paste0("D", dens_stratum, "_C", cent_stratum)
  )

set.seed(123)
per_stratum <- 6  # try 3–6 depending on effort

sampled_tracts <- barcelona_tracts |> 
  group_by(stratum_id) |> 
  sample_n(size = min(per_stratum, n())) |> 
  ungroup() |>
  mutate(stratum = stratum_id)   # ← ADD THIS LINE