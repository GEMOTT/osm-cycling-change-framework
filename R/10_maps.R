# ================================================================
# 10_maps.R
# Produce maps of networks, changes, strata and sampled points for the paper.
#
# Inputs:  perimeters/tracts/networks/samples, CRS settings
# Outputs: map figures (and optional interactive maps)
# ================================================================

# ---- 0) Housekeeping + consistent change layers -----------------------------

fs::dir_create("../figs")
fs::dir_create("../supplements")

# Use evaluation pool for maps (fallback to added/removed for backwards compatibility)
added_map <- if (exists("added_eval") && inherits(added_eval, "sf")) added_eval else
  if (exists("added") && inherits(added, "sf")) added else NULL

removed_map <- if (exists("removed_eval") && inherits(removed_eval, "sf")) removed_eval else
  if (exists("removed") && inherits(removed, "sf")) removed else NULL


# Helpers

as_wgs_lines <- function(x){
  if (!inherits(x, "sf") || !nrow(x)) return(NULL)
  x <- sf::st_make_valid(x)
  keep <- sf::st_geometry_type(x) %in% c("LINESTRING","MULTILINESTRING","GEOMETRYCOLLECTION")
  x <- x[keep, , drop = FALSE]
  if (!nrow(x)) return(NULL)
  x <- suppressWarnings(sf::st_collection_extract(x, "LINESTRING", warn = FALSE))
  x <- suppressWarnings(sf::st_cast(x, "LINESTRING"))
  x <- x[!sf::st_is_empty(sf::st_geometry(x)), , drop = FALSE]
  sf::st_transform(x, crs_wgs)
}

get_boundary_wgs <- function() {
  b <- NULL
  
  if (exists("city_perimeter") && inherits(city_perimeter, "sf") && nrow(city_perimeter)) {
    b <- city_perimeter
  } else if (exists("tracts") && inherits(tracts, "sf") && nrow(tracts)) {
    b <- tracts
  } else if (exists("barcelona_tracts") && inherits(barcelona_tracts, "sf") && nrow(barcelona_tracts)) {
    b <- barcelona_tracts
  } else {
    return(NULL)
  }
  
  b <- sf::st_make_valid(b)
  
  gt <- unique(as.character(sf::st_geometry_type(b)))
  
  # Case 1: polygon input (what we want)
  if (any(gt %in% c("POLYGON", "MULTIPOLYGON"))) {
    poly <- b |>
      sf::st_collection_extract("POLYGON", warn = FALSE) |>
      sf::st_union()
    
    out <- sf::st_boundary(poly)
    out <- sf::st_as_sf(sf::st_sfc(out, crs = sf::st_crs(b)))
    out <- suppressWarnings(sf::st_collection_extract(out, "LINESTRING", warn = FALSE))
    out <- suppressWarnings(sf::st_cast(out, "LINESTRING"))
    
    out <- out[!sf::st_is_empty(sf::st_geometry(out)), , drop = FALSE]
    return(sf::st_transform(out, crs_wgs))
  }
  
  # Case 2: line input (polygonise first, then outline)
  if (any(gt %in% c("LINESTRING", "MULTILINESTRING"))) {
    ln <- b |>
      sf::st_collection_extract("LINESTRING", warn = FALSE) |>
      sf::st_union() |>
      suppressWarnings(sf::st_line_merge())
    
    pg <- suppressWarnings(sf::st_polygonize(ln))
    if (is.null(pg) || length(pg) == 0) return(NULL)
    
    poly <- sf::st_union(pg)
    out  <- sf::st_boundary(poly)
    
    out <- sf::st_as_sf(sf::st_sfc(out, crs = sf::st_crs(b)))
    out <- suppressWarnings(sf::st_collection_extract(out, "LINESTRING", warn = FALSE))
    out <- suppressWarnings(sf::st_cast(out, "LINESTRING"))
    
    out <- out[!sf::st_is_empty(sf::st_geometry(out)), , drop = FALSE]
    return(sf::st_transform(out, crs_wgs))
  }
  
  NULL
}



# ---- 1) Bivariate tract stratification (static) -----------------------------

# barcelona_tracts must already exist with dist_centre_km and dens_2022
barcelona_tracts <- barcelona_tracts |>
  dplyr::mutate(centrality_flipped = -dist_centre_km)

bb_bivar <- bi_class(
  barcelona_tracts,
  x     = dens_2022,
  y     = centrality_flipped,
  style = "quantile",
  dim   = 3
)

# bounding box for zoom
bb <- sf::st_bbox(barcelona_tracts)

