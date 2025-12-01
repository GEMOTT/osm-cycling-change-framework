# 12-bivar-map-build

barcelona_tracts <- barcelona_tracts |> 
  mutate(centrality_flipped = -dist_centre_km)

bb_bivar <- bi_class(barcelona_tracts, x = dens_2022, y = centrality_flipped, style = "quantile", dim = 3)

bivar_map <- ggplot() +
  geom_sf(data = bb_bivar, aes(fill = bi_class), color = "white", size = 0.1, show.legend = FALSE) +
  bi_scale_fill(pal = "DkBlue2", dim = 3) +
  geom_sf(data = sampled_tracts, fill = NA, color = "black", linewidth = 0.5) +
  labs(title = "") +
  bi_theme() +
  theme(plot.title = element_text(size = 12, hjust = 0.5))

bivar_legend <- bi_legend(pal = "DkBlue2", dim = 3, xlab = "Higher Density", ylab = "More Central", size = 9) +
  theme(axis.title = element_text(size = 9), axis.text = element_blank(),
        plot.margin = margin(5, 5, 5, 5), panel.background = element_blank(), plot.background = element_blank())

final_plot <- ggdraw() +
  draw_plot(bivar_map, 0, 0, 1, 1) +
  draw_plot(bivar_legend, x = 0.73, y = 0.03, width = 0.26, height = 0.26)

ggsave("../figs/stratified_sample_bivariate_map.png", final_plot, width = 8, height = 8, dpi = 300)

# validation points map

