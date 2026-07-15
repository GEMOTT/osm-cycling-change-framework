# ================================================================
# 06c_sampling_extension.R
# Add 4 extra tracts per stratum, preserving the original 6
# ================================================================

set.seed(4321)

old_tracts <- sampled_tracts |>
  sf::st_drop_geometry() |>
  dplyr::mutate(CUSEC = as.character(CUSEC)) |>
  dplyr::select(CUSEC, stratum_id)

extra_tracts <- barcelona_tracts |>
  dplyr::mutate(CUSEC = as.character(CUSEC)) |>
  dplyr::anti_join(old_tracts, by = "CUSEC") |>
  dplyr::group_by(stratum_id) |>
  dplyr::slice_sample(n = 4) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    stratum = stratum_id,
    tract_id = CUSEC
  )

cat("\nExtra tracts per stratum:\n")
print(extra_tracts |> sf::st_drop_geometry() |> dplyr::count(stratum_id))

tracts <- sf::st_transform(extra_tracts, crs_work)
tracts$stratum <- droplevels(as.factor(tracts$stratum))

PERTRACT_ADD    <- 2
PERTRACT_REM    <- 2
PERTRACT_NONCYC <- 1
FORCE_QUOTA     <- FALSE
MIN_LEN_M       <- 15

noncycle23 <- sf::st_transform(general1523_n, crs_work)

added_by_tr   <- sample_lines_by_tract(added_eval,   tracts, PERTRACT_ADD,    replace = FORCE_QUOTA, min_len = MIN_LEN_M)
removed_by_tr <- sample_lines_by_tract(removed_eval, tracts, PERTRACT_REM,    replace = FORCE_QUOTA, min_len = MIN_LEN_M)
general_by_tr <- sample_lines_by_tract(noncycle23,   tracts, PERTRACT_NONCYC, replace = FORCE_QUOTA, min_len = MIN_LEN_M)

added_pts   <- points_on_lines(added_by_tr)   |> dplyr::mutate(class = "ADD")
removed_pts <- points_on_lines(removed_by_tr) |> dplyr::mutate(class = "REMOVE")
noncyc_pts  <- points_on_lines(general_by_tr) |> dplyr::mutate(class = "NONCYC")

added_pts   <- keep_in(added_pts, tracts)
removed_pts <- keep_in(removed_pts, tracts)
noncyc_pts  <- keep_in(noncyc_pts, tracts)

cat("\nExtension counts:\n")
print(rbind(
  ADD    = c(lines = nrow(added_by_tr),   pts = nrow(added_pts)),
  REMOVE = c(lines = nrow(removed_by_tr), pts = nrow(removed_pts)),
  NONCYC = c(lines = nrow(general_by_tr), pts = nrow(noncyc_pts))
))

city_tag_old <- city_tag
city_tag <- paste0(city_tag_old, "_extension")

source(here::here("R/07_export_excel.R"))

city_tag <- city_tag_old