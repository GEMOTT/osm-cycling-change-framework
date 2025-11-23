# Cycle infra selector (visible, bike-only infrastructure)
# It does not include both shared-use paths (bikes + pedestrians) and shared/local bikeways (bikes + cars)

pick_cycle_strict <- function(x){
  stopifnot(inherits(x, "sf"))
  if (!nrow(x)) return(x[0, ])
  
  # --- Safe getter ---
  get_chr <- function(x, nm) {
    if (nm %in% names(x)) as.character(x[[nm]]) else rep(NA_character_, nrow(x))
  }
  
  highway       <- get_chr(x, "highway")
  bicycle       <- get_chr(x, "bicycle")
  bicycle_road  <- get_chr(x, "bicycle_road")
  motor_vehicle <- get_chr(x, "motor_vehicle")
  
  # --- Cycleway columns (any prefix form) ---
  lane_cols <- names(x)[grepl("^cycleway", names(x), ignore.case = TRUE)]
  lane_vals <- c("lane", "track", "opposite_lane", "opposite_track", "separate")
  
  has_lane <- rep(FALSE, nrow(x))
  if (length(lane_cols)) {
    for (col in lane_cols) {
      v <- get_chr(x, col)
      has_lane <- has_lane | (!is.na(v) & v %in% lane_vals)
    }
  }
  
  # --- Core cycling infra types (bike-only, visible) ---
  is_cycleway <- !is.na(highway) & highway == "cycleway"
  
  # shared paths REMOVED → do not include highway=footway/path/track
  # local/shared bikeways REMOVED → do not include cycleway* = shared/designated
  
  is_bicycle_road <- !is.na(bicycle_road) & bicycle_road == "yes"
  
  is_bike_only_service <- (!is.na(highway) & highway %in% c("service","unclassified")) &
    (!is.na(bicycle) & bicycle %in% c("yes","designated")) &
    (!is.na(motor_vehicle) & motor_vehicle == "no")
  
  # --- Combine rules (no shared paths, no local/shared bikeways) ---
  keep <- is_cycleway | has_lane | is_bicycle_road | is_bike_only_service
  
  x[keep, , drop = FALSE]
}