bivar_map <- ggplot() +
  geom_sf(
    data        = bb_bivar,
    aes(fill    = bi_class),
    colour      = "white",
    linewidth   = 0.1,
    show.legend = FALSE
  ) +
  bi_scale_fill(pal = "DkBlue2", dim = 3) +
  geom_sf(
    data     = sampled_tracts,
    fill     = NA,
    colour   = "black",
    linewidth = 0.5
  ) +
  bi_theme() +
  coord_sf(
    xlim   = c(bb["xmin"], bb["xmax"]),
    ylim   = c(bb["ymin"], bb["ymax"]),
    expand = FALSE
  ) +
  theme(
    plot.title = element_text(size = 12, hjust = 0.5)
  )

bivar_legend <- bi_legend(
  pal  = "DkBlue2",
  dim  = 3,
  xlab = "Higher density",
  ylab = "More central",
  size = 9
) +
  theme(
    axis.title       = element_text(size = 14),
    axis.text        = element_blank(),
    plot.margin      = margin(5, 5, 5, 5),
    panel.background = element_blank(),
    plot.background  = element_blank()
  )

final_plot <- cowplot::ggdraw() +
  cowplot::draw_plot(bivar_map,    x = 0,    y = 0,    width = 1,    height = 1) +
  cowplot::draw_plot(bivar_legend, x = 0.73, y = 0.03, width = 0.26, height = 0.26)

ggsave(
  "../figs/stratified_sample_bivariate_map.png",
  final_plot,
  width  = 8,
  height = 8,
  dpi    = 300
)


# ---- 2) Validation points (static) ------------------------------------------

make_validation_points_static_map <- function() {
  
  # colours copied from leaflet map
  col_add_pt <- "#0072B2"  # ADD
  col_rem_pt <- "#D95F02"  # REMOVE
  col_gen_pt <- "#E6AB02"  # NONCYC
  
  # target CRS: use tracts / bivariate map CRS
  target_crs <- sf::st_crs(barcelona_tracts)
  
  # bind all validation points into one object
  pts_list <- list()
  
  if (exists("added_pts") && inherits(added_pts, "sf") && nrow(added_pts)) {
    pts_list$ADD <- added_pts |>
      sf::st_transform(target_crs) |>
      dplyr::mutate(type = "ADD")
  }
  
  if (exists("removed_pts") && inherits(removed_pts, "sf") && nrow(removed_pts)) {
    pts_list$REMOVE <- removed_pts |>
      sf::st_transform(target_crs) |>
      dplyr::mutate(type = "REMOVE")
  }
  
  if (exists("noncyc_pts") && inherits(noncyc_pts, "sf") && nrow(noncyc_pts)) {
    pts_list$NONCYC <- noncyc_pts |>
      sf::st_transform(target_crs) |>
      dplyr::mutate(type = "NONCYC")
  }
  
  pts_all <- dplyr::bind_rows(pts_list)
  
  # bbox centred on points, with padding
  bb_pts <- sf::st_bbox(pts_all)
  pad_factor <- 0.05
  
  x_range <- as.numeric(bb_pts["xmax"] - bb_pts["xmin"])
  y_range <- as.numeric(bb_pts["ymax"] - bb_pts["ymin"])
  
  x_pad <- pad_factor * x_range
  y_pad <- pad_factor * y_range
  
  xlim <- c(bb_pts["xmin"] - x_pad, bb_pts["xmax"] + x_pad)
  ylim <- c(bb_pts["ymin"] - y_pad, bb_pts["ymax"] + y_pad)
  
  # optional: non-CI network for context (reproject to target CRS)
  noncyc_net <- NULL
  if (exists("noncyc1523") && inherits(noncyc1523, "sf") && nrow(noncyc1523)) {
    noncyc_net <- sf::st_transform(noncyc1523, target_crs)
  }
  
  gg <- ggplot() +
    geom_sf(
      data      = sf::st_transform(barcelona_tracts, target_crs),
      fill      = "grey95",
      colour    = "white",
      linewidth = 0.1
    ) +
    { if (!is.null(noncyc_net))
      geom_sf(data = noncyc_net, colour = "grey80", linewidth = 0.1)
      else NULL } +
    { if (exists("sampled_tracts") && inherits(sampled_tracts, "sf") && nrow(sampled_tracts))
      geom_sf(
        data = sf::st_transform(sampled_tracts, target_crs),
        fill = NA, colour = "black", linewidth = 0.4
      )
      else NULL } +
    geom_sf(
      data   = pts_all,
      aes(colour = type),
      size   = 2.7,
      stroke = 0.4
    ) +
    coord_sf(
      xlim   = xlim,
      ylim   = ylim,
      expand = FALSE,
      crs    = target_crs
    ) +
    scale_colour_manual(
      name   = NULL,
      values = c("ADD" = col_add_pt, "REMOVE" = col_rem_pt, "NONCYC" = col_gen_pt),
      breaks = c("ADD", "REMOVE", "NONCYC"),
      labels = c("ADD", "REMOVE", "NON-CI")
    ) +
    guides(colour = guide_legend(override.aes = list(size = 4, stroke = 0.6))) +
    theme_void() +
    theme(
      legend.position      = c(0.98, 0.02),
      legend.justification = c("right", "bottom"),
      legend.title         = element_text(size = 14),
      legend.text          = element_text(size = 13),
      legend.key.size      = grid::unit(0.8, "cm"),
      plot.margin          = margin(5, 5, 5, 5)
    )
  
  gg
}

