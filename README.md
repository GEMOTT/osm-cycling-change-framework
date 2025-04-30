

🔗 Part of the [ATRAPA database
project](https://github.com/GEMOTT/atrapa_database)  
⬅️ [Back to project
overview](https://github.com/GEMOTT/atrapa%20database) ➡️ [Next repo
related: Electoral and socioeconomic
data](https://github.com/GEMOTT/electoral-socioeconomic-data)

# Evaluating OpenStreetMap for Tracking Active Travel Infrastructure Changes: A Multi-City Validation Across Seven European Cities

## Introduction

The relationship between the built environment and travel behaviour has
been widely studied, with many studies identifying associations between
environmental characteristics and travel patterns (Cerin et al. 2017;
Ding et al. 2011; Zhang et al. 2022). However, most research relies on
cross-sectional data, which cannot establish causality (McCormack and
Shiell 2011; Coevering, and Wee 2015). In contrast, studies that track
changes in both travel behaviour and the built environment—such as
longitudinal studies and natural experiments—offer stronger causal
insights but remain relatively scarce (Kärmeniemi et al. 2018; Smith et
al. 2017; Tcymbal et al. 2020).

One of the main challenges in expanding this area of research is the
limited availability of consistent, time-series data on the built
environment. While historical data on travel behaviour is often more
accessible—through sources like censuses, surveys, and increasingly,
crowdsourced platforms like Strava—comparable records of past urban
infrastructure are much harder to obtain. Some national road
datasets—such as those in Sweden, the Netherlands, Finland, Denmark, and
Norway—include long-term records of active travel networks, though
consistent and accessible historical data remains limited and varies
across countries, which hinders broader or international comparisons. An
alternative is to reconstruct historical built environment data manually
using maps, satellite imagery, and planning records, but this process is
highly resource-intensive and typically limited in scale.

The growing availability of Volunteered Geographic Information (VGI)
presents new opportunities to overcome data limitations in built
environment research. Among these sources, OpenStreetMap (OSM) stands
out for providing open, editable, and historical data on various types
of infrastructure, making it a promising tool for analysing urban
transformations over time. However, its application in this context
requires careful validation due to well-documented limitations in
accuracy, completeness, and temporal consistency (Barron, Neis, and Zipf
2014; Zielstra and Zipf, n.d.).

While OSM has been widely used to assess infrastructure coverage and
routing potential, its reliability for capturing historical
transformations—especially in pedestrian-oriented infrastructure—remains
unclear. This study aims to evaluate the extent to which historical OSM
data can reliably capture urban transformations in active travel
infrastructure—such as bike lanes, pedestrian streets, and living
streets—across multiple European cities. We develop and apply a
semi-automated validation method that compares reported changes in OSM
to external reference sources, including street-level and satellite
imagery as well as official records. The analysis focuses on seven
cities selected for their relevance to a broader research initiative and
uses stratified sampling to reflect socio-demographic and spatial
diversity. While the present study is limited to these cases, the
framework is designed to be scalable and transferable, offering a
practical tool for researchers and planners seeking to monitor
infrastructure change over time.

This study builds on recent efforts to assess OSM’s data quality and
potential for infrastructure analysis, with particular attention to its
capacity to represent change over time.

## Literature review

<!-- Perhaps the important is not studies analysing historical OSM but completeness per network -->

OSM is often used to study transport infrastructure—especially cycling
networks—but few studies examine how these networks change over time. A
countrywide assessment in Denmark found that neither OSM nor the
official GeoDanmark dataset alone provided complete coverage;
feature-level conflation was necessary to improve reliability,
especially in rural areas (Vierø, Vybornova, and Szell 2025). Viero et
al. also introduced BikeDNA, an open-source tool that validates OSM
cycling data with attention to network topology, local completeness, and
spatial variation (Vierø, Vybornova, and Szell 2024). Similarly, Ferster
et al. compared OSM with municipal datasets in six Canadian cities and
found high agreement in total network length, though accuracy varied by
infrastructure type—especially for newer or inconsistently tagged
features (Ferster et al. 2023). These studies underscore both the
promise and the limitations of OSM for cycling infrastructure research.

In contrast, pedestrian networks—especially pedestrianized and living
streets—have received significantly less attention in OSM validation
studies. While some efforts have focused on sidewalks or routing
networks (e.g. Zielstra and Hochmair (2012);
https://wiki.openstreetmap.org/wiki/OpenSidewalks), few have assessed
whether OSM reliably represents pedestrianized streets (e.g.,
highway=pedestrian) or living streets (highway=living_street), or
whether these features accurately reflect real-world transformations
over time. These types of infrastructure are increasingly relevant for
sustainable mobility but pose unique challenges for mapping and
validation due to tagging ambiguity and definitional variation across
contexts (National Technical University of Athens, Greece 2022; Omar et
al. 2022).

Taken together, these studies demonstrate that OSM is a promising yet
uneven source for analyzing changes in the built environment. However,
most existing research focuses on static comparisons, routing
applications, or cycling-specific infrastructure—often within single
cities or countries. Very few studies assess OSM’s ability to capture
infrastructure transformations over time, particularly for
underrepresented networks like pedestrian and living streets. Our study
addresses this gap by developing a validation framework that compares
reported OSM transformations to multiple external sources—Google Street
View, and satellite imagery—across seven European cities. In doing so,
we assess the temporal completeness, spatial variation, and overall
reliability of OSM as a longitudinal dataset for tracking changes in
active travel infrastructure.

## Data and Method

### Data Sources

- OpenStreetMap (OSM) snapshots: 2015, 2019, 2023
- Google Street View (GSV) imagery
- Satellite imagery

### Sampling Strategy

- Unit: census tracts (~60 per city)
- Sampling: stratified random
- Stratification based on:
- Urban form: center, middle, periphery
- Socio-demographics: income level or population density

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

- Validate all reported changes using:
  - GSV for visual confirmation
  - Satellite imagery for layout verification
- Label each as:
  - ✅ Confirmed
  - ❌ False Positive +❓ Uncertain

#### Missed Changes (False Negatives)

- Sample ~100 street segments per city from within census tract sample
- For each segment, check imagery to see if:
  - Infrastructure exists in reality
  - But is missing from OSM
- Use findings to estimate completeness

### Evaluation Metrics

- Accuracy = Confirmed OSM changes / All OSM-reported changes
- Completeness = Confirmed OSM changes / (Confirmed + Missed changes)
- SCI = Variation in completeness across tracts (e.g., standard
  deviation)

### Inclusion Criteria

- Include city/period/type only if:
  - Completeness ≥ 80%
  - SCI ≤ 15%
- Based on prior studies:
  - Hochmair et al. (2014), Barron et al. (2014), Elwood & Goodchild
    (2013)

#### Example Evaluation Table by Interval and Infrastructure Type

| City      | Interval  | Type           | Completeness | SCI    | Accuracy | Decision       |
|-----------|-----------|----------------|--------------|--------|----------|----------------|
| Barcelona | 2015–2019 | Bike Lanes     | 88% ✅       | 9% ✅  | 91% ✅   | ✅ Include     |
| Barcelona | 2015–2019 | Pedestrian     | 84% ✅       | 12% ✅ | 87% ✅   | ✅ Include     |
| Barcelona | 2015–2019 | Living Streets | 72% ❌       | 18% ❌ | 78% ❌   | ❌ Exclude     |
| Paris     | 2019–2023 | Bike Lanes     | 78% ❌       | 14% ✅ | 82% ✅   | ⚠️ Conditional |
| Paris     | 2019–2023 | Pedestrian     | 83% ✅       | 17% ❌ | 85% ✅   | ⚠️ Conditional |
| Warsaw    | 2015–2019 | Bike Lanes     | 70% ❌       | 10% ✅ | 75% ❌   | ❌ Exclude     |
| Milan     | 2019–2023 | Bike Lanes     | 90% ✅       | 11% ✅ | 89% ✅   | ✅ Include     |

## Results

<!-- Similar studies: -->
<!-- Using OpenStreetMap Point-of-Interest Data to Model Urban Change—A Feasibility Study: DOI: 10.1371/journal.pone.0212606 -->
<!-- Using OpenStreetMap to Inventory Bicycle Infrastructure: A Comparison with Open Data from Cities: DOI: 10.1080/15568318.2018.1519746 -->
<!-- How Good Is Open Bicycle Infrastructure Data? A Countrywide Case Study of Denmark: DOI: 10.1111/gean.12400 -->
<!-- BikeDNA: A Tool for Bicycle Infrastructure Data & Network Assessment: DOI: 10.1177/23998083231184471 -->
<!-- By addressing these aspects, we aim to help researchers and practitioners effectively use OSM while critically assessing its suitability for tracking infrastructure changes over time [@koukoletsos_assessing_2012]. -->
<!-- -   Aim: Develop a dataset capturing changes in the built environment that support active travel in Barcelona, Milan, Ljubljana, Warsaw, Utrecht, Malmö, and Paris. -->
<!-- -   Key Elements: -->
<!--     -   Cycleways -->
<!--     -   Pedestrian & living streets -->
<!--     -   Pavement widenings/extensions (more challenging to track) -->
<!-- -   Data Sources: Official Open Data and OpenStreetMap (OSM). -->
<!-- | Aspect | Official Open Data | OSM | -->
<!-- |-----------------------|-----------------------|--------------------------| -->
<!-- | **Accessibility** | Harder to obtain (data often not preserved) | Easy access with `osmextract` | -->
<!-- | **Data Completeness** | More complete, validated | Potential gaps | -->
<!-- | **Geographical Consistency** | Consistent within cities | More uniform across countries | -->
<!-- ## Data Collection Process -->
<!-- -   Official Open Data: -->
<!--     -   Limited progress in obtaining historical data so far. -->
<!--     -   Cycle lanes in Barcelona and pedestrian streets in Paris and Milan. -->
<!--     -   Potential access to historical backups in Barcelona. -->
<!-- -   OSM Data Extraction: -->
<!--     -   Collected data on cycleways, pedestrian streets, and living streets from 2015 onwards. -->
<!--     -   We aim to cross-validate the data with official data from Barcelona. -->
<!-- ## Preliminary Visuals -->
<!-- #### OSM Cycling Networks Across 7 ATRAPA Cities (2016–2023) -->



### OSM data Barcelona

#### Road network by type

<img src="figs/barcelona_network_all.png" style="width:100.0%" />

#### Indicators at the census tract level

<!-- To assess the impact of sustainable travel interventions, we will calculate the following indicators: -->
<!-- -   Length of cycleways / Total Road Network Length -->
<!-- -   Length of pedestrian and living streets / Total Road Network Length -->
<!-- -   Length of pavement extensions / Total Road Network Length -->
<!-- These indicators will provide valuable insights into the distribution and availability of infrastructure designed to promote sustainable travel within urban areas. -->

- Cycleway Proportion of Total Network

<img src="figs/barcelona_cycleway_ratios_15_19_23.png"
style="width:100.0%" />



- Living Street Proportion of Total Network

<img src="figs/barcelona_livingstreet_ratios_15_19_23.png"
style="width:100.0%" />



- Pedestrian Street Proportion of Total Network

<img src="figs/barcelona_pedestrian_ratios_15_19_23.png"
style="width:100.0%" />



# References

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

<div id="ref-van_de_coevering_multi-period_2015" class="csl-entry">

Coevering, Paul van de, Maat, and Bert and van Wee. 2015. “Multi-Period
Research Designs for Identifying Causal Effects of Built Environment
Characteristics on Travel Behaviour.” *Transport Reviews* 35 (4):
512–32. <https://doi.org/10.1080/01441647.2015.1025455>.

</div>

<div id="ref-ding_neighborhood_2011" class="csl-entry">

Ding, Ding, James F. Sallis, Jacqueline Kerr, Suzanna Lee, and Dori E.
Rosenberg. 2011. “Neighborhood Environment and Physical Activity Among
Youth.” *American Journal of Preventive Medicine* 41 (4): 442–55.
<https://doi.org/10.1016/j.amepre.2011.06.036>.

</div>

<div id="ref-ferster_developing_2023" class="csl-entry">

Ferster, Colin, Trisalyn Nelson, Kevin Manaugh, Jeneva Beairsto, Karen
Laberee, and Meghan Winters. 2023. “Developing a National Dataset of
Bicycle Infrastructure for Canada Using Open Data Sources.” *Environment
and Planning B: Urban Analytics and City Science* 50 (9): 2543–59.
<https://doi.org/10.1177/23998083231159905>.

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

<div id="ref-national_technical_university_of_athens_greece_utilizing_2022"
class="csl-entry">

National Technical University of Athens, Greece. 2022. “Utilizing
OpenStreetMap Data to Measure and Compare Pedestrian Street Lengths in
992 Cities Around the World.” *European Journal of Geography* 13 (2):
127–41. <https://doi.org/10.48088/ejg.a.bar.13.2.127.138>.

</div>

<div id="ref-omar_crowdsourcing_2022" class="csl-entry">

Omar, Kazi Shahrukh, Gustavo Moreira, Daniel Hodczak, Maryam Hosseini,
and Fabio Miranda. 2022. “Crowdsourcing and Sidewalk Data: A Preliminary
Study on the Trustworthiness of OpenStreetMap Data in the US.” arXiv.
<https://doi.org/10.48550/arXiv.2210.02350>.

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

<div id="ref-viero_bikedna_2024" class="csl-entry">

Vierø, Ane Rahbek, Anastassia Vybornova, and Michael Szell. 2024.
“BikeDNA: A Tool for Bicycle Infrastructure Data & Network Assessment.”
*Environment and Planning B: Urban Analytics and City Science* 51 (2):
512–28. <https://doi.org/10.1177/23998083231184471>.

</div>

<div id="ref-viero_how_2025" class="csl-entry">

———. 2025. “How Good Is Open Bicycle Network Data? A Countrywide Case
Study of Denmark.” *Geographical Analysis* 57 (1): 52–87.
<https://doi.org/10.1111/gean.12400>.

</div>

<div id="ref-zhang_impact_2022" class="csl-entry">

Zhang, Yufang, Marijke Koene, Sijmen A. Reijneveld, Jolanda Tuinstra,
Manda Broekhuis, Stefan van der Spek, and Cor Wagenaar. 2022. “The
Impact of Interventions in the Built Environment on Physical Activity
Levels: A Systematic Umbrella Review.” *International Journal of
Behavioral Nutrition and Physical Activity* 19 (1): 156.
<https://doi.org/10.1186/s12966-022-01399-6>.

</div>

<div id="ref-zielstra_using_2012" class="csl-entry">

Zielstra, Dennis, and Hartwig H. Hochmair. 2012. “Using Free and
Proprietary Data to Compare Shortest-Path Lengths for Effective
Pedestrian Routing in Street Networks.” *Transportation Research Record*
2299 (1): 41–47. <https://doi.org/10.3141/2299-05>.

</div>

<div id="ref-zielstra_comparative_nodate" class="csl-entry">

Zielstra, Dennis, and Alexander Zipf. n.d. “A Comparative Study of
Proprietary Geodata and Volunteered Geographic Information for Germany.”

</div>

</div>
