# ================================================================
# 06b_sampling_sensitivity.R
# Sensitivity checks for validation sampling design
# ================================================================

# Test increasing number of sampled tracts per stratum
set.seed(123)

tracts_ordered <- barcelona_tracts |>
  dplyr::group_by(stratum_id) |>
  dplyr::mutate(.rand = runif(dplyr::n())) |>
  dplyr::arrange(.rand, .by_group = TRUE) |>
  dplyr::ungroup()

test_per_stratum <- function(k, n_add = 2, n_rem = 2, min_len = 15) {
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
    per_stratum = k,
    sampled_tracts = nrow(tracts_k),
    add_sampled = nrow(add_k),
    remove_sampled = nrow(rem_k)
  )
}

purrr::map_dfr(c(2, 4, 6, 8, 10, 12, 15), test_per_stratum)


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