validation_points_map <- make_validation_points_static_map()

ggsave(
  "../figs/validation_points_map.png",
  validation_points_map,
  width  = 8,
  height = 8,
  dpi    = 300
)


# ---- 3) OSM infra change (static) -------------------------------------------

# colours: harmonised with validation points map
col_2015    <- "#4A4A4A"
col_added   <- "#0072B2"
col_removed <- "#D95F02"

alpha_2015    <- 0.8
alpha_added   <- 1
alpha_removed <- 1

# 1. Prep layers with safety checks
# Using exists() and is.null() checks to ensure sf objects are valid
bnd_wgs   <- if (exists("get_boundary_wgs")) get_boundary_wgs() else NULL
cyc15_wgs <- if (exists("cyc15_n")) as_wgs_lines(cyc15_n) else NULL

# Check if map objects exist and are valid sf objects before processing
added_wgs <- if (exists("added_map") && !is.null(added_map) && inherits(added_map, "sf") && nrow(added_map) > 0) {
  as_wgs_lines(added_map)
} else { NULL }

removed_wgs <- if (exists("removed_map") && !is.null(removed_map) && inherits(removed_map, "sf") && nrow(removed_map) > 0) {
  as_wgs_lines(removed_map)
} else { NULL }

# 2. Coordinate Reference System (CRS) Selection
# Prioritize network layers, fallback to background tracts
bg_crs <- if (!is.null(cyc15_wgs)) {
  sf::st_crs(cyc15_wgs)
} else if (!is.null(added_wgs)) {
  sf::st_crs(added_wgs)
} else if (!is.null(bnd_wgs)) {
  sf::st_crs(bnd_wgs)
} else {
  sf::st_crs(4326) # Default to WGS84 if all else fails
}

bcn_bg <- barcelona_tracts |> 
  sf::st_transform(bg_crs)

# 3. Robust Bounding Box Calculation
get_bbox_safe <- function(obj) {
  if (!is.null(obj) && inherits(obj, "sf") && nrow(obj) > 0) sf::st_bbox(obj) else NULL
}

# Collect all available bboxes
bboxes <- list(
  get_bbox_safe(bnd_wgs),
  get_bbox_safe(cyc15_wgs),
  get_bbox_safe(added_wgs),
  get_bbox_safe(removed_wgs)
)
bboxes <- Filter(Negate(is.null), bboxes)

if (length(bboxes) > 0) {
  # Merge multiple bboxes into one global extent
  bb <- c(
    xmin = min(sapply(bboxes, function(x) x["xmin"])),
    ymin = min(sapply(bboxes, function(x) x["ymin"])),
    xmax = max(sapply(bboxes, function(x) x["xmax"])),
    ymax = max(sapply(bboxes, function(x) x["ymax"]))
  )
} else {
  # Default Barcelona extents if no data is found
  bb <- c(xmin = 2.05, ymin = 41.30, xmax = 2.25, ymax = 41.45)
}

# 4. Visualization
p_change <- ggplot() +
  geom_sf(
    data      = bcn_bg,
    fill      = "grey96",
    colour    = "white",
    linewidth = 0.1
  ) +
  # Conditional Layers using list() syntax for cleaner ggplot flow
  list(
    if (!is.null(cyc15_wgs)) geom_sf(data = cyc15_wgs, aes(colour = "Baseline (2015)"), 
                                     alpha = alpha_2015, linewidth = 0.2),
    if (!is.null(removed_wgs)) geom_sf(data = removed_wgs, aes(colour = "Removed (2015–2023)"), 
                                       alpha = alpha_removed, linewidth = 0.4),
    if (!is.null(added_wgs)) geom_sf(data = added_wgs, aes(colour = "Added (2015–2023)"), 
                                     alpha = alpha_added, linewidth = 0.4)
  ) +
  coord_sf(
    xlim   = c(bb["xmin"], bb["xmax"]),
    ylim   = c(bb["ymin"], bb["ymax"]),
    expand = FALSE
  ) +
  scale_colour_manual(
    name = NULL,
    values = c(
      "Baseline (2015)"      = col_2015,
      "Added (2015–2023)"    = col_added,
      "Removed (2015–2023)" = col_removed
    ),
    # Ensure legend order is logical
    breaks = c("Baseline (2015)", "Added (2015–2023)", "Removed (2015–2023)")
  ) +
  theme_void() +
  theme(
    legend.position   = "bottom",
    legend.text       = element_text(size = 11),
    legend.key.size   = grid::unit(0.6, "cm"),
    plot.margin       = margin(10, 10, 10, 10),
    plot.background   = element_rect(fill = "white", colour = NA),
    legend.background = element_rect(fill = "white", colour = NA)
  )

