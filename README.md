

<!-- # Can OpenStreetMap Reliably Track Changes in Active Travel Infrastructure? Evidence from Barcelona with GSV Validation -->
<!-- ## Introduction -->

🔗 Part of the [ATRAPA database
project](https://github.com/GEMOTT/atrapa_database)  

⬅️ [Back to project
overview](https://github.com/GEMOTT/atrapa%20database) ➡️ [Next repo
related: Electoral and socioeconomic
data](https://github.com/GEMOTT/electoral-socioeconomic-data)

<!-- The relationship between the built environment and travel behaviour has been widely studied, with many studies identifying associations between environmental characteristics and travel patterns [@cerin_neighbourhood_2017; @ding_neighborhood_2011; @zhang_impact_2022]. However, most research relies on cross-sectional data, which cannot establish causality [@mccormack_search_2011; @coevering_multi-period_2015]. In contrast, studies that track changes in both travel behaviour and the built environment—such as longitudinal studies and natural experiments—offer stronger causal insights but remain relatively scarce [@karmeniemi_built_2018; @smith_systematic_2017; @tcymbal_effects_2020]. -->
<!-- One of the main challenges in expanding this area of research is the limited availability of consistent, time-series data on the built environment. While historical data on travel behaviour is often more accessible—through sources like censuses, surveys, and increasingly, crowdsourced platforms like Strava—comparable records of past urban infrastructure are much harder to obtain. Long-term records of active travel networks, though consistent and accessible historical data remains limited and varies across cities, which hinders broader or international comparisons. An alternative is to reconstruct historical built environment data manually using maps, satellite imagery, and planning records, but this process is highly resource-intensive and typically limited in scale. -->
<!-- The growing availability of Volunteered Geographic Information (VGI) presents new opportunities to overcome data limitations in built environment research. Among these sources, OpenStreetMap (OSM) stands out for providing open, editable, and historical data on various types of infrastructure, making it a promising tool for analysing urban transformations over time. However, its application in this context requires careful validation due to well-documented limitations in accuracy, completeness, and temporal consistency [@barron_comprehensive_2014]. -->
<!-- While OSM has been widely used for mapping infrastructure and supporting routing applications, its utility for analysing changes in infrastructure over time is less well established. This study seeks to evaluate how accurately historical OSM data reflects changes in active travel infrastructure—specifically bike lanes, pedestrian streets, and living streets. We propose and apply a semi-automated validation method that compares reported OSM changes against external reference sources, including street-level imagery (Google Street View), satellite imagery, and official municipal records. -->
<!-- Focusing on the city of Barcelona, our approach uses stratified sampling to ensure spatial and socio-demographic diversity. While the analysis is limited to one city, the proposed framework is designed to be scalable and transferable, offering a practical methodology for researchers and planners seeking to monitor infrastructure change over time using open data sources. -->
<!-- This study builds on recent efforts to assess OSM’s data quality and potential for infrastructure analysis, with particular attention to its capacity to represent change over time. -->

# Validating OpenStreetMap for detecting cycling-infrastructure change: A Barcelona pilot using Google Street View (2019–2023)

## Introduction

- Context: Urban transformations, such as new or upgraded bike lanes,
  can reshape mobility and health, but studying their effects requires
  reliable historical data.

- Problem: Standardised datasets of infrastructure change are rarely
  available across cities and years.

- Potential solution: Volunteered Geographic Information, especially
  OpenStreetMap (OSM), provides open and historical data on
  infrastructure, offering a promising way to track changes over time.
  However, the reliability of OSM data for detecting infrastructure
  change is uncertain and requires systematic validation.

- Aim: Determine whether OSM reliably reflects new or removed bike lanes
  in Barcelona using dated Google Street View as ground truth.

- Contribution: We benchmark OSM’s change detection (precision, recall,
  F1) and share a reusable validation workflow that others can apply; we
  also outline calibration as a next step.

<!-- - **Outputs**: Measures of precision, recall, false negatives, error-adjusted change estimates, and stratum-level diagnostics. -->

## Data and methods

### Data sources

- OpenStreetMap (OSM): open, collaboratively mapped vector data with
  tags for cycling infra.

- Google Street View (GSV): geotagged, time-stamped street-level
  imagery. (Right now they’re just headings.)

<!-- -   Source of independent imagery; pano dates (2019–2023 range); coverage and limitations. -->

### Methods

<div id="fig-workflow">

<img src="figs/osm_gsv_flowchart.png" data-fig-align="center" />


Figure 1: Analytical workflow showing the main steps for detecting and
validating cycling-infrastructure changes in Barcelona (2019–2023).

</div>

#### OSM data extraction and preprocessing

- Extraction: Download OSM linework for both years (snapshot dates:
  2020-01-01 for 2019 and 2024-01-01 for 2023).

- CI selector:

  - Keep segments with: `highway=cycleway` • `cycleway=*` or
    `cycleway:left/right/both=*` (lane/track/opposite/separate) •
    `bicycle_road=yes` • designated `path/footway/track` for bicycles.

  - Normalize geometries; metric CRS; min-length filter; tolerance
    buffer to reduce sliver noise.

- Non-CI (general network): Base roads excluding all CI tags (strict
  complement).

#### Geometric differencing

- ADDED: CI present in OSM 2023, absent in OSM 2019.
- REMOVED: CI present in OSM 2019, absent in OSM 2023.
- Computed via buffered geometric differencing, dropping tiny fragments.

#### Sampling design

- Stratified tracts: Pre-selected census tracts by centrality × density
  (3×3).

- In sampled tracts, draw length-weighted points for ADD, REMOVE, and
  GENERAL (2023 non-CI network).

- Validation point = midpoint of the sampled segment.

<div id="fig-bivariate-map">

<img src="figs/stratified_sample_bivariate_map.png"
data-fig-align="center" />


Figure 2: Stratified sampling bivariate map (density × centrality, 3×3)
with selected validation tracts; inset shows the bivariate legend.

</div>

#### GSV inspection

- Tolerance windows. 2019 condition: 2018–2020; 2023 condition:
  2021–2025.

- Procedure. At each sampled point, inspect both windows; if either
  window is not verifiable, exclude the point from accuracy stats.

- Variables recorded (per year). verifiable\_\[year\] (Y/N),
  presence\_\[year\] (Y/N/NA), notes\_\[year\] (free text).

#### Classification

- OSM-flagged ADD. TP if CI absent in 2019 and present in 2023;
  otherwise FP.

- OSM-flagged REMOVE. TP if CI present in 2019 and absent in 2023;
  otherwise FP.

- GENERAL points. Used to detect FN (true changes that OSM did not
  flag).

- Usable points. Only points with both years verifiable enter
  precision/recall.

<div id="fig-validation-points">

<img src="figs/validation_points_boundary.png"
data-fig-align="center" />


Figure 3: Spatial distribution of validation points across the nine
density–centrality strata in Barcelona (2019–2023).

</div>

#### Performance metrics

- Precision = TP / (TP + FP)

- Recall = TP / (TP + FN)

- F1 = 2·Precision·Recall / (Precision + Recall)

- Notes. Precision is computed on OSM-flagged points (ADD/REMOVE); FN
  comes from GENERAL points. Report metrics by class and pooled, with
  95% CIs.

<!-- ### Uncertainty & stratification -->
<!-- - 95% CIs for proportions: Wilson/score (prop.test(correct=FALSE)). -->
<!-- - By-stratum reporting (centrality × density); if strata imbalanced, compute design-weighted overall. -->
<!-- ### Sensitivity analyses -->
<!-- - Loose FN (ADD): count any verifiable present_2023==TRUE in GENERAL as FN_ADD (regardless of 2019). -->
<!-- - Alternative windows: tighten 2019 to calendar year; set 2023 to 2022–2024. -->
<!-- ### Inter-rater reliability -->
<!-- Double-code ~10–20% of points; report Cohen’s κ (+ % agreement) for presence per year. -->
<!-- #### Calibration -->
<!-- -   Raw OSM change-km were scaled by the validation metrics (precision and recall) to obtain error-adjusted estimates of added and removed cycle infrastructure. -->
<!-- -   Adjustments were computed separately for ADD and REMOVE classes, then aggregated to tract and city level -->

## Results

### OSM-derived change estimates

The OSM cycling network expanded from 214.1 km in 2019 to 263.9 km in
2023 (+49.7 km, ≈23%). Segment differencing suggests 63.4 km were added
and 22.3 km removed (Table 1). Additions were concentrated in dense,
central tracts—especially D3_C3 (36.1% of added km)—while removals were
less frequent and clustered mainly in D1_C3 (61.0%) (Table 2).

<div id="fig-change-map">

<img src="figs/change_map.png" data-fig-align="center" />


Figure 4: Cycling-infrastructure changes detected in OpenStreetMap
between 2019 and 2023 in Barcelona. Additions and removals are shown by
type and spatial distribution.

</div>

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
| TOTAL   |      0 |   0 |       0 |     0 |

Table 3: Validation points by class and stratum (usable points)

| Class | n (usable) | TP | FP | FN (source) | Precision | Precision (95% CI) | Recall | Recall (95% CI) | F1 |
|:---|---:|---:|---:|:---|---:|---:|---:|---:|---:|
| ADD | 0 | 0 | 0 | from GENERAL | NaN | NaN \[NA–NA\] | NaN | NaN \[NA–NA\] | NA |
| REMOVE | 0 | 0 | 0 | from GENERAL | NaN | NaN \[NA–NA\] | NaN | NaN \[NA–NA\] | NA |
| Pooled | 0 | 0 | 0 | from GENERAL | NaN | NaN \[NA–NA\] | NaN | NaN \[NA–NA\] | NA |

Table 4: Validation performance (usable points only)

<!-- ### Error-adjusted change estimates -->
<!-- Calibrated totals after applying validation metrics. -->
<!-- Example table contrasting Raw vs Adjusted at city level (and possibly mean per tract). -->
<!-- Map of tracts showing adjusted changes (before vs after adjustment). -->
<!-- ### Spatial patterns -->
<!-- Highlight clusters of growth or underestimation. -->
<!-- Example: “Adjusted estimates show the largest growth in central tracts, while peripheral areas show smaller net additions once errors are corrected.” -->
<!-- ## Supplements -->
<!-- ### S1. Validation workbook -->
<!-- **Data:** [Download the validation workbook (Excel)](outputs/barcelona_samples_2019_2023.xlsx) -->
<!-- ### S2. Interactive stratification map (density × centrality, 3×3) with sampled tracts -->
<!-- ```{r} -->
<!-- #| label: 17-stratification-map -->
<!-- #| eval: false -->
<!-- #| include: false -->
<!-- # --- Leaflet map matching the static bivariate colours --------------------- -->
<!-- library(sf) -->
<!-- library(leaflet) -->
<!-- library(biscale) -->
<!-- library(htmltools) -->
<!-- library(dplyr) -->
<!-- # 0) Ensure identical classes: reuse bb_bivar from your static pipeline -->
<!-- stopifnot("bi_class" %in% names(bb_bivar)) -->
<!-- # 1) Fix geometry + CRS for leaflet -->
<!-- bb_bivar_ll <- bb_bivar |> -->
<!--   sf::st_make_valid() |> -->
<!--   sf::st_transform(4326) -->
<!-- # (optional) sampled tracts outlines -->
<!-- sampled_ll <- NULL -->
<!-- if (exists("sampled_tracts") && inherits(sampled_tracts, "sf") && nrow(sampled_tracts)) { -->
<!--   sampled_ll <- sampled_tracts |> st_make_valid() |> st_transform(4326) -->
<!-- } -->
<!-- # 2) Build the exact same colour mapping used by bi_scale_fill(pal="DkBlue2", dim=3) -->
<!-- dim_bi  <- 3 -->
<!-- cols    <- biscale::bi_pal("DkBlue2", dim_bi, preview = FALSE) -->
<!-- # Arrange to match the legend orientation (↑ y, → x) used in biscale -->
<!-- M       <- matrix(cols, nrow = dim_bi, byrow = TRUE) -->
<!-- M_flip  <- M[dim_bi:1, ]                            # flip rows so y increases upward -->
<!-- labs_df   <- expand.grid(x = 1:dim_bi, y = 1:dim_bi) -->
<!-- lab_names <- sprintf("%d-%d", labs_df$x, labs_df$y) -->
<!-- lab_cols  <- vapply(seq_len(nrow(labs_df)), function(i) M_flip[labs_df$y[i], labs_df$x[i]], "") -->
<!-- col_lu    <- setNames(lab_cols, lab_names) -->
<!-- # 3) Make sure bi_class is character (not factor), then map colours -->
<!-- bb_bivar_ll <- bb_bivar_ll |> -->
<!--   mutate(bi_class_chr = as.character(bi_class), -->
<!--          fill_col     = unname(col_lu[bi_class_chr]), -->
<!--          fill_col     = ifelse(is.na(fill_col), "#00000000", fill_col)) -->
<!-- # 4) Add a clean bivariate legend that matches the static one -->
<!-- add_bi_legend_leaflet <- function(map, pal = "DkBlue2", dim = 3, -->
<!--                                   position = "bottomright", -->
<!--                                   title = "Density × Centrality", -->
<!--                                   xlab = "Higher Density →", -->
<!--                                   ylab = "More Central ↑", -->
<!--                                   box = 14, gap = 2) { -->
<!--   cols  <- biscale::bi_pal(pal, dim, preview = FALSE) -->
<!--   grid  <- matrix(cols, nrow = dim, byrow = TRUE)[dim:1, ] -->
<!--   cells <- as.vector(t(grid)) -->
<!--   html <- tags$div( -->
<!--     tags$style(HTML(paste0( -->
<!--       ".bi-legend{background:#fff;padding:6px 8px;border-radius:6px;", -->
<!--       "box-shadow:0 1px 4px rgba(0,0,0,.3);font-family:sans-serif}", -->
<!--       ".bi-title{font-weight:600;margin-bottom:4px;font-size:12px}", -->
<!--       ".bi-wrap{display:flex;align-items:center}", -->
<!--       ".bi-grid{display:grid;grid-template-columns:repeat(", dim, ",", box, "px);", -->
<!--       "grid-auto-rows:", box, "px;gap:", gap, "px;margin:0 6px}", -->
<!--       ".bi-cell{width:", box, "px;height:", box, "px}", -->
<!--       ".bi-y{writing-mode:vertical-rl;transform:rotate(180deg);font-size:11px;color:#444}", -->
<!--       ".bi-x{text-align:center;font-size:11px;color:#444;margin-top:4px}" -->
<!--     ))), -->
<!--     tags$div(class = "bi-legend", -->
<!--       tags$div(class = "bi-title", title), -->
<!--       tags$div(class = "bi-wrap", -->
<!--         tags$div(class = "bi-y", ylab), -->
<!--         tags$div(class = "bi-grid", -->
<!--           lapply(cells, function(clr) tags$div(class = "bi-cell", -->
<!--                                                style = paste0("background:", clr, ";"))) -->
<!--         ) -->
<!--       ), -->
<!--       tags$div(class = "bi-x", xlab) -->
<!--     ) -->
<!--   ) -->
<!--   leaflet::addControl(map, html = html, position = position) -->
<!-- } -->
<!-- # 4) Build the leaflet map -->
<!-- m <- leaflet(options = leafletOptions(zoomControl = TRUE)) |> -->
<!--   addProviderTiles("CartoDB.Positron", group = "Positron") |> -->
<!--   addPolygons(data = bb_bivar_ll, -->
<!--               weight = 0.5, color = "#ffffff", opacity = 1, -->
<!--               fillColor = ~fill_col, fillOpacity = 0.9, -->
<!--               smoothFactor = 0.2, -->
<!--               label = ~paste0("Class: ", bi_class_chr)) -->
<!-- if (!is.null(sampled_ll)) { -->
<!--   m <- m |> addPolygons(data = sampled_ll, fill = FALSE, color = "black", weight = 1.2) -->
<!-- } -->
<!-- # 5) Add the same bi-legend as before (already working for you) -->
<!-- m <- add_bi_legend_leaflet(m, pal = "DkBlue2", dim = 3, position = "bottomright") -->
<!-- m -->
<!-- ``` -->
<!-- ### S3. Interactive validation points map (with GSV links) -->
<!-- ```{r} -->
<!-- #| label: 17-validation-map-points -->
<!-- #| echo: false -->
<!-- #| include: false -->
<!-- #| message: false -->
<!-- #| warning: false -->
<!-- # ---- helper: prep points (WGS84 + lon/lat + popup) -------------------------- -->
<!-- prep_pts <- function(x){ -->
<!--   if (!inherits(x,"sf") || !nrow(x)) return(NULL) -->
<!--   w  <- sf::st_transform(x, 4326) -->
<!--   xy <- sf::st_coordinates(w) -->
<!--   good <- is.finite(xy[,1]) & is.finite(xy[,2]) -->
<!--   if (!any(good)) return(NULL) -->
<!--   w   <- w[good, , drop = FALSE] -->
<!--   xy  <- xy[good, , drop = FALSE] -->
<!--   w$lon <- xy[,1]; w$lat <- xy[,2] -->
<!--   w$gsv <- sprintf("https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=%f,%f", xy[,2], xy[,1]) -->
<!--   w$popup <- paste0( -->
<!--     "<b>", w$class, "</b>", -->
<!--     "<br/>tract: ", w$tract_id, -->
<!--     if ("stratum" %in% names(w)) paste0("<br/>stratum: ", w$stratum) else "", -->
<!--     "<br/><a href='", w$gsv, "' target='_blank'>Open GSV</a>" -->
<!--   ) -->
<!--   w -->
<!-- } -->
<!-- add_wgs <- prep_pts(added_pts) -->
<!-- rem_wgs <- prep_pts(removed_pts) -->
<!-- gen_wgs <- prep_pts(gen_pts) -->
<!-- # ---- bounds (prefer city_perimeter -> points -> tracts -> fallback) ---------- -->
<!-- get_bbox <- function(obj) if (inherits(obj, "sf") && nrow(obj)) sf::st_bbox(sf::st_transform(obj, 4326)) else NULL -->
<!-- bb <- NULL -->
<!-- if (exists("city_perimeter") && inherits(city_perimeter, "sf") && nrow(city_perimeter)) { -->
<!--   bb <- get_bbox(city_perimeter) -->
<!-- } else { -->
<!--   bbs <- list() -->
<!--   if (!is.null(add_wgs) && nrow(add_wgs)) bbs <- c(bbs, list(sf::st_bbox(add_wgs))) -->
<!--   if (!is.null(rem_wgs) && nrow(rem_wgs)) bbs <- c(bbs, list(sf::st_bbox(rem_wgs))) -->
<!--   if (!is.null(gen_wgs) && nrow(gen_wgs)) bbs <- c(bbs, list(sf::st_bbox(gen_wgs))) -->
<!--   if (!length(bbs) && exists("tracts") && inherits(tracts,"sf") && nrow(tracts)) { -->
<!--     bbs <- list(get_bbox(tracts)) -->
<!--   } -->
<!--   if (length(bbs)) { -->
<!--     mins <- do.call(pmin, lapply(bbs, function(b) c(b$xmin, b$ymin))) -->
<!--     maxs <- do.call(pmax, lapply(bbs, function(b) c(b$xmax, b$ymax))) -->
<!--     bb <- structure(list(xmin=mins[1], ymin=mins[2], xmax=maxs[1], ymax=maxs[2]), class="bbox") -->
<!--   } else { -->
<!--     bb <- c(xmin = 2.05, ymin = 41.30, xmax = 2.25, ymax = 41.45)  # BCN-ish fallback -->
<!--   } -->
<!-- } -->
<!-- bounds <- unname(c(bb["xmin"], bb["ymin"], bb["xmax"], bb["ymax"])) -->
<!-- # ---- colours ----------------------------------------------------------------- -->
<!-- # points -->
<!-- col_add_pt <- "#E6AB02"  # gold -->
<!-- col_rem_pt <- "#D95F02"  # orange-red -->
<!-- col_gen_pt <- "#1B9E77"  # teal -->
<!-- stroke     <- "#000000" -->
<!-- # tracts -->
<!-- tract_stroke <- "#000000" -->
<!-- tract_fill   <- "#FFFFFF" -->
<!-- # networks (optional) -->
<!-- col_2019_net   <- "#666666" -->
<!-- col_added_net  <- "#D95F02" -->
<!-- col_removedNet <- "#FFFFFF" -->
<!-- col_removedHalo<- "#000000" -->
<!-- col_2023_net   <- "#1B9E77" -->
<!-- col_nonci      <- "#BDBDBD" -->
<!-- # ---- map --------------------------------------------------------------------- -->
<!-- m <- leaflet(options = leafletOptions(preferCanvas = TRUE)) %>% -->
<!--   addProviderTiles("CartoDB.Positron", group = "Positron") -->
<!-- # Barcelona boundary (outline only) -->
<!-- if (exists("city_perimeter") && inherits(city_perimeter, "sf") && nrow(city_perimeter)) { -->
<!--   m <- m %>% -->
<!--     addMapPane("boundaryPane", zIndex = 420) %>% -->
<!--     addPolygons( -->
<!--       data = sf::st_transform(city_perimeter, 4326), -->
<!--       group = "Barcelona boundary", -->
<!--       color = "#111827", weight = 1, opacity = 0.9, -->
<!--       fillColor = "transparent", fillOpacity = 0, -->
<!--       smoothFactor = 0.5 -->
<!--     ) -->
<!-- } -->
<!-- # Tracts polygons (transparent fill, faint outline) -->
<!-- if (exists("tracts") && inherits(tracts,"sf") && nrow(tracts)) { -->
<!--   m <- m %>% -->
<!--     addMapPane("tractsPane", zIndex = 410) %>% -->
<!--     addPolygons( -->
<!--       data = sf::st_transform(tracts, 4326), group = "Tracts", -->
<!--       color = tract_stroke, opacity = 0.7, weight = 0.8, -->
<!--       fillColor = tract_fill, fillOpacity = 0, smoothFactor = 0.5 -->
<!--     ) -->
<!--   # Area labels -->
<!--   tract_centers <- sf::st_point_on_surface(sf::st_transform(tracts, 4326)) -->
<!--   m <- m %>% -->
<!--     addCircleMarkers( -->
<!--       data = tract_centers, group = "Area labels", -->
<!--       radius = 0.1, stroke = FALSE, fillOpacity = 0, -->
<!--       label = ~as.character(tract_id), -->
<!--       labelOptions = labelOptions( -->
<!--         noHide = TRUE, direction = "center", -->
<!--         style = list( -->
<!--           "background"      = "transparent", -->
<!--           "border"          = "none", -->
<!--           "box-shadow"      = "none", -->
<!--           "padding"         = "0px", -->
<!--           "color"           = "rgba(0,0,0,0.25)", -->
<!--           "text-shadow"     = "none", -->
<!--           "pointer-events"  = "none" -->
<!--         ) -->
<!--       ) -->
<!--     ) -->
<!-- } -->
<!-- # Prepare General (non-CI) network (lines only) -->
<!-- gnet <- NULL -->
<!-- if (exists("general23_n") && inherits(general23_n,"sf") && nrow(general23_n)) { -->
<!--   gnet <- general23_n -->
<!-- } else if (exists("noncycle23") && inherits(noncycle23,"sf") && nrow(noncycle23)) { -->
<!--   gnet <- noncycle23 -->
<!-- } -->
<!-- if (!is.null(gnet)) { -->
<!--   keep_lines <- sf::st_geometry_type(gnet, by_geometry = TRUE) %in% c("LINESTRING","MULTILINESTRING") -->
<!--   gnet <- gnet[keep_lines, , drop = FALSE] -->
<!--   if (nrow(gnet)) { -->
<!--     gnet <- suppressWarnings(sf::st_cast(gnet, "LINESTRING")) -->
<!--     gnet <- gnet[!sf::st_is_empty(sf::st_geometry(gnet)), , drop = FALSE] -->
<!--     gnet_wgs <- sf::st_transform(gnet, 4326) -->
<!--   } else { -->
<!--     gnet_wgs <- NULL -->
<!--   } -->
<!-- } else { -->
<!--   gnet_wgs <- NULL -->
<!-- } -->
<!-- # Optional network context (added but hidden by default below) -->
<!-- if (exists("cyc19_n") && inherits(cyc19_n,"sf") && nrow(cyc19_n)) -->
<!--   m <- m %>% addPolylines(data = sf::st_transform(cyc19_n, 4326), group = "2019 net", -->
<!--                           weight = 2, color = col_2019_net, opacity = 0.7) -->
<!-- if (exists("removed") && inherits(removed,"sf") && nrow(removed)) { -->
<!--   m <- m %>% addPolylines(data = sf::st_transform(removed, 4326), group = "Removed net", -->
<!--                           weight = 2.6, color = col_removedHalo, opacity = 0.18) -->
<!--   m <- m %>% addPolylines(data = sf::st_transform(removed, 4326), group = "Removed net", -->
<!--                           weight = 2.0, color = col_removedNet,  opacity = 1.0) -->
<!-- } -->
<!-- if (exists("added") && inherits(added,"sf") && nrow(added)) -->
<!--   m <- m %>% addPolylines(data = sf::st_transform(added, 4326), group = "Added net", -->
<!--                           weight = 2, color = col_added_net, opacity = 0.95) -->
<!-- if (exists("cyc23_n") && inherits(cyc23_n,"sf") && nrow(cyc23_n)) -->
<!--   m <- m %>% addPolylines(data = sf::st_transform(cyc23_n, 4326), group = "2023 net", -->
<!--                           weight = 2, color = col_2023_net, opacity = 0.6) -->
<!-- # Points (explicit lng/lat; active by default) -->
<!-- if (!is.null(add_wgs) && nrow(add_wgs) > 0) -->
<!--   m <- m %>% addCircleMarkers(data = add_wgs, lng = ~lon, lat = ~lat, group = "ADD pts", -->
<!--                               radius = 4, weight = 1, color = stroke, -->
<!--                               fillColor = col_add_pt, fillOpacity = 0.95, -->
<!--                               popup = ~popup) -->
<!-- if (!is.null(rem_wgs) && nrow(rem_wgs) > 0) -->
<!--   m <- m %>% addCircleMarkers(data = rem_wgs, lng = ~lon, lat = ~lat, group = "REMOVE pts", -->
<!--                               radius = 4, weight = 1, color = stroke, -->
<!--                               fillColor = col_rem_pt, fillOpacity = 0.95, -->
<!--                               popup = ~popup) -->
<!-- if (!is.null(gen_wgs) && nrow(gen_wgs) > 0) -->
<!--   m <- m %>% addCircleMarkers(data = gen_wgs, lng = ~lon, lat = ~lat, group = "GENERAL pts", -->
<!--                               radius = 4, weight = 1, color = stroke, -->
<!--                               fillColor = col_gen_pt, fillOpacity = 0.95, -->
<!--                               popup = ~popup) -->
<!-- # General (non-CI) network -->
<!-- if (!is.null(gnet_wgs) && nrow(gnet_wgs)) -->
<!--   m <- m %>% addPolylines(data = gnet_wgs, group = "General (non-CI) net", -->
<!--                           weight = 1, color = col_nonci, opacity = 0.7) -->
<!-- # Control + single legend -->
<!-- m %>% -->
<!--   clearControls() %>% -->
<!--   addLayersControl( -->
<!--     baseGroups = c("Positron"), -->
<!--     overlayGroups = c( -->
<!--       "Barcelona boundary",         # ← boundary as its own layer -->
<!--       "Tracts","Area labels", -->
<!--       "2019 net","Added net","Removed net","2023 net", -->
<!--       "General (non-CI) net", -->
<!--       "ADD pts","REMOVE pts","GENERAL pts" -->
<!--     ), -->
<!--     options = layersControlOptions(collapsed = TRUE) -->
<!--   ) %>% -->
<!--   hideGroup(c("2019 net","Added net","Removed net","2023 net","General (non-CI) net")) %>% -->
<!--   fitBounds(bounds[1], bounds[2], bounds[3], bounds[4]) %>% -->
<!--   addLegend( -->
<!--     position = "bottomright", title = "", -->
<!--     colors = c(col_add_pt, col_rem_pt, col_gen_pt), -->
<!--     labels = c("ADD points", "REMOVE points", "GENERAL points"), -->
<!--     opacity = 1 -->
<!--   ) -->
<!-- ``` -->
<!-- ```{r} -->
<!-- #| label: make-static-validation-map -->
<!-- #| include: false -->
<!-- # Requires: added_pts, removed_pts, gen_pts (from sampling), and sampled_tracts or tracts -->
<!-- # Optionally: city_perimeter (to draw BCN boundary) -->
<!-- suppressPackageStartupMessages({ library(sf); library(ggplot2); library(dplyr) }) -->
<!-- dir.create("figs", showWarnings = FALSE) -->
<!-- # helpers -->
<!-- as_wgs <- function(x){ -->
<!--   if (!inherits(x,"sf") || !nrow(x)) return(NULL) -->
<!--   x <- sf::st_make_valid(x) -->
<!--   x <- x[!sf::st_is_empty(sf::st_geometry(x)), , drop = FALSE] -->
<!--   sf::st_transform(x, 4326) -->
<!-- } -->
<!-- # guards -->
<!-- if (!exists("added_pts"))   added_pts   <- NULL -->
<!-- if (!exists("removed_pts")) removed_pts <- NULL -->
<!-- if (!exists("gen_pts"))     gen_pts     <- NULL -->
<!-- tracts_use <- if (exists("sampled_tracts")) sampled_tracts else if (exists("tracts")) tracts else NULL -->
<!-- # perimeter (optional) -->
<!-- perim_wgs <- if (exists("city_perimeter")) as_wgs(city_perimeter) else NULL -->
<!-- # to WGS84 -->
<!-- add_wgs <- if (!is.null(added_pts)   && nrow(added_pts)   > 0) as_wgs(added_pts)   else NULL -->
<!-- rem_wgs <- if (!is.null(removed_pts) && nrow(removed_pts) > 0) as_wgs(removed_pts) else NULL -->
<!-- gen_wgs <- if (!is.null(gen_pts)     && nrow(gen_pts)     > 0) as_wgs(gen_pts)     else NULL -->
<!-- trs_wgs <- if (!is.null(tracts_use)  && nrow(tracts_use)  > 0) as_wgs(tracts_use)  else NULL -->
<!-- # points + class -->
<!-- pts_list <- list( -->
<!--   if (!is.null(add_wgs)) dplyr::mutate(add_wgs, class = "ADD"), -->
<!--   if (!is.null(rem_wgs)) dplyr::mutate(rem_wgs, class = "REMOVE"), -->
<!--   if (!is.null(gen_wgs)) dplyr::mutate(gen_wgs, class = "GENERAL") -->
<!-- ) -->
<!-- pts_all <- do.call(dplyr::bind_rows, pts_list) -->
<!-- # ---------- OPTION A: zoom-to-points bbox (buffered), clamped to perimeter ---- -->
<!-- make_zoom_bbox <- function(pts, perim = NULL, margin_m = 2000){ -->
<!--   if (is.null(pts) || !inherits(pts,"sf") || !nrow(pts)) return(NULL) -->
<!--   p3857   <- sf::st_transform(pts, 3857)              # metric CRS -->
<!--   buf     <- sf::st_buffer(sf::st_union(p3857), margin_m) -->
<!--   bb_poly <- sf::st_as_sfc(sf::st_bbox(buf))          # bbox polygon in 3857 -->
<!--   bb4326  <- sf::st_transform(bb_poly, 4326) -->
<!--   bb      <- sf::st_bbox(bb4326) -->
<!--   if (!is.null(perim) && inherits(perim,"sf") && nrow(perim)){ -->
<!--     bp <- sf::st_bbox(perim) -->
<!--     bb["xmin"] <- max(bb["xmin"], bp["xmin"]) -->
<!--     bb["ymin"] <- max(bb["ymin"], bp["ymin"]) -->
<!--     bb["xmax"] <- min(bb["xmax"], bp["xmax"]) -->
<!--     bb["ymax"] <- min(bb["ymax"], bp["ymax"]) -->
<!--   } -->
<!--   bb -->
<!-- } -->
<!-- get_bbox <- function(obj) if (!is.null(obj) && inherits(obj,"sf") && nrow(obj)) st_bbox(obj) else NULL -->
<!-- bb <- if (!is.null(pts_all) && nrow(pts_all) > 0) make_zoom_bbox(pts_all, perim_wgs, margin_m = 2000) else NULL -->
<!-- if (is.null(bb)) bb <- get_bbox(perim_wgs) -->
<!-- if (is.null(bb)) bb <- get_bbox(trs_wgs) -->
<!-- if (is.null(bb)) bb <- c(xmin = 2.05, ymin = 41.30, xmax = 2.25, ymax = 41.45) -->
<!-- lims <- list(x = c(bb[["xmin"]], bb[["xmax"]]), y = c(bb[["ymin"]], bb[["ymax"]])) -->
<!-- # colours -->
<!-- cols <- c(ADD = "#E6AB02", REMOVE = "#D95F02", GENERAL = "#1B9E77") -->
<!-- # --- OPTIONAL: base cycle network (use whatever object you have) -------------- -->
<!-- # cyc_wgs <- NULL -->
<!-- # if (exists("cyc19_n")) { -->
<!-- #   cyc_wgs <- as_wgs(cyc19_n) -->
<!-- # } else if (exists("cyc23_n")) { -->
<!-- #   cyc_wgs <- as_wgs(cyc23_n) -->
<!-- # } else if (exists("cyc_network")) { -->
<!-- #   cyc_wgs <- as_wgs(cyc_network) -->
<!-- # } -->
<!-- #  -->
<!-- # # Clip to the city perimeter to avoid clutter outside BCN -->
<!-- # if (!is.null(cyc_wgs) && !is.null(perim_wgs)) { -->
<!-- #   cyc_wgs <- suppressWarnings(sf::st_intersection(cyc_wgs, sf::st_union(perim_wgs))) -->
<!-- # } -->
<!-- p_val <- ggplot() + -->
<!--   # network below everything -->
<!--   # { if (!is.null(cyc_wgs)) -->
<!--   #     geom_sf(data = cyc_wgs, inherit.aes = FALSE, -->
<!--   #             colour = "#9E9E9E", linewidth = 0.35, alpha = 0.5, show.legend = FALSE) } + -->
<!--   # boundary + tracts -->
<!--   { if (!is.null(perim_wgs)) -->
<!--       geom_sf(data = perim_wgs, inherit.aes = FALSE, -->
<!--               fill = NA, colour = "#222222", linewidth = 0.3, show.legend = FALSE) } + -->
<!--   { if (!is.null(trs_wgs)) -->
<!--       geom_sf(data = trs_wgs, inherit.aes = FALSE, -->
<!--               fill = NA, colour = "#B3B3B3", linewidth = 0.25, alpha = 0.4) } + -->
<!--   # points on top -->
<!--   { if (!is.null(pts_all) && nrow(pts_all) > 0) -->
<!--       geom_sf(data = pts_all, aes(fill = class), -->
<!--               colour = "white", shape = 21, size = 3.2, stroke = 0.5) } + -->
<!--   scale_fill_manual(values = cols, name = "Validation class") + -->
<!--   coord_sf(xlim = lims$x, ylim = lims$y, expand = 0) + -->
<!--   theme_void() + -->
<!--   theme( -->
<!--     panel.background = element_rect(fill = "#F7F7F7", colour = NA), -->
<!--     legend.position  = c(0.05, 0.95), -->
<!--     legend.justification = c("left","top"), -->
<!--     legend.background = element_rect(fill = scales::alpha("white", 0.8), colour = "#CCCCCC"), -->
<!--     plot.margin = margin(5,5,5,5) -->
<!--   ) -->
<!-- ggsave("figs/validation_points_boundary.png", p_val, width = 9, height = 7, dpi = 300) -->
<!-- ``` -->
<!-- ### S4. Interactive infrastructure change map (2019→2023) -->
<!-- ```{r} -->
<!-- #| label: 09-map -->
<!-- #| echo: false -->
<!-- #| include: false -->
<!-- #| message: false -->
<!-- #| warning: false -->
<!-- # ---- helper: force WGS84 LINESTRING and skip empties ------------------------- -->
<!-- as_wgs_lines <- function(x){ -->
<!--   if (!inherits(x, "sf") || !nrow(x)) return(NULL) -->
<!--   x <- sf::st_make_valid(x) -->
<!--   keep <- sf::st_geometry_type(x) %in% c("LINESTRING","MULTILINESTRING") -->
<!--   x <- x[keep, , drop = FALSE] -->
<!--   if (!nrow(x)) return(NULL) -->
<!--   x <- suppressWarnings(sf::st_cast(x, "LINESTRING")) -->
<!--   x <- x[!sf::st_is_empty(sf::st_geometry(x)), , drop = FALSE] -->
<!--   if (!nrow(x)) return(NULL) -->
<!--   x <- sf::st_transform(x, 4326) -->
<!--   x -->
<!-- } -->
<!-- as_wgs_poly <- function(x){ -->
<!--   if (!inherits(x, "sf") || !nrow(x)) return(NULL) -->
<!--   x <- sf::st_make_valid(x) -->
<!--   keep <- sf::st_geometry_type(x) %in% c("POLYGON","MULTIPOLYGON") -->
<!--   x <- x[keep, , drop = FALSE] -->
<!--   if (!nrow(x)) return(NULL) -->
<!--   x <- sf::st_transform(x, 4326) -->
<!--   x -->
<!-- } -->
<!-- # ---- colours ----------------------------------------------------------------- -->
<!-- col_2019         <- "#7F7F7F"  # a bit lighter neutral for base 2019 -->
<!-- col_added        <- "#E69F00"  # match ADD across figures (was #E6AB02 on points) -->
<!-- col_removed      <- "#FFFFFF"  # white line (erase look) -->
<!-- col_removed_halo <- "#000000"  # halo -->
<!-- col_2023         <- "#0072B2"  # blue (avoid green here) -->
<!-- col_nonci        <- "#C8C8C8"  # lighter background grey -->
<!-- alpha_2019  <- 0.65   # slightly lower so added/removed pop -->
<!-- alpha_added <- 0.95 -->
<!-- alpha_2023  <- 0.60 -->
<!-- alpha_nonci <- 0.40   # push further into background -->
<!-- alpha_halo  <- 0.25   # a bit stronger to support white line -->
<!-- # ---- prep layers safely ------------------------------------------------------ -->
<!-- perim_wgs   <- if (exists("city_perimeter")) as_wgs_poly(city_perimeter) else NULL -->
<!-- cyc19_wgs   <- if (exists("cyc19_n"))  as_wgs_lines(cyc19_n)  else NULL -->
<!-- added_wgs   <- if (exists("added"))    as_wgs_lines(added)    else NULL -->
<!-- removed_wgs <- if (exists("removed"))  as_wgs_lines(removed)  else NULL -->
<!-- cyc23_wgs   <- if (exists("cyc23_n"))  as_wgs_lines(cyc23_n)  else NULL -->
<!-- nonci_wgs   <- if (exists("general23_n")) as_wgs_lines(general23_n) else NULL -->
<!-- # ---- bounds (prefer perimeter, else any layer, else BCN-ish fallback) -------- -->
<!-- get_bbox <- function(obj) if (!is.null(obj) && inherits(obj,"sf") && nrow(obj)) sf::st_bbox(obj) else NULL -->
<!-- bb <- get_bbox(perim_wgs) -->
<!-- if (is.null(bb)) { -->
<!--   cands <- Filter(Negate(is.null), list(get_bbox(cyc19_wgs), get_bbox(added_wgs), -->
<!--                                         get_bbox(removed_wgs), get_bbox(cyc23_wgs), -->
<!--                                         get_bbox(nonci_wgs))) -->
<!--   if (length(cands)) { -->
<!--     mins <- do.call(pmin, lapply(cands, function(b) c(b$xmin,b$ymin))) -->
<!--     maxs <- do.call(pmax, lapply(cands, function(b) c(b$xmax,b$ymax))) -->
<!--     bb <- structure(list(xmin=mins[1], ymin=mins[2], xmax=maxs[1], ymax=maxs[2]), class="bbox") -->
<!--   } else { -->
<!--     bb <- c(xmin = 2.05, ymin = 41.30, xmax = 2.25, ymax = 41.45) -->
<!--   } -->
<!-- } -->
<!-- bounds <- unname(c(bb["xmin"], bb["ymin"], bb["xmax"], bb["ymax"])) -->
<!-- # ---- map --------------------------------------------------------------------- -->
<!-- m <- leaflet(options = leafletOptions(preferCanvas = TRUE)) %>% -->
<!--   addProviderTiles("CartoDB.Positron", group = "Positron") -->
<!-- if (!is.null(perim_wgs)) -->
<!--   m <- m %>% addPolygons(data = perim_wgs, group = "Boundary", -->
<!--                          weight = 1, color = "#222222", fill = FALSE, fillOpacity = 0) -->
<!-- if (!is.null(cyc19_wgs)) -->
<!--   m <- m %>% addPolylines(data = cyc19_wgs, group = "2019 CI", -->
<!--                           weight = 2, color = col_2019, opacity = alpha_2019) -->
<!-- if (!is.null(removed_wgs)) { -->
<!--   m <- m %>% addPolylines(data = removed_wgs, group = "Removed (19→23)", -->
<!--                           weight = 2, color = col_removed_halo, opacity = alpha_halo) -->
<!--   m <- m %>% addPolylines(data = removed_wgs, group = "Removed (19→23)", -->
<!--                           weight = 2.5, color = col_removed, opacity = 1.0) -->
<!-- } -->
<!-- if (!is.null(added_wgs)) -->
<!--   m <- m %>% addPolylines(data = added_wgs, group = "Added (19→23)", -->
<!--                           weight = 2, color = col_added, opacity = alpha_added) -->
<!-- if (!is.null(cyc23_wgs)) -->
<!--   m <- m %>% addPolylines(data = cyc23_wgs, group = "2023 CI", -->
<!--                           weight = 2, color = col_2023, opacity = alpha_2023) -->
<!-- if (!is.null(nonci_wgs)) -->
<!--   m <- m %>% addPolylines(data = nonci_wgs, group = "General (non-CI) 2023", -->
<!--                           weight = 1, color = col_nonci, opacity = alpha_nonci, -->
<!--                           smoothFactor = 0.5) -->
<!-- m %>% -->
<!--   addLayersControl( -->
<!--     baseGroups = c("Positron"), -->
<!--     overlayGroups = c("Boundary","2019 CI","Added (19→23)","Removed (19→23)","2023 CI","General (non-CI) 2023"), -->
<!--     options = layersControlOptions(collapsed = TRUE) -->
<!--   ) %>% -->
<!--   hideGroup(c("2023 CI","General (non-CI) 2023")) %>% -->
<!--   fitBounds(bounds[1], bounds[2], bounds[3], bounds[4]) %>% -->
<!--   addLegend( -->
<!--     position = "bottomright", title = "Layers", -->
<!--     colors = c(col_2019, col_added, col_removed), -->
<!--     labels = c("2019 CI","Added (19→23)","Removed (19→23)"), -->
<!--     opacity = 1 -->
<!--   ) -->
<!-- ``` -->
<!-- ```{r} -->
<!-- #| label: make-static-infra-map -->
<!-- #| include: false -->
<!-- # Requires: cyc19_n, added, removed (built earlier), and optionally city_perimeter -->
<!-- suppressPackageStartupMessages({ library(sf); library(ggplot2); library(dplyr) }) -->
<!-- dir.create("figs", showWarnings = FALSE) -->
<!-- # helpers -->
<!-- as_wgs <- function(x){ -->
<!--   if (!inherits(x,"sf") || !nrow(x)) return(NULL) -->
<!--   x <- sf::st_make_valid(x) -->
<!--   x <- x[!sf::st_is_empty(sf::st_geometry(x)), , drop = FALSE] -->
<!--   sf::st_transform(x, 4326) -->
<!-- } -->
<!-- # prepare layers (WGS84) -->
<!-- perim_wgs   <- if (exists("city_perimeter")) as_wgs(city_perimeter) else NULL -->
<!-- cyc19_wgs   <- if (exists("cyc19_n"))  as_wgs(cyc19_n)  else NULL -->
<!-- added_wgs   <- if (exists("added"))    as_wgs(added)    else NULL -->
<!-- removed_wgs <- if (exists("removed"))  as_wgs(removed)  else NULL -->
<!-- # bounds -->
<!-- get_bbox <- function(obj) if (!is.null(obj) && inherits(obj,"sf") && nrow(obj)) st_bbox(obj) else NULL -->
<!-- bb <- get_bbox(perim_wgs) -->
<!-- if (is.null(bb)) { -->
<!--   cands <- Filter(Negate(is.null), list(get_bbox(cyc19_wgs), get_bbox(added_wgs), get_bbox(removed_wgs))) -->
<!--   if (length(cands)) { -->
<!--     mins <- do.call(pmin, lapply(cands, function(b) c(b$xmin,b$ymin))) -->
<!--     maxs <- do.call(pmax, lapply(cands, function(b) c(b$xmax,b$ymax))) -->
<!--     bb <- structure(list(xmin=mins[1], ymin=mins[2], xmax=maxs[1], ymax=maxs[2]), class="bbox") -->
<!--   } else { -->
<!--     bb <- c(xmin = 2.05, ymin = 41.30, xmax = 2.25, ymax = 41.45) -->
<!--   } -->
<!-- } -->
<!-- lims <- list(x = c(bb[["xmin"]], bb[["xmax"]]), y = c(bb[["ymin"]], bb[["ymax"]])) -->
<!-- # colours -->
<!-- col_2019  <- "#7F7F7F" -->
<!-- col_added <- "#E69F00" -->
<!-- col_white <- "#FFFFFF" -->
<!-- col_halo  <- "#000000" -->
<!-- # legend colours -->
<!-- leg_cols <- c( -->
<!--   "2019 CI"                = col_2019, -->
<!--   "Added (19→23)"          = col_added, -->
<!--   "Removed (white + halo)" = col_white   # CHANGED: label mentions halo -->
<!-- ) -->
<!-- p <- ggplot() + -->
<!--   # perimeter (no legend) -->
<!--   { if (!is.null(perim_wgs)) geom_sf( -->
<!--       data = perim_wgs, inherit.aes = FALSE, -->
<!--       fill = NA, colour = "#222222", linewidth = 0.2, show.legend = FALSE) } + -->
<!--   # 2019 network -->
<!--   { if (!is.null(cyc19_wgs)) geom_sf( -->
<!--       data = cyc19_wgs, aes(color = "2019 CI"), -->
<!--       linewidth = 0.4, alpha = 0.85) } + -->
<!--   # added -->
<!--   { if (!is.null(added_wgs)) geom_sf( -->
<!--       data = added_wgs, aes(color = "Added (19→23)"), -->
<!--       linewidth = 0.6, alpha = 0.95) } +   # CHANGED: slightly thicker -->
<!--   # removed: thicker/stronger halo + white line with legend label -->
<!--   { if (!is.null(removed_wgs)) geom_sf( -->
<!--       data = removed_wgs, inherit.aes = FALSE, -->
<!--       colour = col_halo, linewidth = 1.2, alpha = 0.28, show.legend = FALSE) } +  # CHANGED: wider halo + higher alpha -->
<!--   { if (!is.null(removed_wgs)) geom_sf( -->
<!--       data = removed_wgs, aes(color = "Removed (white + halo)"), -->
<!--       linewidth = 0.7, alpha = 1.00) } + -->
<!--   scale_color_manual( -->
<!--     values = leg_cols, breaks = names(leg_cols), -->
<!--     guide = guide_legend( -->
<!--       title = "Layers", -->
<!--       override.aes = list(linewidth = 1.8)   # CHANGED: bigger legend stroke -->
<!--     ) -->
<!--   ) + -->
<!--   coord_sf(xlim = lims$x, ylim = lims$y, expand = 0) + -->
<!--   theme_void() + -->
<!--   theme( -->
<!--     panel.background = element_rect(fill = "#F7F7F7", colour = NA), -->
<!--     legend.position = "inside", -->
<!--     legend.position.inside = c(0.02, 0.98), -->
<!--     legend.justification = c("left","top"), -->
<!--     legend.background = element_rect(fill = scales::alpha("white", 0.85), colour = "#CCCCCC"), -->
<!--     legend.key = element_rect(fill = "#D9D9D9", colour = NA),   # CHANGED: darker key so white line is visible -->
<!--     plot.margin = margin(5,5,5,5) -->
<!--   ) -->
<!-- ggsave("figs/change_map.png", p, width = 9, height = 7, dpi = 300) -->
<!-- ``` -->
<!-- <!-- ## References -->
