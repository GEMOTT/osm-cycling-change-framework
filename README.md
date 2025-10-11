

<link href="README_files/libs/htmltools-fill-0.5.8.1/fill.css" rel="stylesheet" />
<script src="README_files/libs/htmlwidgets-1.6.4/htmlwidgets.js"></script>
<script src="README_files/libs/jquery-3.6.0/jquery-3.6.0.min.js"></script>
<link href="README_files/libs/leaflet-1.3.1/leaflet.css" rel="stylesheet" />
<script src="README_files/libs/leaflet-1.3.1/leaflet.js"></script>
<link href="README_files/libs/leafletfix-1.0.0/leafletfix.css" rel="stylesheet" />
<script src="README_files/libs/proj4-2.6.2/proj4.min.js"></script>
<script src="README_files/libs/Proj4Leaflet-1.0.1/proj4leaflet.js"></script>
<link href="README_files/libs/rstudio_leaflet-1.3.1/rstudio_leaflet.css" rel="stylesheet" />
<script src="README_files/libs/leaflet-binding-2.2.2/leaflet.js"></script>
<script src="README_files/libs/leaflet-providers-2.0.0/leaflet-providers_2.0.0.js"></script>
<script src="README_files/libs/leaflet-providers-plugin-2.2.2/leaflet-providers-plugin.js"></script>


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

## Data and methods

### Data sources

- OpenStreetMap (OSM): open, collaboratively mapped vector data with
  tags for cycling infra.

- Google Street View (GSV): geotagged, time-stamped street-level
  imagery. (Right now they’re just headings.)

### Methods

<img src="figs/osm_gsv_flowchart.png" data-fig-align="center"
alt="Analytical workflow showing the main steps for detecting and validating cycling-infrastructure changes in Barcelona (2019–2023)." />

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

<img src="figs/stratified_sample_bivariate_map.png"
data-fig-align="center"
alt="Stratified sampling bivariate map (density × centrality, 3×3) with selected validation tracts; inset shows the bivariate legend." />

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

<img src="figs/validation_points_boundary.png" data-fig-align="center"
alt="Spatial distribution of validation points across the nine density–centrality strata in Barcelona (2019–2023)." />

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

<img src="figs/change_map.png" data-fig-align="center"
alt="Cycling-infrastructure changes detected in OpenStreetMap between 2019 and 2023 in Barcelona. Additions and removals are shown by type and spatial distribution." />

| Metric                     | Value |
|:---------------------------|------:|
| Total 2019 (km)            | 214.1 |
| Total 2023 (km)            | 263.9 |
| Net growth (km)            |  49.7 |
| Added (km)                 |  65.8 |
| Removed (km)               |  23.1 |
| Added − Removed (km)       |  42.7 |
| Gap: (Added−Removed) − Net |  -7.0 |

Table 1: Consistency between yearly totals and differencing estimates
(2019–2023, Barcelona)

| stratum | Added_km | Removed_km | Added_pct | Removed_pct |
|:--------|---------:|-----------:|----------:|------------:|
| D1_C1   |      0.2 |        0.0 |      7.8% |        2.0% |
| D1_C2   |      0.5 |        0.1 |     19.8% |        4.2% |
| D1_C3   |      0.6 |        0.8 |     22.8% |       62.4% |
| D2_C1   |      0.0 |        0.1 |      0.0% |        7.4% |
| D2_C2   |      0.1 |        0.2 |      4.3% |       13.2% |
| D2_C3   |      0.1 |        0.1 |      4.6% |       10.8% |
| D3_C1   |      0.2 |        0.0 |      8.1% |        0.0% |
| D3_C2   |      0.4 |        0.0 |     17.1% |        0.0% |
| D3_C3   |      0.4 |        0.0 |     15.5% |        0.0% |

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
| D1_C1   |      1 |   0 |       0 |     1 |
| D1_C2   |      1 |   3 |       4 |     8 |
| D1_C3   |      1 |   2 |       3 |     6 |
| D2_C1   |      1 |   0 |       0 |     1 |
| D2_C2   |      1 |   1 |       2 |     4 |
| D2_C3   |      0 |   1 |       2 |     3 |
| D3_C1   |      0 |   1 |       2 |     3 |
| D3_C2   |      0 |   2 |       2 |     4 |
| D3_C3   |      0 |   5 |       5 |    10 |
| TOTAL   |      5 |  15 |      20 |    40 |

Table 3: Validation points by class and stratum (usable points)

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

### S3. Interactive validation points map (with GSV links)

<!-- ### S4. Interactive infrastructure change map (2019→2023) -->
<!-- ```{r} -->
<!-- #| label: 29-infra-change-map-interactive -->
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
<!-- #| label: 30-infra-change-map-static-built -->
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