# 5. Save
ggsave(
  filename = "../figs/infra_change_map.png",
  plot     = p_change,
  width    = 9,
  height   = 9,
  dpi      = 300
)


# ---- 4) Validation points (interactive) -------------------------------------

make_validation_points_interactive_map <- function() {
  
  # helper to prep points: WGS84 + lon/lat + popup
  prep_pts <- function(x) {
    if (!inherits(x, "sf") || !nrow(x)) return(NULL)
    w  <- sf::st_transform(x, crs_wgs)
    xy <- sf::st_coordinates(w)
    good <- is.finite(xy[, 1]) & is.finite(xy[, 2])
    if (!any(good)) return(NULL)
    
    w  <- w[good, , drop = FALSE]
    xy <- xy[good, , drop = FALSE]
    w$lon <- xy[, 1]
    w$lat <- xy[, 2]
    
    gsv_url <- sprintf(
      "https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=%.6f,%.6f",
      w$lat, w$lon
    )
    
    make_html <- function(i) htmltools::HTML(paste0(
      "<b>", if ("class" %in% names(w)) w$class[i] else "Point", "</b>",
      if ("id" %in% names(w))       paste0("<br/>ID: ",      w$id[i])       else "",
      if ("tract_id" %in% names(w)) paste0("<br/>tract: ",   w$tract_id[i]) else "",
      if ("stratum"  %in% names(w)) paste0("<br/>stratum: ", w$stratum[i])  else "",
      "<br/><a href='", gsv_url[i],
      "' target='_blank' rel='noopener noreferrer'>Open GSV</a>"
    ))
    
    w$popup_html <- lapply(seq_len(nrow(w)), make_html)
    w
  }
  
  # points (tolerate missing objects)
  add_wgs <- if (exists("added_pts"))   prep_pts(added_pts)   else NULL
  rem_wgs <- if (exists("removed_pts")) prep_pts(removed_pts) else NULL
  gen_wgs <- if (exists("noncyc_pts"))   prep_pts(noncyc_pts)   else NULL
  
  bnd_wgs <- get_boundary_wgs()
  
  # non-CI network
  stopifnot(exists("noncyc1523"), inherits(noncyc1523, "sf"))
  gnet_wgs <- noncyc1523 |>
    sf::st_make_valid() |>
    sf::st_transform(crs_wgs)
  
  keep <- sf::st_geometry_type(gnet_wgs, by_geometry = TRUE) %in%
    c("LINESTRING", "MULTILINESTRING", "GEOMETRYCOLLECTION")
  gnet_wgs <- gnet_wgs[keep, , drop = FALSE]
  
  if (nrow(gnet_wgs)) {
    gnet_wgs <- suppressWarnings(sf::st_collection_extract(gnet_wgs, "LINESTRING", warn = FALSE))
    gnet_wgs <- suppressWarnings(sf::st_cast(gnet_wgs, "LINESTRING"))
    gnet_wgs <- gnet_wgs[!sf::st_is_empty(sf::st_geometry(gnet_wgs)), , drop = FALSE]
  }
  
  # bounds
  get_bbox <- function(obj) {
    if (inherits(obj, "sf") && nrow(obj)) sf::st_bbox(sf::st_transform(obj, 4326)) else NULL
  }
  
  bb <- NULL
  if (!is.null(bnd_wgs) && nrow(bnd_wgs)) {
    bb <- get_bbox(bnd_wgs)
  } else if (exists("city_perimeter") && inherits(city_perimeter, "sf") && nrow(city_perimeter)) {
    bb <- get_bbox(city_perimeter)
  } else {
    bbs <- list()
    if (!is.null(add_wgs)  && nrow(add_wgs))  bbs <- c(bbs, list(sf::st_bbox(add_wgs)))
    if (!is.null(rem_wgs)  && nrow(rem_wgs))  bbs <- c(bbs, list(sf::st_bbox(rem_wgs)))
    if (!is.null(gen_wgs)  && nrow(gen_wgs))  bbs <- c(bbs, list(sf::st_bbox(gen_wgs)))
    if (inherits(gnet_wgs, "sf") && nrow(gnet_wgs)) bbs <- c(bbs, list(sf::st_bbox(gnet_wgs)))
    if (!length(bbs) && exists("tracts") && inherits(tracts, "sf") && nrow(tracts)) {
      bbs <- list(get_bbox(tracts))
    }
    if (length(bbs)) {
      mins <- do.call(pmin, lapply(bbs, function(b) c(b$xmin, b$ymin)))
      maxs <- do.call(pmax, lapply(bbs, function(b) c(b$xmax, b$ymax)))
      bb <- structure(
        list(xmin = mins[1], ymin = mins[2], xmax = maxs[1], ymax = maxs[2]),
        class = "bbox"
      )
    } else {
      bb <- c(xmin = 2.05, ymin = 41.30, xmax = 2.25, ymax = 41.45)
    }
  }
  bounds <- as.numeric(unname(c(bb["xmin"], bb["ymin"], bb["xmax"], bb["ymax"])))
  
  # colours – harmonised with static validation points map
  col_add_pt <- "#0072B2"
  col_rem_pt <- "#D95F02"
  col_gen_pt <- "#E6AB02"
  stroke     <- "#666666"
  
  tract_stroke <- "#000000"
  tract_fill   <- "#FFFFFF"
  col_noncyc    <- "#A6761D"
  
  # base map and panes
  m <- leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE)) %>%
    leaflet::addProviderTiles("CartoDB.Positron", group = "Positron") %>%
    leaflet::addMapPane("tracts",    zIndex = 410) %>%
    leaflet::addMapPane("nets",      zIndex = 420) %>%
    leaflet::addMapPane("boundary",  zIndex = 430) %>%
    leaflet::addMapPane("points",    zIndex = 440) %>%
    leaflet::addMapPane("labels",    zIndex = 450) %>%
    leaflet::addMapPane("id_labels", zIndex = 460)
  
  # boundary
  if (!is.null(bnd_wgs) && nrow(bnd_wgs)) {
    m <- m %>% leaflet::addPolylines(
      data    = bnd_wgs,
      group   = "Barcelona boundary",
      color   = "#111827",
      weight  = 1,
      opacity = 0.95,
      options = leaflet::pathOptions(pane = "boundary")
    )
  }
  
  # tracts and labels
  if (exists("tracts") && inherits(tracts, "sf") && nrow(tracts)) {
    m <- m %>% leaflet::addPolygons(
      data         = sf::st_transform(tracts, crs_wgs),
      group        = "Tracts",
      color        = tract_stroke,
      weight       = 1,
      opacity      = 0.7,
      fillColor    = tract_fill,
      fillOpacity  = 0.05,
      smoothFactor = 0.5,
      options      = leaflet::pathOptions(pane = "tracts"),
      highlightOptions = leaflet::highlightOptions(
        weight = 2, color = "#111827",
        fillOpacity = 0.1, bringToFront = FALSE
      ),
      label = ~as.character(tract_id),
      labelOptions = leaflet::labelOptions(pane = "labels")
    )
    
    tract_centres <- sf::st_point_on_surface(sf::st_transform(tracts, sf::st_crs(tracts))) |>
      sf::st_transform(4326)
    
    m <- m %>%
      leaflet::addCircleMarkers(
        data        = tract_centres,
        group       = "Area labels",
        radius      = 0.1,
        stroke      = FALSE,
        fillOpacity = 0,
        label       = ~as.character(tract_id),
        options     = leaflet::pathOptions(pane = "labels"),
        labelOptions = leaflet::labelOptions(
          noHide    = TRUE,
          direction = "center",
          style = list(
            "background"     = "transparent",
            "border"         = "none",
            "box-shadow"     = "none",
            "padding"        = "0px",
            "color"          = "rgba(0,0,0,0.25)",
            "text-shadow"    = "none",
            "pointer-events" = "none"
          )
        )
      )
  }
  
  # non-CI network
  if (inherits(gnet_wgs, "sf") && nrow(gnet_wgs)) {
    m <- m %>% leaflet::addPolylines(
      data    = gnet_wgs,
      group   = "General (non-CI) 2023",
      weight  = 1,
      color   = col_noncyc,
      opacity = 1,
      options = leaflet::pathOptions(pane = "nets")
    )
  }
  
  # optional CI networks
  if (exists("cyc15_n") && inherits(cyc15_n, "sf") && nrow(cyc15_n)) {
    m <- m %>% leaflet::addPolylines(
      data    = sf::st_transform(cyc15_n, crs_wgs),
      group   = "2015 CI",
      weight  = 2,
      color   = "#666666",
      opacity = 0.7,
      options = leaflet::pathOptions(pane = "nets")
    )
  }
  
  # Removed net (use consistent removed_map)
  if (!is.null(removed_map) && inherits(removed_map, "sf") && nrow(removed_map)) {
    m <- m %>% leaflet::addPolylines(
        data    = sf::st_transform(removed_map, crs_wgs),
        group   = "Removed (15→23)",
        weight  = 2.0,
        color   = "#D95F02",
        opacity = 1,
        options = leaflet::pathOptions(pane = "nets")
      )
  }
  
  # Added net (use consistent added_map)
  if (!is.null(added_map) && inherits(added_map, "sf") && nrow(added_map)) {
    m <- m %>% leaflet::addPolylines(
      data    = sf::st_transform(added_map, crs_wgs),
      group   = "Added (15→23)",
      weight  = 2,
      color   = "#0072B2",
      opacity = 0.95,
      options = leaflet::pathOptions(pane = "nets")
    )
  }
  
  if (exists("cyc23_n") && inherits(cyc23_n, "sf") && nrow(cyc23_n)) {
    m <- m %>% leaflet::addPolylines(
      data    = sf::st_transform(cyc23_n, crs_wgs),
      group   = "2023 CI",
      weight  = 2,
      color   = "#1B9E77",
      opacity = 0.6,
      options = leaflet::pathOptions(pane = "nets")
    )
  }
  
  # points
  if (!is.null(add_wgs) && nrow(add_wgs) > 0) {
    m <- m %>% leaflet::addCircleMarkers(
      data        = add_wgs,
      lng         = ~lon,
      lat         = ~lat,
      group       = "ADD pts",
      radius      = 4,
      weight      = 1,
      color       = stroke,
      fillColor   = col_add_pt,
      fillOpacity = 0.95,
      popup       = add_wgs$popup_html,
      options     = leaflet::pathOptions(pane = "points")
    )
  }
  
  if (!is.null(rem_wgs) && nrow(rem_wgs) > 0) {
    m <- m %>% leaflet::addCircleMarkers(
      data        = rem_wgs,
      lng         = ~lon,
      lat         = ~lat,
      group       = "REMOVE pts",
      radius      = 4,
      weight      = 1,
      color       = stroke,
      fillColor   = col_rem_pt,
      fillOpacity = 0.95,
      popup       = rem_wgs$popup_html,
      options     = leaflet::pathOptions(pane = "points")
    )
  }
  
  if (!is.null(gen_wgs) && nrow(gen_wgs) > 0) {
    m <- m %>% leaflet::addCircleMarkers(
      data        = gen_wgs,
      lng         = ~lon,
      lat         = ~lat,
      group       = "NONCYC pts",
      radius      = 4,
      weight      = 1,
      color       = stroke,
      fillColor   = col_gen_pt,
      fillOpacity = 0.95,
      popup       = gen_wgs$popup_html,
      options     = leaflet::pathOptions(pane = "points")
    )
  }
  
  # ID labels (hidden by default, toggled via layer control)
  add_id_layer <- function(map_obj, dat, group_name, col) {
    if (!is.null(dat) && nrow(dat) > 0 && "id" %in% names(dat)) {
      map_obj %>% leaflet::addLabelOnlyMarkers(
        data  = dat,
        lng   = ~lon,
        lat   = ~lat,
        group = group_name,
        label = ~as.character(id),
        labelOptions = leaflet::labelOptions(
          noHide = TRUE,
          direction = "top",
          offset = c(0, -10),
          textOnly = TRUE,
          style = list(
            "color"       = col,
            "font-size"   = "10px",
            "font-weight" = "bold",
            "text-shadow" =
              "1px 1px 2px white, -1px -1px 2px white, 1px -1px 2px white, -1px 1px 2px white"
          )
        ),
        options = leaflet::pathOptions(pane = "id_labels")
      )
    } else {
      map_obj
    }
  }
  
  m <- m |>
    add_id_layer(add_wgs, "ADD IDs",    "#0072B2") |>
    add_id_layer(rem_wgs, "REMOVE IDs", "#D95F02") |>
    add_id_layer(gen_wgs, "NONCYC IDs",  "#E6AB02")
  
  # controls
  m <- m %>%
    leaflet::addLayersControl(
      baseGroups = c("Positron"),
      overlayGroups = c(
        "Barcelona boundary", "Tracts", "Area labels",
        "2015 CI", "Added (15→23)", "Removed (15→23)", "2023 CI",
        "General (non-CI) 2023",
        "ADD pts", "REMOVE pts", "NONCYC pts",
        "ADD IDs", "REMOVE IDs", "NONCYC IDs"
      ),
      options = leaflet::layersControlOptions(collapsed = TRUE)
    ) %>%
    leaflet::hideGroup(c(
      "2015 CI", "Area labels", "Added (15→23)", "Removed (15→23)", "2023 CI",
      "General (non-CI) 2023",
      "ADD IDs", "REMOVE IDs", "NONCYC IDs"
    )) %>%
    leaflet::fitBounds(bounds[1], bounds[2], bounds[3], bounds[4])
  
  # force popup links to open in a new tab
  m <- htmlwidgets::onRender(m, "
function(el, x){
  this.on('popupopen', function(e){
    var links = e.popup.getElement().querySelectorAll('a');
    links.forEach(function(a){
      a.setAttribute('target','_blank');
      a.setAttribute('rel','noopener noreferrer');
    });
  });
}
")
  
  # legend
  legend_html <- "
<div style='background:white; padding:8px; border-radius:4px;
            box-shadow:0 0 4px rgba(0,0,0,0.25); font-size:11px;'>
  <b>Validation points</b><br>
  <div style='display:flex; align-items:center; margin-top:4px;'>
    <div style='width:10px; height:10px; border-radius:50%;
                border:1px solid #666666; background:#0072B2;
                margin-right:6px;'></div>
    ADD
  </div>
  <div style='display:flex; align-items:center; margin-top:4px;'>
    <div style='width:10px; height:10px; border-radius:50%;
                border:1px solid #666666; background:#D95F02;
                margin-right:6px;'></div>
    REMOVE
  </div>
  <div style='display:flex; align-items:center; margin-top:4px;'>
    <div style='width:10px; height:10px; border-radius:50%;
                border:1px solid #666666; background:#E6AB02;
                margin-right:6px;'></div>
    NONCYC
  </div>
</div>
"
  
  m <- m %>%
    leaflet::addControl(
      html     = legend_html,
      position = "bottomright"
    )
  
  m
}


