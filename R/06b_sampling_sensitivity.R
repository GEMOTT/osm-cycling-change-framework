# ================================================================
# 06b_sampling_sensitivity.R
# Sensitivity checks for validation sampling design
# ================================================================

set.seed(123)

# ------------------------------------------------
# 1. Fresh nested samples from scratch
#    Useful for design exploration only.
#    Not equivalent to extending the current sample.
# ------------------------------------------------

tracts_ordered <- barcelona_tracts |>
  dplyr::group_by(stratum_id) |>
  dplyr::mutate(.rand = runif(dplyr::n())) |>
  dplyr::arrange(.rand, .by_group = TRUE) |>
  dplyr::ungroup()

test_fresh_sample <- function(k, n_add = 2, n_rem = 2, min_len = 15) {
  tracts_k <- tracts_ordered |>
    dplyr::group_by(stratum_id) |>
    dplyr::slice_head(n = k) |>
    dplyr::ungroup() |>
    dplyr::mutate(stratum = stratum_id) |>
    normalize_tract_id() |>
    sf::st_transform(crs_work)
  
  add_k <- sample_lines_by_tract(added_eval, tracts_k, n_add, min_len = min_len)
  rem_k <- sample_lines_by_tract(removed_eval, tracts_k, n_rem, min_len = min_len)
  
  tibble::tibble(
    design = "fresh_sample",
    per_stratum = k,
    sampled_tracts = nrow(tracts_k),
    add_sampled = nrow(add_k),
    remove_sampled = nrow(rem_k)
  )
}

sensitivity_fresh_sample <- purrr::map_dfr(
  c(2, 4, 6, 8, 10, 12, 15),
  test_fresh_sample
)

sensitivity_fresh_sample

# ------------------------------------------------
# 2. Extension of the current validated sample
#    Keeps existing sampled_tracts fixed and adds
#    extra tracts per stratum from the remaining pool.
# ------------------------------------------------

old_tract_ids <- sampled_tracts |>
  sf::st_drop_geometry() |>
  normalize_tract_id() |>
  dplyr::pull(tract_id)

remaining_tracts <- barcelona_tracts |>
  normalize_tract_id() |>
  dplyr::filter(!tract_id %in% old_tract_ids)

test_extension_sample <- function(extra_k, n_add = 2, n_rem = 2, min_len = 15) {
  set.seed(123 + extra_k)
  
  extra_tracts <- remaining_tracts |>
    dplyr::group_by(stratum_id) |>
    dplyr::slice_sample(n = extra_k) |>
    dplyr::ungroup() |>
    dplyr::mutate(stratum = stratum_id) |>
    sf::st_transform(crs_work)
  
  add_extra <- sample_lines_by_tract(added_eval, extra_tracts, n_add, min_len = min_len)
  rem_extra <- sample_lines_by_tract(removed_eval, extra_tracts, n_rem, min_len = min_len)
  
  tibble::tibble(
    design = "extension_of_current_sample",
    extra_per_stratum = extra_k,
    extra_tracts = nrow(extra_tracts),
    add_extra = nrow(add_extra),
    remove_extra = nrow(rem_extra)
  )
}

sensitivity_extension <- purrr::map_dfr(
  c(2, 4, 6, 8, 10),
  test_extension_sample
)

sensitivity_extension

# Interpretation:
# Randomly extending the current 6-tract sample yields few additional removal cases
# unless many extra tracts are added. This reflects the rarity and uneven spatial
# distribution of OSM-detected removals.

# Test increasing per-tract removal quota using original sampled tracts
test_remove_quota <- function(q, min_len = 15) {
  rem_q <- sample_lines_by_tract(
    removed_eval,
    tracts,
    n_per = q,
    min_len = min_len
  )
  
  tibble::tibble(
    per_tract_remove = q,
    remove_sampled = nrow(rem_q)
  )
}

sensitivity_remove_quota <- purrr::map_dfr(
  c(1, 2, 3, 4, 5, 6),
  test_remove_quota
)

sensitivity_remove_quota

# save
writexl::write_xlsx(
  list(
    fresh_sample = sensitivity_fresh_sample,
    extension_sample = sensitivity_extension,
    remove_quota = sensitivity_remove_quota,
    summary_notes = tibble::tibble(
      note = c(
        "Sensitivity checks for validation sampling design.",
        "Fresh samples explore alternative stratified designs from scratch.",
        "Extension samples test adding extra tracts to the current sample.",
        "Increasing the removal quota within original sampled tracts only increased removals from 5 to 6.",
        "Results suggest that removals are rare and unevenly distributed, rather than mainly limited by per-tract sampling quota."
      )
    )
  ),
  "outputs/sampling_sensitivity_checks.xlsx"
)
