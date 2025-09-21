

🔗 Part of the [ATRAPA database
project](https://github.com/GEMOTT/atrapa_database)  
⬅️ [Back to project
overview](https://github.com/GEMOTT/atrapa%20database) ➡️ [Next repo
related: Electoral and socioeconomic
data](https://github.com/GEMOTT/electoral-socioeconomic-data)

# Can OpenStreetMap Reliably Track Changes in Active Travel Infrastructure? Evidence from Barcelona with GSV Validation

## Introduction

The relationship between the built environment and travel behaviour has
been widely studied, with many studies identifying associations between
environmental characteristics and travel patterns (Cerin et al. 2017;
Ding et al. 2011; Zhang et al. 2022). However, most research relies on
cross-sectional data, which cannot establish causality (McCormack and
Shiell 2011; Coevering, Maat, and Wee 2015). In contrast, studies that
track changes in both travel behaviour and the built environment—such as
longitudinal studies and natural experiments—offer stronger causal
insights but remain relatively scarce (Kärmeniemi et al. 2018; Smith et
al. 2017; Tcymbal et al. 2020).

One of the main challenges in expanding this area of research is the
limited availability of consistent, time-series data on the built
environment. While historical data on travel behaviour is often more
accessible—through sources like censuses, surveys, and increasingly,
crowdsourced platforms like Strava—comparable records of past urban
infrastructure are much harder to obtain. Long-term records of active
travel networks, though consistent and accessible historical data
remains limited and varies across cities, which hinders broader or
international comparisons. An alternative is to reconstruct historical
built environment data manually using maps, satellite imagery, and
planning records, but this process is highly resource-intensive and
typically limited in scale.

The growing availability of Volunteered Geographic Information (VGI)
presents new opportunities to overcome data limitations in built
environment research. Among these sources, OpenStreetMap (OSM) stands
out for providing open, editable, and historical data on various types
of infrastructure, making it a promising tool for analysing urban
transformations over time. However, its application in this context
requires careful validation due to well-documented limitations in
accuracy, completeness, and temporal consistency (Barron, Neis, and Zipf
2014).

While OSM has been widely used for mapping infrastructure and supporting
routing applications, its utility for analysing changes in
infrastructure over time is less well established. This study seeks to
evaluate how accurately historical OSM data reflects changes in active
travel infrastructure—specifically bike lanes, pedestrian streets, and
living streets. We propose and apply a semi-automated validation method
that compares reported OSM changes against external reference sources,
including street-level imagery (Google Street View), satellite imagery,
and official municipal records.

Focusing on the city of Barcelona, our approach uses stratified sampling
to ensure spatial and socio-demographic diversity. While the analysis is
limited to one city, the proposed framework is designed to be scalable
and transferable, offering a practical methodology for researchers and
planners seeking to monitor infrastructure change over time using open
data sources.

This study builds on recent efforts to assess OSM’s data quality and
potential for infrastructure analysis, with particular attention to its
capacity to represent change over time.

## Data and Method

### Data Sources

- OpenStreetMap (OSM) snapshots: 2015, 2019, 2023
- Google Street View (GSV) imagery

### Sampling Strategy

- Unit of analysis: Census tracts (80 in total, Barcelona, 2015
  boundaries)
- Stratification variables:
  - Population density (2022 estimates)
  - Centrality: Euclidean distance from Plaça Catalunya, the city center

### Change Detection in OSM

- Extract infrastructure from OSM for 2015, 2019, 2023
  - Focus tags: highway=cycleway, cycleway=\*, highway=pedestrian,
    highway=living_street
- Compare time periods:
  - Period 1: 2015–2019
  - Period 2: 2019–2023
- Identify changes:
  - Additions
  - Removals
  - Reclassifications

### Validation Strategy

#### OSM-Reported Changes (False Positives)

- Use GSV imagery and satellite views to verify all detected changes
- Label each as:
  - ✅ Confirmed
  - ❌ False Positive +❓ Uncertain

#### Missed Changes (False Negatives)

- Sample ~100 street segments from within census tract sample
- For each segment, check imagery to see if:
  - Infrastructure exists in reality
  - But is missing from OSM

### Evaluation Metrics

- Accuracy = Confirmed OSM changes / All OSM-reported changes
- Completeness = Confirmed OSM changes / (Confirmed + Missed changes)
- SCI (Spatial Completeness Index) = Variation in completeness across
  tracts (e.g., standard deviation)

### Inclusion Criteria

- Include city/period/type only if:
  - Completeness ≥ 80%
  - SCI ≤ 15%
- Based on prior studies:
  - Hochmair et al. (2014), Barron et al. (2014), Elwood & Goodchild
    (2013)

#### Example Evaluation Table by Interval and Infrastructure Type

| City      | Interval  | Type           | Completeness | SCI    | Accuracy | Decision   |
|-----------|-----------|----------------|--------------|--------|----------|------------|
| Barcelona | 2015–2019 | Bike Lanes     | 88% ✅       | 9% ✅  | 91% ✅   | ✅ Include |
| Barcelona | 2015–2019 | Pedestrian     | 84% ✅       | 12% ✅ | 87% ✅   | ✅ Include |
| Barcelona | 2015–2019 | Living Streets | 72% ❌       | 18% ❌ | 78% ❌   | ❌ Exclude |

## Results

### Descriptive analyses

``` r
samples_all_wgs   <- readRDS("data/samples_all_wgs.rds")

#| include: false
desired_n <- 3
min_year  <- 2023

# Ensure gsv_year exists
samples_all_wgs <- samples_all_wgs %>%
  mutate(gsv_year = suppressWarnings(as.integer(substr(gsv_date, 1, 4))))

# 1) Up to 3 recent (≥ 2023) per group
recent <- samples_all_wgs %>%
  filter(!is.na(gsv_year) & gsv_year >= min_year) %>%
  group_by(tract_id, source) %>%
  mutate(.rand = runif(dplyr::n())) %>%
  arrange(.by_group = TRUE, .rand) %>%
  slice_head(n = desired_n) %>%
  ungroup() %>%
  select(-.rand)

# 2) Groups that still need filling (make non-sf!)
needs <- samples_all_wgs %>%
  st_drop_geometry() %>%
  group_by(tract_id, source) %>%
  summarise(n_recent = sum(!is.na(gsv_year) & gsv_year >= min_year), .groups = "drop") %>%
  mutate(to_fill = pmax(0, desired_n - n_recent)) %>%
  filter(to_fill > 0)

# 3) Back-fill with most recent < 2023 (or NA)
fallback <- samples_all_wgs %>%
  filter(is.na(gsv_year) | gsv_year < min_year) %>%
  inner_join(needs, by = c("tract_id","source")) %>%
  group_by(tract_id, source) %>%
  arrange(desc(coalesce(gsv_year, -Inf)), .by_group = TRUE) %>%
  mutate(.rk = row_number()) %>%
  filter(.rk <= first(to_fill)) %>%
  ungroup() %>%
  select(-.rk, -n_recent, -to_fill)

# 4) Final set
samples_3each <- bind_rows(recent, fallback)

# Check: ≤ 3 per (tract_id × source)
samples_3each %>% count(tract_id, source) %>% arrange(desc(n))
```

    Simple feature collection with 74 features and 3 fields
    Geometry type: MULTIPOINT
    Dimension:     XY
    Bounding box:  xmin: 2.104151 ymin: 41.37107 xmax: 2.209253 ymax: 41.45902
    Geodetic CRS:  WGS 84
    # A tibble: 74 × 4
       tract_id source           n                                          geometry
          <int> <chr>        <int>                                  <MULTIPOINT [°]>
     1        1 osm_cycleway     3 ((2.112029 41.3909), (2.112235 41.39107), (2.112…
     2        1 osm_general      3 ((2.107163 41.39041), (2.107965 41.38956), (2.10…
     3        2 osm_general      3 ((2.171181 41.42685), (2.171866 41.42353), (2.17…
     4        3 osm_cycleway     3 ((2.180506 41.45836), (2.180518 41.45843), (2.18…
     5        3 osm_general      3 ((2.184811 41.45714), (2.180861 41.459), (2.1809…
     6        4 osm_cycleway     3 ((2.140654 41.41358), (2.1428 41.41261), (2.1427…
     7        4 osm_general      3 ((2.143615 41.41223), (2.143548 41.41226), (2.14…
     8        5 osm_general      3 ((2.209253 41.42355), (2.207708 41.42275), (2.20…
     9        6 osm_cycleway     3 ((2.134062 41.39004), (2.13214 41.38955), (2.137…
    10        6 osm_general      3 ((2.132201 41.38956), (2.135704 41.39045), (2.13…
    # ℹ 64 more rows

``` r
saveRDS(samples_3each,  "data/samples_3each.rds")
```

    file:////tmp/RtmpKKuZYQ/file5115b82c3684/widget5115b67ec4c9a.html screenshot completed

![](README_files/figure-commonmark/unnamed-chunk-11-1.png)

<!-- <iframe src="figs/final_map_interactive.html" width="100%" height="600px"></iframe> -->

## References

<div id="refs" class="references csl-bib-body hanging-indent"
entry-spacing="0">

<div id="ref-barron_comprehensive_2014" class="csl-entry">

Barron, Christopher, Pascal Neis, and Alexander Zipf. 2014. “A
Comprehensive Framework for Intrinsic OpenStreetMap Quality Analysis.”
*Transactions in GIS* 18 (6): 877–95.
<https://doi.org/10.1111/tgis.12073>.

</div>

<div id="ref-cerin_neighbourhood_2017" class="csl-entry">

Cerin, Ester, Andrea Nathan, Jelle van Cauwenberg, David W. Barnett,
Anthony Barnett, and on behalf of the Council on Environment and
Physical Activity (CEPA) – Older Adults working group. 2017. “The
Neighbourhood Physical Environment and Active Travel in Older Adults: A
Systematic Review and Meta-Analysis.” *International Journal of
Behavioral Nutrition and Physical Activity* 14 (1): 15.
<https://doi.org/10.1186/s12966-017-0471-5>.

</div>

<div id="ref-coevering_multi-period_2015" class="csl-entry">

Coevering, Paul van de, Kees Maat, and Bert van Wee. 2015. “Multi-Period
Research Designs for Identifying Causal Effects of Built Environment
Characteristics on Travel Behaviour.” *Transport Reviews*, July.
<https://www.tandfonline.com/doi/full/10.1080/01441647.2015.1025455>.

</div>

<div id="ref-ding_neighborhood_2011" class="csl-entry">

Ding, Ding, James F. Sallis, Jacqueline Kerr, Suzanna Lee, and Dori E.
Rosenberg. 2011. “Neighborhood Environment and Physical Activity Among
Youth.” *American Journal of Preventive Medicine* 41 (4): 442–55.
<https://doi.org/10.1016/j.amepre.2011.06.036>.

</div>

<div id="ref-karmeniemi_built_2018" class="csl-entry">

Kärmeniemi, Mikko, Tiina Lankila, Tiina Ikäheimo, Heli
Koivumaa-Honkanen, and Raija Korpelainen. 2018. “The Built Environment
as a Determinant of Physical Activity: A Systematic Review of
Longitudinal Studies and Natural Experiments.” *Annals of Behavioral
Medicine* 52 (3): 239–51. <https://doi.org/10.1093/abm/kax043>.

</div>

<div id="ref-mccormack_search_2011" class="csl-entry">

McCormack, Gavin R., and Alan Shiell. 2011. “In Search of Causality: A
Systematic Review of the Relationship Between the Built Environment and
Physical Activity Among Adults.” *International Journal of Behavioral
Nutrition and Physical Activity* 8 (1): 125.
<https://doi.org/10.1186/1479-5868-8-125>.

</div>

<div id="ref-smith_systematic_2017" class="csl-entry">

Smith, Melody, Jamie Hosking, Alistair Woodward, Karen Witten, Alexandra
MacMillan, Adrian Field, Peter Baas, and Hamish Mackie. 2017.
“Systematic Literature Review of Built Environment Effects on Physical
Activity and Active Transport – an Update and New Findings on Health
Equity.” *International Journal of Behavioral Nutrition and Physical
Activity* 14 (1): 158. <https://doi.org/10.1186/s12966-017-0613-9>.

</div>

<div id="ref-tcymbal_effects_2020" class="csl-entry">

Tcymbal, Antonina, Yolanda Demetriou, Anne Kelso, Laura Wolbring,
Kathrin Wunsch, Hagen Wäsche, Alexander Woll, and Anne K. Reimers. 2020.
“Effects of the Built Environment on Physical Activity: A Systematic
Review of Longitudinal Studies Taking Sex/Gender into Account.”
*Environmental Health and Preventive Medicine* 25 (1): 75.
<https://doi.org/10.1186/s12199-020-00915-z>.

</div>

<div id="ref-zhang_impact_2022" class="csl-entry">

Zhang, Yufang, Marijke Koene, Sijmen A. Reijneveld, Jolanda Tuinstra,
Manda Broekhuis, Stefan van der Spek, and Cor Wagenaar. 2022. “The
Impact of Interventions in the Built Environment on Physical Activity
Levels: A Systematic Umbrella Review.” *International Journal of
Behavioral Nutrition and Physical Activity* 19 (1): 156.
<https://doi.org/10.1186/s12966-022-01399-6>.

</div>

</div>