# ---- 5) Infra change (interactive) ------------------------------------------

make_infra_change_interactive_map <- function() {
  
  col_2015    <- "#4A4A4A"
  col_added   <- "#0072B2"
  col_removed <- "#D95F02"
  col_2023    <- "#1B9E77"
  col_noncyc   <- "#A6761D"
  
  alpha_2015  <- 0.65
  alpha_added <- 0.95
  alpha_2023  <- 0.60
  alpha_noncyc <- 0.40
  
  # prep layers (use consistent map layers with fallback)
  bnd_wgs     <- get_boundary_wgs()
  cyc15_wgs   <- if (exists("cyc15_n")) as_wgs_lines(cyc15_n) else NULL
  added_wgs   <- if (!is.null(added_map)   && inherits(added_map, "sf")   && nrow(added_map))   as_wgs_lines(added_map)   else NULL
  removed_wgs <- if (!is.null(removed_map) && inherits(removed_map, "sf") && nrow(removed_map)) as_wgs_lines(removed_map) else NULL
  cyc23_wgs   <- if (exists("cyc23_n")) as_wgs_lines(cyc23_n) else NULL
  noncyc_wgs <- if (exists("noncyc1523_n") && inherits(noncyc1523_n, "sf") && nrow(noncyc1523_n)) {
    as_wgs_lines(noncyc1523_n)
  } else if (exists("noncyc1523") && inherits(noncyc1523, "sf") && nrow(noncyc1523)) {
    as_wgs_lines(noncyc1523)
  } else {
    NULL
  }
  
  
  # bounds
  get_bbox <- function(obj) {
    if (!is.null(obj) && inherits(obj, "sf") && nrow(obj)) sf::st_bbox(obj) else NULL
  }
  
  bb <- if (!is.null(bnd_wgs) && nrow(bnd_wgs)) {
    get_bbox(bnd_wgs)
  } else {
    cands <- Filter(
      Negate(is.null),
      lapply(list(cyc15_wgs, added_wgs, removed_wgs, cyc23_wgs, noncyc_wgs), get_bbox)
    )
    if (length(cands)) {
      mins <- do.call(pmin, lapply(cands, function(b) c(b["xmin"], b["ymin"])))
      maxs <- do.call(pmax, lapply(cands, function(b) c(b["xmax"], b["ymax"])))
      c(
        xmin = as.numeric(mins[1]),
        ymin = as.numeric(mins[2]),
        xmax = as.numeric(maxs[1]),
        ymax = as.numeric(maxs[2])
      )
    } else {
      c(xmin = 2.05, ymin = 41.30, xmax = 2.25, ymax = 41.45)
    }
  }
  
  bounds <- as.numeric(bb[c("xmin", "ymin", "xmax", "ymax")])
  
  # base map
  m <- leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE)) %>%
    leaflet::addProviderTiles("CartoDB.Positron", group = "Positron") %>%
    leaflet::addMapPane("nets",     zIndex = 420) %>%
    leaflet::addMapPane("boundary", zIndex = 430)
  
  # boundary
  if (!is.null(bnd_wgs) && nrow(bnd_wgs)) {
    m <- m %>% leaflet::addPolylines(
      data    = bnd_wgs,
      group   = "Barcelona boundary",
      color   = "#111827",
      weight  = 1,
      opacity = 0.95,
      options = leaflet::pathOptions(pane = "boundary")
    )
  }
  
  # networks
  if (!is.null(cyc15_wgs)) {
    m <- m %>% leaflet::addPolylines(
      data    = cyc15_wgs,
      group   = "2015 CI",
      weight  = 2,
      color   = col_2015,
      opacity = alpha_2015,
      options = leaflet::pathOptions(pane = "nets")
    )
  }
  
  if (!is.null(added_wgs)) {
    m <- m %>% leaflet::addPolylines(
      data    = added_wgs,
      group   = "Added (15→23)",
      weight  = 2,
      color   = col_added,
      opacity = alpha_added,
      options = leaflet::pathOptions(pane = "nets")
    )
  }
  
  if (!is.null(removed_wgs)) {
    m <- m %>% leaflet::addPolylines(
      data    = removed_wgs,
      group   = "Removed (15→23)",
      weight  = 2,
      color   = col_removed,
      opacity = 0.9,
      options = leaflet::pathOptions(pane = "nets")
    )
  }
  
  if (!is.null(cyc23_wgs)) {
    m <- m %>% leaflet::addPolylines(
      data    = cyc23_wgs,
      group   = "2023 CI",
      weight  = 2,
      color   = col_2023,
      opacity = alpha_2023,
      options = leaflet::pathOptions(pane = "nets")
    )
  }
  
  if (!is.null(noncyc_wgs)) {
    m <- m %>% leaflet::addPolylines(
      data         = noncyc_wgs,
      group        = "General (non-CI) 2023",
      weight       = 1,
      color        = col_noncyc,
      opacity      = alpha_noncyc,
      options      = leaflet::pathOptions(pane = "nets"),
      smoothFactor = 0.5
    )
  }
  
  m <- m %>%
    leaflet::addLayersControl(
      baseGroups    = c("Positron"),
      overlayGroups = c(
        "Barcelona boundary", "2015 CI", "Added (15→23)",
        "Removed (15→23)", "2023 CI", "General (non-CI) 2023"
      ),
      options = leaflet::layersControlOptions(collapsed = TRUE)
    ) %>%
    leaflet::hideGroup(c("2023 CI", "General (non-CI) 2023")) %>%
    leaflet::fitBounds(bounds[1], bounds[2], bounds[3], bounds[4])
  
  legend_html <- "