make_validation_points_map <- function() {
  
  # ---- helper: prep points (WGS84 + lon/lat + popup) ------------------------
  prep_pts <- function(x){
    if (!inherits(x, "sf") || !nrow(x)) return(NULL)
    w  <- sf::st_transform(x, 4326)
    xy <- sf::st_coordinates(w)
    good <- is.finite(xy[,1]) & is.finite(xy[,2])
    if (!any(good)) return(NULL)
    w   <- w[good, , drop = FALSE]
    xy  <- xy[good, , drop = FALSE]
    w$lon <- xy[,1]; w$lat <- xy[,2]
    
    gsv_url <- sprintf(
      "https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=%.6f,%.6f",
      w$lat, w$lon
    )
    
    make_html <- function(i) htmltools::HTML(paste0(
      "<b>", if ("class" %in% names(w)) w$class[i] else "Point", "</b>",
      if ("id" %in% names(w)) paste0("<br/>ID: ", w$id[i]) else "",
      if ("tract_id" %in% names(w)) paste0("<br/>tract: ",   w$tract_id[i]) else "",
      if ("stratum"  %in% names(w)) paste0("<br/>stratum: ", w$stratum[i])  else "",
      "<br/><a href='", gsv_url[i], "' target='_blank' rel='noopener noreferrer'>Open GSV</a>"
    ))
    
    w$popup_html <- lapply(seq_len(nrow(w)), make_html)
    w
  }
  
  # ---- prepare points (tolerate missing objects) ----------------------------
  add_wgs <- if (exists("added_pts"))   prep_pts(added_pts)   else NULL
  rem_wgs <- if (exists("removed_pts")) prep_pts(removed_pts) else NULL
  gen_wgs <- if (exists("nonci_pts"))   prep_pts(nonci_pts)   else NULL
  # optional stable points (uncomment if you have them)
  # pers_wgs <- if (exists("ci_stable_pts") && inherits(ci_stable_pts,"sf") && nrow(ci_stable_pts)) prep_pts(ci_stable_pts) else NULL
  
  bnd_wgs <- get_boundary_wgs()
  
  # ---- Non-CI network: expect 'nonci1523' from earlier chunk ----------------
  stopifnot(exists("nonci1523"), inherits(nonci1523, "sf"))
  gnet_wgs <- nonci1523 |>
    sf::st_make_valid() |>
    sf::st_transform(4326)
  
  keep <- sf::st_geometry_type(gnet_wgs, by_geometry = TRUE) %in%
    c("LINESTRING","MULTILINESTRING","GEOMETRYCOLLECTION")
  gnet_wgs <- gnet_wgs[keep, , drop = FALSE]
  if (nrow(gnet_wgs)) {
    gnet_wgs <- suppressWarnings(sf::st_collection_extract(gnet_wgs, "LINESTRING", warn = FALSE))
    gnet_wgs <- suppressWarnings(sf::st_cast(gnet_wgs, "LINESTRING"))
    gnet_wgs <- gnet_wgs[!sf::st_is_empty(sf::st_geometry(gnet_wgs)), , drop = FALSE]
  }
  
  # ---- bounds (prefer boundary; otherwise union of layers) ------------------
  get_bbox <- function(obj) {
    if (inherits(obj,"sf") && nrow(obj)) sf::st_bbox(sf::st_transform(obj, 4326)) else NULL
  }
  
  bb <- NULL
  if (!is.null(bnd_wgs) && nrow(bnd_wgs)) {
    bb <- get_bbox(bnd_wgs)
  } else if (exists("city_perimeter") && inherits(city_perimeter,"sf") && nrow(city_perimeter)) {
    bb <- get_bbox(city_perimeter)
  } else {
    bbs <- list()
    if (!is.null(add_wgs)  && nrow(add_wgs))  bbs <- c(bbs, list(sf::st_bbox(add_wgs)))
    if (!is.null(rem_wgs)  && nrow(rem_wgs))  bbs <- c(bbs, list(sf::st_bbox(rem_wgs)))
    if (!is.null(gen_wgs)  && nrow(gen_wgs))  bbs <- c(bbs, list(sf::st_bbox(gen_wgs)))
    if (inherits(gnet_wgs,"sf") && nrow(gnet_wgs)) bbs <- c(bbs, list(sf::st_bbox(gnet_wgs)))
    if (!length(bbs) && exists("tracts") && inherits(tracts,"sf") && nrow(tracts)) {
      bbs <- list(get_bbox(tracts))
    }
    if (length(bbs)) {
      mins <- do.call(pmin, lapply(bbs, function(b) c(b$xmin,b$ymin)))
      maxs <- do.call(pmax, lapply(bbs, function(b) c(b$xmax,b$ymax)))
      bb <- structure(list(xmin=mins[1], ymin=mins[2], xmax=maxs[1], ymax=maxs[2]), class="bbox")
    } else {
      bb <- c(xmin = 2.05, ymin = 41.30, xmax = 2.25, ymax = 41.45)  # BCN-ish fallback
    }
  }
  bounds <- as.numeric(unname(c(bb["xmin"], bb["ymin"], bb["xmax"], bb["ymax"])))
  
  # ---- colours --------------------------------------------------------------
  col_add_pt <- "#E6AB02"  # gold
  col_rem_pt <- "#D95F02"  # orange-red
  col_gen_pt <- "#1B9E77"  # teal
  stroke     <- "#666666"
  
  tract_stroke <- "#000000"
  tract_fill   <- "#FFFFFF"
  
  col_2015_net    <- "#666666"
  col_added_net   <- "#D95F02"
  col_removedNet  <- "#FFFFFF"
  col_removedHalo <- "#000000"
  col_2023_net    <- "#1B9E77"
  col_nonci       <- "red"
  
  # ---- base map + panes (control drawing order) -----------------------------
  m <- leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE)) %>%
    leaflet::addProviderTiles("CartoDB.Positron", group = "Positron") %>%
    leaflet::addMapPane("tracts",   zIndex = 410) %>%
    leaflet::addMapPane("nets",     zIndex = 420) %>%
    leaflet::addMapPane("boundary", zIndex = 430) %>%
    leaflet::addMapPane("points",   zIndex = 440) %>%   # dots above tracks
    leaflet::addMapPane("labels",   zIndex = 450) %>%
    leaflet::addMapPane("id_labels", zIndex = 460)      # ID labels on top
  
  # ---- Barcelona boundary ----------------------------------------------------
  if (!is.null(bnd_wgs) && nrow(bnd_wgs)) {
    m <- m %>% leaflet::addPolylines(
      data    = bnd_wgs,
      group   = "Barcelona boundary",
      color   = "#111827", weight = 1, opacity = 0.95,
      options = leaflet::pathOptions(pane = "boundary")
    )
  }
  
  # ---- Tracts (polygons + labels) -------------------------------------------
  if (exists("tracts") && inherits(tracts,"sf") && nrow(tracts)) {
    m <- m %>% leaflet::addPolygons(
      data       = sf::st_transform(tracts, 4326),
      group      = "Tracts",
      color      = tract_stroke, weight = 1, opacity = 0.7,
      fillColor  = tract_fill,  fillOpacity = 0.05,
      smoothFactor = 0.5,
      options    = leaflet::pathOptions(pane = "tracts"),
      highlightOptions = leaflet::highlightOptions(
        weight = 2, color = "#111827",
        fillOpacity = 0.1, bringToFront = FALSE
      ),
      label = ~as.character(tract_id),
      labelOptions = leaflet::labelOptions(pane = "labels")
    )
    
    # Area labels (centroids)
    tract_centers <- sf::st_point_on_surface(sf::st_transform(tracts, sf::st_crs(tracts))) |>
      sf::st_transform(4326)
    m <- m %>%
      leaflet::addCircleMarkers(
        data = tract_centers, group = "Area labels",
        radius = 0.1, stroke = FALSE, fillOpacity = 0,
        label = ~as.character(tract_id),
        options = leaflet::pathOptions(pane = "labels"),
        labelOptions = leaflet::labelOptions(
          noHide = TRUE, direction = "center",
          style = list(
            "background"="transparent","border"="none","box-shadow"="none","padding"="0px",
            "color"="rgba(0,0,0,0.25)","text-shadow"="none","pointer-events"="none"
          )
        )
      )
  }
  
  # ---- Non-CI network -------------------------------------------------------
  if (inherits(gnet_wgs,"sf") && nrow(gnet_wgs)) {
    m <- m %>% leaflet::addPolylines(
      data = gnet_wgs, group = "General (non-CI) net",
      weight = 1, color = col_nonci, opacity = 1.0,
      options = leaflet::pathOptions(pane = "nets")
    )
  }
  
  # ---- Optional network context ---------------------------------------------
  if (exists("cyc15_n") && inherits(cyc15_n,"sf") && nrow(cyc15_n)) {
    m <- m %>% leaflet::addPolylines(
      data = sf::st_transform(cyc15_n, 4326), group = "2015 net",
      weight = 2, color = col_2015_net, opacity = 0.7,
      options = leaflet::pathOptions(pane = "nets")
    )
  }
  
  if (exists("removed") && inherits(removed,"sf") && nrow(removed)) {
    m <- m %>% leaflet::addPolylines(
      data = sf::st_transform(removed, 4326), group = "Removed net",
      weight = 2.6, color = col_removedHalo, opacity = 0.18,
      options = leaflet::pathOptions(pane = "nets")
    )
    m <- m %>% leaflet::addPolylines(
      data = sf::st_transform(removed, 4326), group = "Removed net",
      weight = 2.0, color = col_removedNet,  opacity = 1.0,
      options = leaflet::pathOptions(pane = "nets")
    )
  }
  
  if (exists("added") && inherits(added,"sf") && nrow(added)) {
    m <- m %>% leaflet::addPolylines(
      data = sf::st_transform(added, 4326), group = "Added net",
      weight = 2, color = col_added_net, opacity = 0.95,
      options = leaflet::pathOptions(pane = "nets")
    )
  }
  
  if (exists("cyc23_n") && inherits(cyc23_n,"sf") && nrow(cyc23_n)) {
    m <- m %>% leaflet::addPolylines(
      data = sf::st_transform(cyc23_n, 4326), group = "2023 net",
      weight = 2, color = col_2023_net, opacity = 0.6,
      options = leaflet::pathOptions(pane = "nets")
    )
  }
  
  # ---- Points (on top of tracks) --------------------------------------------
  if (!is.null(add_wgs) && nrow(add_wgs) > 0)
    m <- m %>% leaflet::addCircleMarkers(
      data = add_wgs, lng = ~lon, lat = ~lat, group = "ADD pts",
      radius = 4, weight = 1, color = stroke, fillColor = col_add_pt, fillOpacity = 0.95,
      popup = add_wgs$popup_html,
      options = leaflet::pathOptions(pane = "points")
    )
  
  if (!is.null(rem_wgs) && nrow(rem_wgs) > 0)
    m <- m %>% leaflet::addCircleMarkers(
      data = rem_wgs, lng = ~lon, lat = ~lat, group = "REMOVE pts",
      radius = 4, weight = 1, color = stroke, fillColor = col_rem_pt, fillOpacity = 0.95,
      popup = rem_wgs$popup_html,
      options = leaflet::pathOptions(pane = "points")
    )
  
  if (!is.null(gen_wgs) && nrow(gen_wgs) > 0)
    m <- m %>% leaflet::addCircleMarkers(
      data = gen_wgs, lng = ~lon, lat = ~lat, group = "NONCI pts",
      radius = 4, weight = 1, color = stroke, fillColor = col_gen_pt, fillOpacity = 0.95,
      popup = gen_wgs$popup_html,
      options = leaflet::pathOptions(pane = "points")
    )
  
  # ---- ID Labels (hidden by default) ----------------------------------------
  if (!is.null(add_wgs) && nrow(add_wgs) > 0 && "id" %in% names(add_wgs))
    m <- m %>% leaflet::addLabelOnlyMarkers(
      data = add_wgs, lng = ~lon, lat = ~lat, group = "ADD IDs",
      label = ~as.character(id),
      labelOptions = leaflet::labelOptions(
        noHide = TRUE,
        direction = "top",
        offset = c(0, -10),
        textOnly = TRUE,
        style = list(
          "color" = "#E6AB02",
          "font-size" = "10px",
          "font-weight" = "bold",
          "text-shadow" = "1px 1px 2px white, -1px -1px 2px white, 1px -1px 2px white, -1px 1px 2px white"
        )
      ),
      options = leaflet::pathOptions(pane = "id_labels")
    )
  
  if (!is.null(rem_wgs) && nrow(rem_wgs) > 0 && "id" %in% names(rem_wgs))
    m <- m %>% leaflet::addLabelOnlyMarkers(
      data = rem_wgs, lng = ~lon, lat = ~lat, group = "REMOVE IDs",
      label = ~as.character(id),
      labelOptions = leaflet::labelOptions(
        noHide = TRUE,
        direction = "top",
        offset = c(0, -10),
        textOnly = TRUE,
        style = list(
          "color" = "#D95F02",
          "font-size" = "10px",
          "font-weight" = "bold",
          "text-shadow" = "1px 1px 2px white, -1px -1px 2px white, 1px -1px 2px white, -1px 1px 2px white"
        )
      ),
      options = leaflet::pathOptions(pane = "id_labels")
    )
  
  if (!is.null(gen_wgs) && nrow(gen_wgs) > 0 && "id" %in% names(gen_wgs))
    m <- m %>% leaflet::addLabelOnlyMarkers(
      data = gen_wgs, lng = ~lon, lat = ~lat, group = "NONCI IDs",
      label = ~as.character(id),
      labelOptions = leaflet::labelOptions(
        noHide = TRUE,
        direction = "top",
        offset = c(0, -10),
        textOnly = TRUE,
        style = list(
          "color" = "#1B9E77",
          "font-size" = "10px",
          "font-weight" = "bold",
          "text-shadow" = "1px 1px 2px white, -1px -1px 2px white, 1px -1px 2px white, -1px 1px 2px white"
        )
      ),
      options = leaflet::pathOptions(pane = "id_labels")
    )
  
  m <- m %>%
    leaflet::addMapPane("boundary", zIndex = 430)
  
  if (!is.null(bnd_wgs) && nrow(bnd_wgs)) {
    m <- m %>% leaflet::addPolylines(
      data    = bnd_wgs,
      group   = "Barcelona boundary",
      color   = "#111827", weight = 1, opacity = 0.95,
      options = leaflet::pathOptions(pane = "boundary")
    )
  }
  
  # ---- Controls --------------------------------------------------------------
  m <- m %>%
    leaflet::addLayersControl(
      baseGroups = c("Positron"),
      overlayGroups = c(
        "Barcelona boundary", "Tracts", "Area labels",
        "2015 net","Added net","Removed net","2023 net",
        "General (non-CI) net",
        "ADD pts","REMOVE pts","NONCI pts",
        "ADD IDs","REMOVE IDs","NONCI IDs"
      ),
      options = leaflet::layersControlOptions(collapsed = TRUE)
    ) %>%
    leaflet::hideGroup(c(
      "2015 net","Area labels","Added net","Removed net","2023 net","General (non-CI) net",
      "ADD IDs","REMOVE IDs","NONCI IDs"
    )) %>%
    leaflet::fitBounds(bounds[1], bounds[2], bounds[3], bounds[4])
  
  # ---- Force popup links to open in a new tab -------------------------------
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
  
  # ---- Legend: custom HTML ---------------------------------------------------
  legend_html <- "
