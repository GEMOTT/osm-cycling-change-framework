
city_tag <- "barcelona"
ver15    <- "15"
ver23    <- "23"
crs_work <- 25831
tol_m    <- 10
min_len  <- 10

dir_city <- "data/processed"
proc_dir <- "data/processed"
if (!dir.exists(proc_dir)) dir.create(proc_dir, recursive = TRUE)

gpkg15 <- file.path(dir_city, paste0(city_tag, "_", ver15, "_lines.gpkg"))
gpkg23 <- file.path(dir_city, paste0(city_tag, "_", ver23, "_lines.gpkg"))
lyr15  <- paste0(city_tag, "_", ver15, "_lines")
lyr23  <- paste0(city_tag, "_", ver23, "_lines")
stopifnot(file.exists(gpkg15), file.exists(gpkg23))

l15 <- sf::st_read(gpkg15, layer = lyr15, quiet = TRUE)
l23 <- sf::st_read(gpkg23, layer = lyr23, quiet = TRUE)

rds_cyc15 <- file.path(proc_dir, sprintf("%s_%s_cyc_n.rds", city_tag, ver15))
rds_cyc23 <- file.path(proc_dir, sprintf("%s_%s_cyc_n.rds", city_tag, ver23))

cyc23_n <- .cache(
  rds_cyc23,
  build = function() l23 |>
    pick_cycle_strict() |>
    sf::st_transform(crs_work) |>
    normalize_lines_safe(),
  inputs = gpkg23
)

cyc15_n <- .cache(
  rds_cyc15,
  build = function() l15 |>
    pick_cycle_strict() |>
    sf::st_transform(crs_work) |>
    normalize_lines_safe(),
  inputs = gpkg15
)

# --- Length helper (measure in metres CRS) -----------------------------------
# len_km <- function(x, crs_m = 25831) {
#   if (!inherits(x, "sf") || !nrow(x)) return(0)
#   x_m <- sf::st_transform(x, crs_m)
#   round(sum(as.numeric(sf::st_length(x_m)), na.rm = TRUE) / 1000, 1)
# }
get_chr <- function(x, nm) if (nm %in% names(x)) as.character(x[[nm]]) else rep(NA_character_, nrow(x))

# We'll work on the 2023 CI network you already built
ci <- cyc23_n
stopifnot(inherits(ci, "sf"))

# --- Extract tags on ci -------------------------------------------------------
highway       <- get_chr(ci, "highway")
bicycle       <- get_chr(ci, "bicycle")
bicycle_road  <- get_chr(ci, "bicycle_road")
motor_vehicle <- get_chr(ci, "motor_vehicle")

# --- On-road lane/track flags from any cycleway* column -----------------------
lane_cols <- names(ci)[grepl("^cycleway", names(ci), ignore.case = TRUE)]
lane_vals <- c("lane","track","opposite_lane","opposite_track","separate")

has_lane <- rep(FALSE, nrow(ci))
if (length(lane_cols)) {
  for (col in lane_cols) {
    v <- get_chr(ci, col)
    has_lane <- has_lane | (!is.na(v) & v %in% lane_vals)
  }
}

# --- Category masks (shared paths and local/shared bikeways already excluded upstream) ---
is_cycleway          <- !is.na(highway) & highway == "cycleway"
is_bicycle_road      <- !is.na(bicycle_road) & bicycle_road == "yes"
is_bike_only_service <- (!is.na(highway) & highway %in% c("service","unclassified")) &
  (!is.na(bicycle) & bicycle %in% c("yes","designated")) &
  (!is.na(motor_vehicle) & motor_vehicle == "no")

# --- Make categories mutually exclusive via priority -------------------------
priority <- list(
  cycleway          = is_cycleway,
  onroad_lanes      = has_lane,
  bicycle_road      = is_bicycle_road,
  bike_only_service = is_bike_only_service
)

assigned <- rep(NA_character_, nrow(ci))
for (nm in names(priority)) {
  take <- is.na(assigned) & priority[[nm]]
  assigned[take] <- nm
}

len_km_cat <- function(mask) if (any(mask, na.rm = TRUE)) len_km(ci[which(mask), ]) else 0

# --- Build the length table ---------------------------------------------------
len_summary <- tibble::tibble(
  category = c(
    "Dedicated cycleways (highway=cycleway)",
    "Painted/protected on-road lanes (cycleway* = lane/track/opposite_*)",
    "Signed bicycle streets (bicycle_road=yes)",
    "Bike-only service/unclassified (motor_vehicle=no)"
  ),
  km = c(
    len_km_cat(assigned == "cycleway"),
    len_km_cat(assigned == "onroad_lanes"),
    len_km_cat(assigned == "bicycle_road"),
    len_km_cat(assigned == "bike_only_service")
  )
)

len_summary <- dplyr::bind_rows(
  len_summary,
  tibble::tibble(
    category = "Total visible cycling infrastructure",
    km = sum(len_summary$km, na.rm = TRUE)
  )
)

print(len_summary, n = nrow(len_summary))