<div style='background:white; padding:8px; border-radius:4px;
            box-shadow:0 0 4px rgba(0,0,0,0.2); font-size:11px;'>
  <b>Layers</b><br>

  <div style='display:flex; align-items:center; margin-top:4px;'>
    <div style='width:24px; height:0; border-top:3px solid #4A4A4A; margin-right:6px;'></div>
    2015 CI
  </div>

  <div style='display:flex; align-items:center; margin-top:4px;'>
    <div style='width:24px; height:0; border-top:3px solid #0072B2; margin-right:6px;'></div>
    Added (15–23)
  </div>

  <div style='display:flex; align-items:center; margin-top:4px;'>
    <div style='width:24px; height:0; border-top:3px solid #D95F02; margin-right:6px;'></div>
    Removed (15–23)
  </div>

</div>
"
  
  m <- m %>%
    leaflet::addControl(
      html     = legend_html,
      position = "bottomright"
    )
  
  m
}


# ---- 6) Export interactive maps as HTML supplements -------------------------

# 1) Validation points interactive map
val_map_widget <- make_validation_points_interactive_map()

htmlwidgets::saveWidget(
  widget        = val_map_widget,
  file          = "../supplements/S2_validation_points_map.html",
  selfcontained = TRUE
)

# 2) Infrastructure change interactive map
infra_map_widget <- make_infra_change_interactive_map()

htmlwidgets::saveWidget(
  widget        = infra_map_widget,
  file          = "../supplements/S2_infra_change_map.html",
  selfcontained = TRUE
)