<div style='background:white; padding:8px; border-radius:4px;
            box-shadow:0 0 4px rgba(0,0,0,0.25); font-size:11px;'>
  <b>Validation points</b><br>
  <div style='display:flex; align-items:center; margin-top:4px;'>
    <div style='width:10px; height:10px; border-radius:50%;
                border:1px solid #666666; background:#E6AB02;
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
                border:1px solid #666666; background:#1B9E77;
                margin-right:6px;'></div>
    NONCI
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

# infra-change map

make_infra_change_map <- function() {
  
  # ---- colours ---------------------------------------------------------------
  col_2015         <- "#7F7F7F"
  col_added        <- "#E69F00"
  col_removed      <- "#FFFFFF"
  col_removed_halo <- "#000000"
  col_2023         <- "#0072B2"
  col_nonci        <- "red"
  
  alpha_2015  <- 0.65
  alpha_added <- 0.95
  alpha_2023  <- 0.60
  alpha_nonci <- 0.40
  alpha_halo  <- 0.25
  
  # ---- prep layers -----------------------------------------------------------
  bnd_wgs      <- get_boundary_wgs()
  cyc15_wgs    <- if (exists("cyc15_n"))       as_wgs_lines(cyc15_n)       else NULL
  added_wgs    <- if (exists("added"))         as_wgs_lines(added)         else NULL
  removed_wgs  <- if (exists("removed"))       as_wgs_lines(removed)       else NULL
  cyc23_wgs    <- if (exists("cyc23_n"))       as_wgs_lines(cyc23_n)       else NULL
  nonci_wgs    <- if (exists("general1523_n")) as_wgs_lines(general1523_n) else NULL
  
  # ---- bounds ----------------------------------------------------------------
  get_bbox <- function(obj) {
    if (!is.null(obj) && inherits(obj,"sf") && nrow(obj)) sf::st_bbox(obj) else NULL
  }
  bb <- if (!is.null(bnd_wgs) && nrow(bnd_wgs)) get_bbox(bnd_wgs) else NULL
  if (is.null(bb)) {
    cands <- Filter(Negate(is.null),
                    lapply(list(cyc15_wgs, added_wgs, removed_wgs, cyc23_wgs, nonci_wgs), get_bbox))
    if (length(cands)) {
      mins <- do.call(pmin, lapply(cands, function(b) c(b["xmin"], b["ymin"])))
      maxs <- do.call(pmax, lapply(cands, function(b) c(b["xmax"], b["ymax"])))
      bb <- c(xmin = as.numeric(mins[1]), ymin = as.numeric(mins[2]),
              xmax = as.numeric(maxs[1]), ymax = as.numeric(maxs[2]))
    } else {
      bb <- c(xmin = 2.05, ymin = 41.30, xmax = 2.25, ymax = 41.45)
    }
  }
  bounds <- as.numeric(bb[c("xmin","ymin","xmax","ymax")])
  
  # ---- map (match map 18 panes, boundary, and toggle) ------------------------
  m <- leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE)) %>%
    leaflet::addProviderTiles("CartoDB.Positron", group = "Positron") %>%
    leaflet::addMapPane("nets",     zIndex = 420) %>%
    leaflet::addMapPane("boundary", zIndex = 430)
  
  # Barcelona boundary outline (toggleable)
  if (!is.null(bnd_wgs) && nrow(bnd_wgs)) {
    m <- m %>% leaflet::addPolylines(
      data    = bnd_wgs,
      group   = "Barcelona boundary",
      color   = "#111827", weight = 1, opacity = 0.95,
      options = leaflet::pathOptions(pane = "boundary")
    )
  }
  
  # Networks
  if (!is.null(cyc15_wgs)) {
    m <- m %>% leaflet::addPolylines(
      data = cyc15_wgs, group = "2015 CI",
      weight = 2, color = col_2015, opacity = alpha_2015,
      options = leaflet::pathOptions(pane = "nets")
    )
  }
  if (!is.null(removed_wgs)) {
    m <- m %>% leaflet::addPolylines(
      data = removed_wgs, group = "Removed (15→23)",
      weight = 2, color = col_removed_halo, opacity = alpha_halo,
      options = leaflet::pathOptions(pane = "nets")
    ) %>%
      leaflet::addPolylines(
        data = removed_wgs, group = "Removed (15→23)",
        weight = 2.5, color = col_removed, opacity = 1.0,
        options = leaflet::pathOptions(pane = "nets")
      )
  }
  if (!is.null(added_wgs)) {
    m <- m %>% leaflet::addPolylines(
      data = added_wgs, group = "Added (15→23)",
      weight = 2, color = col_added, opacity = alpha_added,
      options = leaflet::pathOptions(pane = "nets")
    )
  }
  if (!is.null(cyc23_wgs)) {
    m <- m %>% leaflet::addPolylines(
      data = cyc23_wgs, group = "2023 CI",
      weight = 2, color = col_2023, opacity = alpha_2023,
      options = leaflet::pathOptions(pane = "nets")
    )
  }
  if (!is.null(nonci_wgs)) {
    m <- m %>% leaflet::addPolylines(
      data = nonci_wgs, group = "General (non-CI) 2023",
      weight = 1, color = col_nonci, opacity = alpha_nonci,
      options = leaflet::pathOptions(pane = "nets"),
      smoothFactor = 0.5
    )
  }
  
  m <- m %>%
    leaflet::addLayersControl(
      baseGroups = c("Positron"),
      overlayGroups = c(
        "Barcelona boundary","2015 CI","Added (15→23)",
        "Removed (15→23)","2023 CI","General (non-CI) 2023"
      ),
      options = leaflet::layersControlOptions(collapsed = TRUE)
    ) %>%
    leaflet::hideGroup(c("2023 CI","General (non-CI) 2023")) %>%
    leaflet::fitBounds(bounds[1], bounds[2], bounds[3], bounds[4])

  legend_html <- "
