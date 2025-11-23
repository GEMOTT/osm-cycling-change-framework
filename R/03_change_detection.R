# union -> buffer is faster than buffer -> union
rds_buf15 <- file.path(proc_dir, sprintf("%s_%s_buf_tol%sm.rds", city_tag, ver15, tol_m))
rds_buf23 <- file.path(proc_dir, sprintf("%s_%s_buf_tol%sm.rds", city_tag, ver23, tol_m))

buf15 <- .cache(
  rds_buf15,
  build  = function() sf::st_buffer(sf::st_union(sf::st_geometry(cyc15_n)), tol_m),
  inputs = rds_cyc15
)
buf23 <- .cache(
  rds_buf23,
  build  = function() sf::st_buffer(sf::st_union(sf::st_geometry(cyc23_n)), tol_m),
  inputs = rds_cyc23
)

process_difference <- function(diff_geom, crs){
  if (length(diff_geom) == 0) return(sf::st_sf(geometry = sf::st_sfc(crs = crs)))
  g <- suppressWarnings(sf::st_collection_extract(diff_geom, "LINESTRING"))
  g <- suppressWarnings(sf::st_cast(g, "LINESTRING"))
  out <- sf::st_sf(geometry = g, crs = crs)
  out[as.numeric(sf::st_length(out)) > 0, , drop = FALSE]
}

rds_added   <- file.path(proc_dir, sprintf("%s_added_tol%sm_min%sm.rds",   city_tag, tol_m, min_len))
rds_removed <- file.path(proc_dir, sprintf("%s_removed_tol%sm_min%sm.rds", city_tag, tol_m, min_len))

added <- .cache(
  rds_added,
  build  = function(){
    diff <- sf::st_difference(sf::st_union(sf::st_geometry(cyc23_n)), buf15)
    process_difference(diff, sf::st_crs(cyc23_n)) |> len_ok(min_len)
  },
  inputs = c(rds_cyc23, rds_buf15)
)
removed <- .cache(
  rds_removed,
  build  = function(){
    diff <- sf::st_difference(sf::st_union(sf::st_geometry(cyc15_n)), buf23)
    process_difference(diff, sf::st_crs(cyc15_n)) |> len_ok(min_len)
  },
  inputs = c(rds_cyc15, rds_buf23)
)

message("CI nets — 2015 segs: ", nrow(cyc15_n),
        " | 2023 segs: ", nrow(cyc23_n),
        " | Added segs: ", nrow(added),
        " | Removed segs: ", nrow(removed))


# Flag as REALIGN if an ADD and a REMOVE sit within d metres of each other
# d must be a bit larger than your diff buffer tol_m (e.g. tol_m=10 -> d=15)
tag_realign_between_add_rem <- function(a, b, d = 15) {
  a_m <- sf::st_transform(a, 3857)
  b_m <- sf::st_transform(b, 3857)
  lengths(sf::st_is_within_distance(a_m, b_m, dist = d)) > 0
}

# After you build `added` and `removed`
removed$REALIGN <- tag_realign_between_add_rem(removed, added, d = 15)
added$REALIGN   <- tag_realign_between_add_rem(added,   removed, d = 15)

# Evaluation pools exclude REALIGN
removed_eval <- subset(removed, !REALIGN)
added_eval   <- subset(added,   !REALIGN)

table(removed$REALIGN); table(added$REALIGN)

# Rename datasets
removed <- removed_eval 
added <- added_eval  
