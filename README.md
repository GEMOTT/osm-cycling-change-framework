# OSM Cycling Change Validation (Barcelona 2015–2023)


# Overview

This repository contains the full reproducible computational workflow
for the study:

**Quantifying the accuracy of OpenStreetMap for longitudinal
cycling-infrastructure change:  
A reproducible validation framework using Google Street View (Barcelona,
2015–2023).**

The project develops and validates a transparent, modular pipeline to
detect cycling-infrastructure additions and removals from dated
OpenStreetMap (OSM) snapshots and to quantify detection accuracy using
stratified Google Street View (GSV) validation.

Although demonstrated for Barcelona (2015–2023), the framework is
designed to be transferable to other cities where historical OSM
extracts and street-level imagery are available.

------------------------------------------------------------------------

# Repository Structure

- `R/` – Modular R scripts implementing the full analytical pipeline  
- `paper/` – Quarto manuscript source files  
- `figs/` – Figures used in the manuscript  
- `outputs/` – Derived datasets and validation results  
- `supplements/` – Supplementary materials (validation protocol,
  workbooks, additional outputs)  
- `refs/` – Bibliography files  
- `templates/` – Supporting document templates  
- `_quarto.yml` – Quarto project configuration  
- `osm-cycling-change-framework.Rproj` – RStudio project file

------------------------------------------------------------------------

# Code Structure

The workflow is modular and organised into sequential scripts within
`R/`, covering:

- OSM data retrieval and preprocessing  
- Cycling-network construction  
- Geometric snapshot differencing (additions and removals)  
- Stratified sampling design (density × centrality)  
- Google Street View validation processing  
- Accuracy metrics (precision, recall, F1 with confidence intervals)  
- Figure and table generation

All scripts are sourced from the main Quarto manuscript to ensure full
reproducibility from raw inputs to final figures and tables.

------------------------------------------------------------------------

# Methodological Workflow (Summary)

1.  Construct baseline and follow-up cycling-infrastructure networks
    from dated OSM extracts.  
2.  Detect additions and removals using geometric snapshot
    differencing.  
3.  Design a probability-based stratified validation sample.  
4.  Conduct dual independent GSV coding and reconcile disagreements.  
5.  Estimate precision, recall, and F1 with confidence intervals.  
6.  Regenerate all manuscript outputs reproducibly.

------------------------------------------------------------------------

# Reproducibility

## Requirements

- R (tested on 4.3.3)  
- RStudio (recommended)  
- Quarto

## Reproduce the analysis

1.  Open the project: `osm-cycling-change-framework.Rproj`
2.  Render the manuscript in the `paper/` directory.

All intermediate datasets, validation outputs, tables, and figures are
regenerated automatically.

------------------------------------------------------------------------

# Data Notes

- OSM data are retrieved from dated extracts (e.g. Geofabrik
  snapshots).  
- Census and boundary data originate from official statistical
  sources.  
- Some raw inputs may not be redistributed due to licensing or size
  constraints.  
- Derived outputs used in the manuscript are available in `outputs/`.

------------------------------------------------------------------------

# Licence

This project is licensed under the MIT License.  
See the `LICENSE` file for full details.

------------------------------------------------------------------------

# Citation

If you use this workflow, please cite the associated publication once
available.  
A DOI will be added upon archival release.