<div style='background:white; padding:8px; border-radius:4px;
            box-shadow:0 0 4px rgba(0,0,0,0.2);'>
<b>Layers</b><br>

<div style='display:flex; align-items:center; margin-top:4px;'>
  <div style='width:24px; height:0; border-top:3px solid #7F7F7F; margin-right:6px;'></div>
  2015 CI
</div>

<div style='display:flex; align-items:center; margin-top:4px;'>
  <div style='width:24px; height:0; border-top:3px solid #E69F00; margin-right:6px;'></div>
  Added (15–23)
</div>

<div style='display:flex; align-items:center; margin-top:4px;'>
  <div style='display:flex; flex-direction:column; margin-right:6px;'>
     <div style='width:24px; height:0; border-top:3px solid #FFFFFF;'></div>
     <div style='width:24px; height:0; border-top:3px solid #000000;'></div>
  </div>
  Removed (15–23)
</div>

</div>
"

m <- m %>% leaflet::addControl(
  html = legend_html,
  position = "bottomright"
)

  m
}


# 19b-infra-change-map-static

# ---- colours -----------------------------------------------------------------
col_outline <- "#111827"   # coast / perimeter
col_land    <- "#FFFFFF"   # inside city

col_2015    <- "#BDBDBD"   # grey
col_added   <- "#009E73"   # green
col_removed <- "#D55E00"   # orange

