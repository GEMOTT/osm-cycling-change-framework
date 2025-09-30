

<!-- # Can OpenStreetMap Reliably Track Changes in Active Travel Infrastructure? Evidence from Barcelona with GSV Validation -->
<!-- ## Introduction -->
<!-- 🔗 Part of the [ATRAPA database project](https://github.com/GEMOTT/atrapa_database)\ -->
<!-- ⬅️ [Back to project overview](https://github.com/GEMOTT/atrapa%20database) ➡️ [Next repo related: Electoral and socioeconomic data](https://github.com/GEMOTT/electoral-socioeconomic-data) -->
<!-- The relationship between the built environment and travel behaviour has been widely studied, with many studies identifying associations between environmental characteristics and travel patterns [@cerin_neighbourhood_2017; @ding_neighborhood_2011; @zhang_impact_2022]. However, most research relies on cross-sectional data, which cannot establish causality [@mccormack_search_2011; @coevering_multi-period_2015]. In contrast, studies that track changes in both travel behaviour and the built environment—such as longitudinal studies and natural experiments—offer stronger causal insights but remain relatively scarce [@karmeniemi_built_2018; @smith_systematic_2017; @tcymbal_effects_2020]. -->
<!-- One of the main challenges in expanding this area of research is the limited availability of consistent, time-series data on the built environment. While historical data on travel behaviour is often more accessible—through sources like censuses, surveys, and increasingly, crowdsourced platforms like Strava—comparable records of past urban infrastructure are much harder to obtain. Long-term records of active travel networks, though consistent and accessible historical data remains limited and varies across cities, which hinders broader or international comparisons. An alternative is to reconstruct historical built environment data manually using maps, satellite imagery, and planning records, but this process is highly resource-intensive and typically limited in scale. -->
<!-- The growing availability of Volunteered Geographic Information (VGI) presents new opportunities to overcome data limitations in built environment research. Among these sources, OpenStreetMap (OSM) stands out for providing open, editable, and historical data on various types of infrastructure, making it a promising tool for analysing urban transformations over time. However, its application in this context requires careful validation due to well-documented limitations in accuracy, completeness, and temporal consistency [@barron_comprehensive_2014]. -->
<!-- While OSM has been widely used for mapping infrastructure and supporting routing applications, its utility for analysing changes in infrastructure over time is less well established. This study seeks to evaluate how accurately historical OSM data reflects changes in active travel infrastructure—specifically bike lanes, pedestrian streets, and living streets. We propose and apply a semi-automated validation method that compares reported OSM changes against external reference sources, including street-level imagery (Google Street View), satellite imagery, and official municipal records. -->
<!-- Focusing on the city of Barcelona, our approach uses stratified sampling to ensure spatial and socio-demographic diversity. While the analysis is limited to one city, the proposed framework is designed to be scalable and transferable, offering a practical methodology for researchers and planners seeking to monitor infrastructure change over time using open data sources. -->
<!-- This study builds on recent efforts to assess OSM’s data quality and potential for infrastructure analysis, with particular attention to its capacity to represent change over time. -->

# Validating OpenStreetMap for Detecting Cycling Infrastructure Change: A Pilot Study in Barcelona

## Introduction

- **Context**: Urban transformations (e.g. new bike lanes, pedestrian
  areas) can reshape mobility and health, but studying their effects
  requires reliable historical data.

- **Problem**: Standardised datasets of infrastructure change are rarely
  available across cities and years.

- **Solution**: Volunteered Geographic Information, especially
  OpenStreetMap (OSM), provides open and historical data on
  infrastructure, offering a potential way to track changes over time.

- **Aim**: Assess how well OSM detects cycling infrastructure (CI)
  changes (additions/removals), by estimating precision, recall, false
  negatives, and error-adjusted rates of change.

<!-- - **Outputs**: Measures of precision, recall, false negatives, error-adjusted change estimates, and stratum-level diagnostics. -->

- **Contribution**: Using Barcelona as a pilot case, this study provides
  one of the first systematic validations of OSM for detecting changes
  in cycling infrastructure, introduces an error-adjusted approach to
  estimate true additions and removals, and delivers city-level
  diagnostics to inform cross-city comparisons and practical monitoring
  of urban transformations.

## Data and Methods

### Data

#### Setting and period

- **Study area**: Barcelona; period: 2019→2023.

#### OpenStreetMap (OSM)

- **Extraction**: Download OSM linework for both years (snapshot dates:
  2020-01-01 for 2019 and 2024-01-01 for 2023).

- **CI selector**:

  - Keep segments with: `highway=cycleway` • `cycleway=*` or
    `cycleway:left/right/both=*` (lane/track/opposite/separate) •
    `bicycle_road=yes` • designated `path/footway/track` for bicycles.

  - Normalize geometries; metric CRS; min-length filter; tolerance
    buffer to reduce sliver noise.

- **Non-CI (general network)**: Base roads excluding all CI tags (strict
  complement).

#### Google Street View (GSV)

- Source of independent imagery; pano dates (2019–2023 range); coverage
  and limitations.

### Methods

#### Change detection

- ADDED: present in 2023, absent in 2019.
- REMOVED: present in 2019, absent in 2023.
- Computed via buffered geometric differencing, dropping tiny fragments.

#### Sampling frame

- Stratified tracts: Pre-selected census tracts by centrality × density
  (3×3).

- In sampled tracts, draw length-weighted points for ADD, REMOVE, and
  GENERAL (2023 non-CI network).

- Validation point = midpoint of the sampled segment.

![](README_files/figure-commonmark/13-bivariate-map-1.png)

#### Validation protocol

##### Coding rules

- **Tolerance windows**: 2019 condition = 2018–2020; 2023 condition =
  2021–2025.

- Per point & year:

  - Verifiability (yes/no). If not verifiable → presence = NA.

  - Presence of CI (yes/no/NA).

  - Notes (obstruction/works/angle).

  - Ambiguous but visible → keep verifiable=YES, presence=NA.

![](figs/validation_points.png)

##### Outcomes and metrics

- For ADD/REMOVE:

  - TP: OSM change confirmed by GSV.

  - FP: OSM change not confirmed (e.g., late mapping for ADD; data
    clean-up for REMOVE).

  - FN: true change in GENERAL missed by OSM.

- Precision = TP/(TP+FP); Recall = TP/(TP+FN); F1 = 2PR/(P+R).

- Overall (adds+removes): pool TP/FP/FN across classes.

<!-- ### Uncertainty & stratification -->
<!-- - 95% CIs for proportions: Wilson/score (prop.test(correct=FALSE)). -->
<!-- - By-stratum reporting (centrality × density); if strata imbalanced, compute design-weighted overall. -->
<!-- ### Sensitivity analyses -->
<!-- - Loose FN (ADD): count any verifiable present_2023==TRUE in GENERAL as FN_ADD (regardless of 2019). -->
<!-- - Alternative windows: tighten 2019 to calendar year; set 2023 to 2022–2024. -->
<!-- ### Inter-rater reliability -->
<!-- Double-code ~10–20% of points; report Cohen’s κ (+ % agreement) for presence per year. -->

#### Calibration

- Raw OSM change-km were scaled by the validation metrics (precision and
  recall) to obtain error-adjusted estimates of added and removed cycle
  infrastructure.

- Adjustments were computed separately for ADD and REMOVE classes, then
  aggregated to tract and city level

## Results

### Raw OSM change estimates

The OSM cycling network expanded from 214.1 km in 2019 to 263.9 km in
2023 (+49.7 km, ≈23%). Segment differencing suggests 63.7 km were added
and 22.3 km removed (Table 1). Additions were concentrated in dense,
central tracts—especially D3_C3 (36.1% of added km)—while removals were
less frequent and clustered mainly in D1_C3 (61.0%) (Table 2).

| Metric                     | Value |
|:---------------------------|------:|
| Total 2019 (km)            | 214.1 |
| Total 2023 (km)            | 263.9 |
| Net growth (km)            |  49.7 |
| Added (km)                 |  63.4 |
| Removed (km)               |  22.3 |
| Added − Removed (km)       |  41.1 |
| Gap: (Added−Removed) − Net |  -8.6 |

Table 1: Consistency between yearly totals and differencing estimates
(2019–2023, Barcelona)

| stratum | Added_km | Removed_km | Added_pct | Removed_pct |
|:--------|---------:|-----------:|----------:|------------:|
| D1_C1   |      0.0 |        0.0 |      0.0% |        3.1% |
| D1_C2   |      0.4 |        0.0 |     22.1% |        4.9% |
| D1_C3   |      0.3 |        0.5 |     13.3% |       61.0% |
| D2_C1   |      0.0 |        0.1 |      0.0% |       11.1% |
| D2_C2   |      0.1 |        0.2 |      5.2% |       19.8% |
| D2_C3   |      0.1 |        0.0 |      4.3% |        0.0% |
| D3_C1   |      0.2 |        0.0 |      9.8% |        0.0% |
| D3_C2   |      0.2 |        0.0 |      9.3% |        0.0% |
| D3_C3   |      0.7 |        0.0 |     36.1% |        0.0% |

Table 2: OSM-estimated additions and removals (2019–2023) by density ×
centrality stratum

![](figs/change_map.png)

### Validation results

Validation covered 44 points across all nine density–centrality strata
(largest D3_C3: 11/44). Among OSM-flagged changes with verifiable
imagery (n=20; 15 ADD, 5 REMOVE), ADD performed well (precision 0.87
\[0.62–0.96\]; recall 1.00 \[0.77–1.00\]; F1 0.93), whereas REMOVE was
weak (precision 0.20 \[0.04–0.62\]; recall 0.50 \[0.09–0.91\]; F1 0.29);
we found one false negative (missed removal) and none for ADD. Pooled
over classes: precision 0.70 \[0.48–0.85\], recall 0.93 \[0.70–0.99\],
F1 0.80.

| stratum | REMOVE | ADD | GENERAL | Total |
|:--------|-------:|----:|--------:|------:|
| D1_C1   |      1 |   0 |       0 |     1 |
| D1_C2   |      1 |   3 |       4 |     8 |
| D1_C3   |      2 |   3 |       4 |     9 |
| D2_C1   |      1 |   0 |       0 |     1 |
| D2_C2   |      1 |   1 |       0 |     2 |
| D2_C3   |      0 |   1 |       1 |     2 |
| D3_C1   |      0 |   1 |       2 |     3 |
| D3_C2   |      0 |   2 |       2 |     4 |
| D3_C3   |      0 |   5 |       3 |     8 |
| TOTAL   |      6 |  16 |      16 |    38 |

Table 3: Validation points by class and stratum

| Class | n (usable) | TP | FP | FN (source) | Precision | Precision (95% CI) | Recall | Recall (95% CI) | F1 |
|:---|---:|---:|---:|:---|---:|---:|---:|---:|---:|
| ADD | 15 | 13 | 2 | from GENERAL | 0.87 | 0.87 \[0.62–0.96\] | 1.00 | 1.00 \[0.77–1.00\] | 0.93 |
| REMOVE | 5 | 1 | 4 | from GENERAL | 0.20 | 0.20 \[0.04–0.62\] | 0.50 | 0.50 \[0.09–0.91\] | 0.29 |
| Pooled | 20 | 14 | 6 | from GENERAL | 0.70 | 0.70 \[0.48–0.85\] | 0.93 | 0.93 \[0.70–0.99\] | 0.80 |

Table 4: Validation performance (usable points only)

<!-- ### Error-adjusted change estimates -->
<!-- Calibrated totals after applying validation metrics. -->
<!-- Example table contrasting Raw vs Adjusted at city level (and possibly mean per tract). -->
<!-- Map of tracts showing adjusted changes (before vs after adjustment). -->
<!-- ### Spatial patterns -->
<!-- Highlight clusters of growth or underestimation. -->
<!-- Example: “Adjusted estimates show the largest growth in central tracts, while peripheral areas show smaller net additions once errors are corrected.” -->

## Supplements

### S1. Validation workbook

**Data:** [Download the validation workbook
(Excel)](outputs/barcelona_samples_2019_2023.xlsx)

### S2. Interactive stratification map (density × centrality, 3×3) with sampled tracts

``` r
# #| label: 17-stratification-map
# #| echo: false
# # --- Leaflet map matching the static bivariate colours ---------------------
# library(sf)
# library(leaflet)
# library(biscale)
# library(htmltools)
# library(dplyr)
# 
# # 0) Ensure identical classes: reuse bb_bivar from your static pipeline
# stopifnot("bi_class" %in% names(bb_bivar))
# 
# # 1) Fix geometry + CRS for leaflet
# bb_bivar_ll <- bb_bivar |>
#   sf::st_make_valid() |>
#   sf::st_transform(4326)
# 
# # (optional) sampled tracts outlines
# sampled_ll <- NULL
# if (exists("sampled_tracts") && inherits(sampled_tracts, "sf") && nrow(sampled_tracts)) {
#   sampled_ll <- sampled_tracts |> st_make_valid() |> st_transform(4326)
# }
# 
# # 2) Build the exact same colour mapping used by bi_scale_fill(pal="DkBlue2", dim=3)
# dim_bi  <- 3
# cols    <- biscale::bi_pal("DkBlue2", dim_bi, preview = FALSE)
# # Arrange to match the legend orientation (↑ y, → x) used in biscale
# M       <- matrix(cols, nrow = dim_bi, byrow = TRUE)
# M_flip  <- M[dim_bi:1, ]                            # flip rows so y increases upward
# 
# labs_df   <- expand.grid(x = 1:dim_bi, y = 1:dim_bi)
# lab_names <- sprintf("%d-%d", labs_df$x, labs_df$y)
# lab_cols  <- vapply(seq_len(nrow(labs_df)), function(i) M_flip[labs_df$y[i], labs_df$x[i]], "")
# col_lu    <- setNames(lab_cols, lab_names)
# 
# # 3) Make sure bi_class is character (not factor), then map colours
# bb_bivar_ll <- bb_bivar_ll |>
#   mutate(bi_class_chr = as.character(bi_class),
#          fill_col     = unname(col_lu[bi_class_chr]),
#          fill_col     = ifelse(is.na(fill_col), "#00000000", fill_col))
# 
# # 4) Add a clean bivariate legend that matches the static one
# add_bi_legend_leaflet <- function(map, pal = "DkBlue2", dim = 3,
#                                   position = "bottomright",
#                                   title = "Density × Centrality",
#                                   xlab = "Higher Density →",
#                                   ylab = "More Central ↑",
#                                   box = 14, gap = 2) {
#   cols  <- biscale::bi_pal(pal, dim, preview = FALSE)
#   grid  <- matrix(cols, nrow = dim, byrow = TRUE)[dim:1, ]
#   cells <- as.vector(t(grid))
# 
#   html <- tags$div(
#     tags$style(HTML(paste0(
#       ".bi-legend{background:#fff;padding:6px 8px;border-radius:6px;",
#       "box-shadow:0 1px 4px rgba(0,0,0,.3);font-family:sans-serif}",
#       ".bi-title{font-weight:600;margin-bottom:4px;font-size:12px}",
#       ".bi-wrap{display:flex;align-items:center}",
#       ".bi-grid{display:grid;grid-template-columns:repeat(", dim, ",", box, "px);",
#       "grid-auto-rows:", box, "px;gap:", gap, "px;margin:0 6px}",
#       ".bi-cell{width:", box, "px;height:", box, "px}",
#       ".bi-y{writing-mode:vertical-rl;transform:rotate(180deg);font-size:11px;color:#444}",
#       ".bi-x{text-align:center;font-size:11px;color:#444;margin-top:4px}"
#     ))),
#     tags$div(class = "bi-legend",
#       tags$div(class = "bi-title", title),
#       tags$div(class = "bi-wrap",
#         tags$div(class = "bi-y", ylab),
#         tags$div(class = "bi-grid",
#           lapply(cells, function(clr) tags$div(class = "bi-cell",
#                                                style = paste0("background:", clr, ";")))
#         )
#       ),
#       tags$div(class = "bi-x", xlab)
#     )
#   )
#   leaflet::addControl(map, html = html, position = position)
# }
# 
# # 4) Build the leaflet map
# m <- leaflet(options = leafletOptions(zoomControl = TRUE)) |>
#   addProviderTiles("CartoDB.Positron", group = "Positron") |>
#   addPolygons(data = bb_bivar_ll,
#               weight = 0.5, color = "#ffffff", opacity = 1,
#               fillColor = ~fill_col, fillOpacity = 0.9,
#               smoothFactor = 0.2,
#               label = ~paste0("Class: ", bi_class_chr))
# 
# if (!is.null(sampled_ll)) {
#   m <- m |> addPolygons(data = sampled_ll, fill = FALSE, color = "black", weight = 1.2)
# }
# 
# # 5) Add the same bi-legend as before (already working for you)
# m <- add_bi_legend_leaflet(m, pal = "DkBlue2", dim = 3, position = "bottomright")
# m
```

### S3. Interactive validation points map (with GSV links)

``` r
# #| label: 17-validation-map-points
# #| echo: false
# #| message: false
# #| warning: false
# 
# # ---- helper: prep points (WGS84 + lon/lat + popup) --------------------------
# prep_pts <- function(x){
#   if (!inherits(x,"sf") || !nrow(x)) return(NULL)
#   w  <- st_transform(x, 4326)
#   xy <- st_coordinates(w)
#   good <- is.finite(xy[,1]) & is.finite(xy[,2])
#   if (!any(good)) return(NULL)
#   w   <- w[good, , drop = FALSE]
#   xy  <- xy[good, , drop = FALSE]
#   w$lon <- xy[,1]; w$lat <- xy[,2]
#   w$gsv <- sprintf("https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=%f,%f", xy[,2], xy[,1])
#   w$popup <- paste0(
#     "<b>", w$class, "</b>",
#     "<br/>tract: ", w$tract_id,
#     if ("stratum" %in% names(w)) paste0("<br/>stratum: ", w$stratum) else "",
#     "<br/><a href='", w$gsv, "' target='_blank'>Open GSV</a>"
#   )
#   w
# }
# 
# add_wgs <- prep_pts(added_pts)
# rem_wgs <- prep_pts(removed_pts)
# gen_wgs <- prep_pts(gen_pts)
# 
# # ---- bounds (prefer city_perimeter -> points -> tracts -> fallback) ----------
# if (exists("city_perimeter")) {
#   bb <- st_bbox(st_transform(city_perimeter, 4326))
#   bounds <- unname(c(bb$xmin, bb$ymin, bb$xmax, bb$ymax))
# } else {
#   bbs <- list()
#   if (!is.null(add_wgs) && nrow(add_wgs)) bbs <- c(bbs, list(st_bbox(add_wgs)))
#   if (!is.null(rem_wgs) && nrow(rem_wgs)) bbs <- c(bbs, list(st_bbox(rem_wgs)))
#   if (!is.null(gen_wgs) && nrow(gen_wgs)) bbs <- c(bbs, list(st_bbox(gen_wgs)))
#   if (!length(bbs) && exists("tracts") && nrow(tracts)) bbs <- list(st_bbox(st_transform(tracts, 4326)))
#   bounds <- if (length(bbs)) {
#     M <- do.call(rbind, lapply(bbs, function(b) unname(c(b$xmin,b$ymin,b$xmax,b$ymax))))
#     c(min(M[,1]), min(M[,2]), max(M[,3]), max(M[,4]))
#   } else c(2.05, 41.30, 2.25, 41.45)  # BCN-ish fallback
# }
# 
# # ---- colours -----------------------------------------------------------------
# # points (Dark2-ish, no purple)
# col_add_pt <- "#E6AB02"  # gold
# col_rem_pt <- "#D95F02"  # orange-red
# col_gen_pt <- "#1B9E77"  # teal
# stroke     <- "#000000"
# 
# # tracts
# tract_stroke <- "#000000"   # very light outline
# tract_fill   <- "#FFFFFF"   # fully transparent fill
# 
# 
# # networks (optional)
# col_2019_net   <- "#666666"
# col_added_net  <- "#D95F02"
# col_removedNet <- "#FFFFFF"
# col_removedHalo<- "#000000"
# col_2023_net   <- "#1B9E77"
# col_nonci      <- "#BDBDBD"   # <-- NEW: general (non-CI) net
# 
# 
# # ---- map ---------------------------------------------------------------------
# m <- leaflet(options = leafletOptions(preferCanvas = TRUE)) %>%
#   addProviderTiles("CartoDB.Positron", group = "Positron")
# 
# # Tracts polygons (transparent fill, faint outline)
# if (exists("tracts") && inherits(tracts,"sf") && nrow(tracts)) {
#   m <- m %>%
#     # put tracts below points but above tiles (optional, for layering)
#     addMapPane("tractsPane", zIndex = 410) %>%
#     addPolygons(
#      data = st_transform(tracts, 4326), group = "Tracts",
#       color = tract_stroke, opacity = 0.7,  # <-- visible but subtle
#       weight = 0.8,                          # hairline; try 1.0 if still faint
#       fillColor = tract_fill, fillOpacity = 0,
#       smoothFactor = 0.5
#   )
# 
#   # Area labels (already transparent background)
#   tract_centers <- st_point_on_surface(st_transform(tracts, 4326))
#   m <- m %>%
#     addCircleMarkers(
#       data = tract_centers, group = "Area labels",
#       radius = 0.1, stroke = FALSE, fillOpacity = 0,
#       label = ~as.character(tract_id),
#       labelOptions = labelOptions(
#         noHide = TRUE, direction = "center",
#         style = list(
#           "background"      = "transparent",
#           "border"          = "none",
#           "box-shadow"      = "none",
#           "padding"         = "0px",
#           "color"           = "rgba(0,0,0,0.25)",
#           "text-shadow"     = "none",
#           "pointer-events"  = "none"
#         )
#       )
#     )
# }
# 
# # Prepare General (non-CI) network (lines only)
# gnet <- NULL
# if (exists("general23_n") && inherits(general23_n,"sf") && nrow(general23_n)) {
#   gnet <- general23_n
# } else if (exists("noncycle23") && inherits(noncycle23,"sf") && nrow(noncycle23)) {
#   gnet <- noncycle23
# }
# 
# if (!is.null(gnet)) {
#   keep_lines <- sf::st_geometry_type(gnet, by_geometry = TRUE) %in% c("LINESTRING","MULTILINESTRING")
#   gnet <- gnet[keep_lines, , drop = FALSE]
#   if (nrow(gnet)) {
#     gnet <- suppressWarnings(sf::st_cast(gnet, "LINESTRING"))
#     gnet <- gnet[!sf::st_is_empty(sf::st_geometry(gnet)), , drop = FALSE]
#     gnet_wgs <- sf::st_transform(gnet, 4326)
#   } else {
#     gnet_wgs <- NULL
#   }
# } else {
#   gnet_wgs <- NULL
# }
# 
# # Optional network context (added but hidden by default below)
# if (exists("cyc19_n") && inherits(cyc19_n,"sf") && nrow(cyc19_n))
#   m <- m %>% addPolylines(data = st_transform(cyc19_n, 4326), group = "2019 net",
#                           weight = 2, color = col_2019_net, opacity = 0.7)
# 
# if (exists("removed") && inherits(removed,"sf") && nrow(removed)) {
#   m <- m %>% addPolylines(data = st_transform(removed, 4326), group = "Removed net",
#                           weight = 2.6, color = col_removedHalo, opacity = 0.18)
#   m <- m %>% addPolylines(data = st_transform(removed, 4326), group = "Removed net",
#                           weight = 2.0, color = col_removedNet,  opacity = 1.0)
# }
# 
# if (exists("added") && inherits(added,"sf") && nrow(added))
#   m <- m %>% addPolylines(data = st_transform(added, 4326), group = "Added net",
#                           weight = 2, color = col_added_net, opacity = 0.95)
# 
# if (exists("cyc23_n") && inherits(cyc23_n,"sf") && nrow(cyc23_n))
#   m <- m %>% addPolylines(data = st_transform(cyc23_n, 4326), group = "2023 net",
#                           weight = 2, color = col_2023_net, opacity = 0.6)
# 
# # Points (explicit lng/lat; active by default)
# if (!is.null(add_wgs) && nrow(add_wgs) > 0)
#   m <- m %>% addCircleMarkers(data = add_wgs, lng = ~lon, lat = ~lat, group = "ADD pts",
#                               radius = 4, weight = 1, color = stroke,
#                               fillColor = col_add_pt, fillOpacity = 0.95,
#                               popup = ~popup)
# 
# if (!is.null(rem_wgs) && nrow(rem_wgs) > 0)
#   m <- m %>% addCircleMarkers(data = rem_wgs, lng = ~lon, lat = ~lat, group = "REMOVE pts",
#                               radius = 4, weight = 1, color = stroke,
#                               fillColor = col_rem_pt, fillOpacity = 0.95,
#                               popup = ~popup)
# 
# if (!is.null(gen_wgs) && nrow(gen_wgs) > 0)
#   m <- m %>% addCircleMarkers(data = gen_wgs, lng = ~lon, lat = ~lat, group = "GENERAL pts",
#                               radius = 4, weight = 1, color = stroke,
#                               fillColor = col_gen_pt, fillOpacity = 0.95,
#                               popup = ~popup)
# # General (non-CI) network
# if (!is.null(gnet_wgs) && nrow(gnet_wgs))
#   m <- m %>% addPolylines(data = gnet_wgs, group = "General (non-CI) net",
#                           weight = 1, color = col_nonci, opacity = 0.7)
# 
# # Control + single legend
# m %>%
#   clearControls() %>%
#   addLayersControl(
#     baseGroups = c("Positron"),
#     overlayGroups = c(
#       "Tracts","Area labels",
#       "2019 net","Added net","Removed net","2023 net",
#       "General (non-CI) net",         # <-- add here
#       "ADD pts","REMOVE pts","GENERAL pts"
#     ),
#     options = layersControlOptions(collapsed = TRUE)
#   ) %>%
#   hideGroup(c("2019 net","Added net","Removed net","2023 net","General (non-CI) net")) %>%  # <-- add here
#   fitBounds(bounds[1], bounds[2], bounds[3], bounds[4]) %>%
#   addLegend(
#     position = "bottomright", title = "",
#     colors = c(col_add_pt, col_rem_pt, col_gen_pt),
#     labels = c("ADD points", "REMOVE points", "GENERAL points"),
#     opacity = 1
#   )
```

### S4. Interactive infrastructure change map (2019→2023)

``` r
# #| label: 09-map
# #| echo: false
# #| message: false
# #| warning: false
# 
# # ---- helper: force WGS84 LINESTRING and skip empties -------------------------
# as_wgs_lines <- function(x){
#   if (!inherits(x, "sf") || !nrow(x)) return(NULL)
#   x <- sf::st_make_valid(x)
#   keep <- sf::st_geometry_type(x) %in% c("LINESTRING","MULTILINESTRING")
#   x <- x[keep, , drop = FALSE]
#   if (!nrow(x)) return(NULL)
#   x <- suppressWarnings(sf::st_cast(x, "LINESTRING"))
#   x <- x[!sf::st_is_empty(sf::st_geometry(x)), , drop = FALSE]
#   if (!nrow(x)) return(NULL)
#   x <- sf::st_transform(x, 4326)
#   x
# }
# 
# as_wgs_poly <- function(x){
#   if (!inherits(x, "sf") || !nrow(x)) return(NULL)
#   x <- sf::st_make_valid(x)
#   keep <- sf::st_geometry_type(x) %in% c("POLYGON","MULTIPOLYGON")
#   x <- x[keep, , drop = FALSE]
#   if (!nrow(x)) return(NULL)
#   x <- sf::st_transform(x, 4326)
#   x
# }
# 
# # ---- colours -----------------------------------------------------------------
# col_2019        <- "#666666"
# col_added       <- "#D95F02"
# col_removed     <- "#FFFFFF"
# col_removed_halo<- "#000000"   # <-- needed for the halo
# col_2023        <- "#1B9E77"
# col_nonci       <- "#BDBDBD"
# 
# alpha_2019  <- 0.85
# alpha_added <- 0.95
# alpha_2023  <- 0.65
# alpha_nonci <- 0.70
# alpha_halo  <- 0.18
# 
# 
# # ---- prep layers safely ------------------------------------------------------
# perim_wgs   <- if (exists("city_perimeter")) as_wgs_poly(city_perimeter) else NULL
# cyc19_wgs   <- if (exists("cyc19_n"))  as_wgs_lines(cyc19_n)  else NULL
# added_wgs   <- if (exists("added"))    as_wgs_lines(added)    else NULL
# removed_wgs <- if (exists("removed"))  as_wgs_lines(removed)  else NULL
# cyc23_wgs   <- if (exists("cyc23_n"))  as_wgs_lines(cyc23_n)  else NULL
# nonci_wgs   <- if (exists("general23_n")) as_wgs_lines(general23_n) else NULL
# 
# # ---- bounds (prefer perimeter, else any layer, else BCN-ish fallback) --------
# get_bbox <- function(obj) if (!is.null(obj) && inherits(obj,"sf") && nrow(obj)) sf::st_bbox(obj) else NULL
# bb <- get_bbox(perim_wgs)
# if (is.null(bb)) {
#   cands <- Filter(Negate(is.null), list(get_bbox(cyc19_wgs), get_bbox(added_wgs),
#                                         get_bbox(removed_wgs), get_bbox(cyc23_wgs),
#                                         get_bbox(nonci_wgs)))
#   if (length(cands)) {
#     mins <- do.call(pmin, lapply(cands, function(b) c(b$xmin,b$ymin)))
#     maxs <- do.call(pmax, lapply(cands, function(b) c(b$xmax,b$ymax)))
#     bb <- structure(list(xmin=mins[1], ymin=mins[2], xmax=maxs[1], ymax=maxs[2]), class="bbox")
#   } else {
#     bb <- c(xmin = 2.05, ymin = 41.30, xmax = 2.25, ymax = 41.45)
#   }
# }
# bounds <- unname(c(bb["xmin"], bb["ymin"], bb["xmax"], bb["ymax"]))
# 
# # ---- map ---------------------------------------------------------------------
# m <- leaflet(options = leafletOptions(preferCanvas = TRUE)) %>%
#   addProviderTiles("CartoDB.Positron", group = "Positron")
# 
# if (!is.null(perim_wgs))
#   m <- m %>% addPolygons(data = perim_wgs, group = "Boundary",
#                          weight = 1, color = "#222222", fill = FALSE, fillOpacity = 0)
# 
# if (!is.null(cyc19_wgs))
#   m <- m %>% addPolylines(data = cyc19_wgs, group = "2019 CI",
#                           weight = 2, color = col_2019, opacity = alpha_2019)
# 
# if (!is.null(removed_wgs)) {
#   m <- m %>% addPolylines(data = removed_wgs, group = "Removed (19→23)",
#                           weight = 2, color = col_removed_halo, opacity = alpha_halo)
#   m <- m %>% addPolylines(data = removed_wgs, group = "Removed (19→23)",
#                           weight = 2.5, color = col_removed, opacity = 1.0)
# }
# 
# if (!is.null(added_wgs))
#   m <- m %>% addPolylines(data = added_wgs, group = "Added (19→23)",
#                           weight = 2, color = col_added, opacity = alpha_added)
# 
# if (!is.null(cyc23_wgs))
#   m <- m %>% addPolylines(data = cyc23_wgs, group = "2023 CI",
#                           weight = 2, color = col_2023, opacity = alpha_2023)
# 
# if (!is.null(nonci_wgs))
#   m <- m %>% addPolylines(data = nonci_wgs, group = "General (non-CI) 2023",
#                           weight = 1, color = col_nonci, opacity = alpha_nonci,
#                           smoothFactor = 0.5)
# 
# m %>%
#   addLayersControl(
#     baseGroups = c("Positron"),
#     overlayGroups = c("Boundary","2019 CI","Added (19→23)","Removed (19→23)","2023 CI","General (non-CI) 2023"),
#     options = layersControlOptions(collapsed = TRUE)
#   ) %>%
#   hideGroup(c("2023 CI","General (non-CI) 2023")) %>%
#   fitBounds(bounds[1], bounds[2], bounds[3], bounds[4]) %>%
#   addLegend(
#     position = "bottomright", title = "Layers",
#     colors = c(col_2019, col_added, col_removed),
#     labels = c("2019 CI","Added (19→23)","Removed (19→23)"),
#     opacity = 1
#   )
```

<!-- ## References -->