alpha_2015    <- 0.8
alpha_added   <- 1
alpha_removed <- 1

# ---- prep layers -------------------------------------------------------------
bnd_wgs     <- get_boundary_wgs()
cyc15_wgs   <- if (exists("cyc15_n")) as_wgs_lines(cyc15_n) else NULL
added_wgs   <- if (exists("added"))   as_wgs_lines(added)   else NULL
removed_wgs <- if (exists("removed")) as_wgs_lines(removed) else NULL

# ---- bounds ------------------------------------------------------------------
get_bbox <- function(obj){
  if (!is.null(obj) && inherits(obj, "sf") && nrow(obj)) sf::st_bbox(obj) else NULL
}

bb <- if (!is.null(bnd_wgs) && nrow(bnd_wgs)) get_bbox(bnd_wgs) else NULL

if (is.null(bb)) {
  cands <- Filter(
    Negate(is.null),
    list(get_bbox(cyc15_wgs), get_bbox(added_wgs), get_bbox(removed_wgs))
  )
  if (length(cands)) {
    mins <- do.call(pmin, lapply(cands, function(b) c(b["xmin"], b["ymin"])))
    maxs <- do.call(pmax, lapply(cands, function(b) c(b["xmax"], b["ymax"])))
    bb <- c(xmin = as.numeric(mins[1]), ymin = as.numeric(mins[2]),
            xmax = as.numeric(maxs[1]), ymax = as.numeric(maxs[2]))
  } else {
    bb <- c(xmin = 2.05, ymin = 41.30, xmax = 2.25, ymax = 41.45)
  }
}

# ---- build static map --------------------------------------------------------
p_change <- ggplot() +
  # Barcelona polygon (white over black background)
  { if (!is.null(bnd_wgs) && nrow(bnd_wgs))
    geom_sf(
      data   = bnd_wgs,
      fill   = col_land,
      colour = col_outline,
      linewidth = 0.3
    )
  } +
  # 2015 CI
  { if (!is.null(cyc15_wgs) && nrow(cyc15_wgs))
    geom_sf(
      data = cyc15_wgs,
      aes(colour = "2015"),
      alpha = alpha_2015,
      linewidth = 0.2,
      show.legend = TRUE
    )
  } +
  # Removed segments (orange)
  { if (!is.null(removed_wgs) && nrow(removed_wgs))
    geom_sf(
      data = removed_wgs,
      aes(colour = "Removed (2015–2023)"),
      alpha = alpha_removed,
      linewidth = 0.4,
      show.legend = TRUE
    )
  } +
  # Added segments (green)
  { if (!is.null(added_wgs) && nrow(added_wgs))
    geom_sf(
      data = added_wgs,
      aes(colour = "Added (2015–2023)"),
      alpha = alpha_added,
      linewidth = 0.4,
      show.legend = TRUE
    )
  } +
  coord_sf(
    xlim = c(bb["xmin"], bb["xmax"]),
    ylim = c(bb["ymin"], bb["ymax"]),
    expand = FALSE
  ) +
  scale_colour_manual(
    name = NULL,
    values = c(
      "2015"               = col_2015,
      "Added (2015–2023)"     = col_added,
      "Removed (2015–2023)"   = col_removed
    )
  ) +
  theme_void() +
  theme(
    legend.position   = "right",
    legend.direction  = "vertical",
    plot.background   = element_rect(fill = "NA", colour = NA),
    panel.background  = element_rect(fill = "NA", colour = NA),
    legend.background = element_rect(fill = "NA", colour = NA),
    legend.text       = element_text(colour = "black"),
    plot.margin       = margin(5, 5, 5, 5)
  )

p_change

ggsave(
  filename = "../figs/infra_change_static.png",
  plot = p_change,
  width = 9,
  height = 9,
  dpi = 300,
  bg = "transparent"
)

