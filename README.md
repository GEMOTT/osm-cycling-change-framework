# OSM Cycling Change Validation Framework


[![License:
MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![DOI](https://img.shields.io/badge/DOI-10.1016%2Fj.jtrangeo.2026.104775-blue)](https://doi.org/10.1016/j.jtrangeo.2026.104775)

# Overview

This repository contains the reproducible research materials
accompanying the study:

**Vidal-Tortosa, E., Gonzàlez-Parra, V., & Marquet, O. (2026).**  
*Quantifying the accuracy of OpenStreetMap for longitudinal
cycling-infrastructure change: A reproducible validation framework using
Google Street View.*  
*Journal of Transport Geography, 136, 104775.*  
https://doi.org/10.1016/j.jtrangeo.2026.104775

The repository includes the manuscript source, analytical code,
validation materials, derived outputs, figures, and supplementary
resources used in the study.

The manuscript is the main entry point to the workflow. Rendering
`paper/manuscript.qmd` executes the required R scripts in sequence,
reconstructing the principal analytical objects, results, tables,
figures, maps, and workflow diagram used in the article.

The study develops and validates a transparent, modular framework for
detecting cycling-infrastructure additions and removals from dated
OpenStreetMap (OSM) snapshots and assessing detection accuracy through
stratified Google Street View (GSV) validation.

Although demonstrated for Barcelona (2015–2023), the framework is
designed to be transferable to other cities where historical OSM
extracts and suitable street-level imagery are available.

------------------------------------------------------------------------

# Repository Structure

- `paper/` – Quarto manuscript source and files required to render the
  article
- `R/` – Modular R scripts sourced by the manuscript
- `data/` – Spatial and population inputs, together with processed
  analytical datasets
- `outputs/` – Sampling workbooks, reconciled validation results,
  summary outputs, and derived datasets
- `figs/` – Static figures generated or used by the manuscript
- `supplements/` – Validation protocol, sensitivity analyses,
  interactive maps, workbooks, and supporting materials
- `refs/` – Bibliography and related reference files
- `_quarto.yml` – Quarto project configuration
- `osm-cycling-change-framework.Rproj` – RStudio project file

------------------------------------------------------------------------

# Workflow

Rendering the manuscript sources the following components in sequence:

1.  `R/00_setup.R` – packages, paths, coordinate reference systems,
    dates, and analytical settings
2.  `R/utils_core.R` – shared geometry, caching, and length-processing
    functions
3.  `R/utils_ci.R` – cycling-infrastructure classification and cleaning
    functions
4.  `R/utils_validation.R` – sampling and validation-table helper
    functions
5.  `R/01_osm_download.R` – retrieval and clipping of dated OSM
    snapshots
6.  `R/02_ci_networks.R` – construction of baseline and follow-up
    cycling networks
7.  `R/03_change_detection.R` – detection of candidate additions and
    removals
8.  `R/04_noncyc_network.R` – construction of the non-cycling control
    pool
9.  `R/05_tracts_strata.R` – tract-level density and centrality
    stratification
10. `R/06_sampling_points.R` – selection of validation segments and
    points
11. `R/07_export_excel.R` – preparation of coder validation workbooks
12. `R/08_results_general.R` – descriptive summaries and general results
13. `R/09_results_validation.R` – reconciliation and validation metrics
14. `R/10_maps.R` – static and interactive maps
15. `R/99_workflow_diagram.R` – methodological workflow diagram

Additional scripts provide sensitivity analyses and sample-extension
checks but are not part of the default manuscript render.

------------------------------------------------------------------------

# Methodological Summary

1.  Construct baseline and follow-up cycling-infrastructure networks
    from dated OSM extracts.
2.  Detect candidate additions and removals using geometric snapshot
    differencing.
3.  Construct a non-cycling control pool.
4.  Stratify census tracts by population density and network centrality.
5.  Draw a probability-based validation sample across the resulting
    strata.
6.  Assess sampled locations using historical Google Street View
    imagery.
7.  Reconcile the classifications of two independent coders.
8.  Estimate precision, recall, and F1 score with confidence intervals.
9.  Compare OSM-derived network lengths with official
    cycling-infrastructure statistics.

------------------------------------------------------------------------

# Reproducibility

## Requirements

The workflow was developed using:

- R 4.3.3
- RStudio (recommended)
- Quarto
- a working LaTeX installation for PDF rendering

Required R packages are loaded in `R/00_setup.R`.

## Rendering the Manuscript

1.  Clone or download this repository.
2.  Open `osm-cycling-change-framework.Rproj`.
3.  Open `paper/manuscript.qmd`.
4.  Render the document with Quarto.

From the repository root, the equivalent terminal command is:

``` bash
quarto render paper/manuscript.qmd
```

Rendering the manuscript sources the principal workflow scripts
automatically.

Some stages reuse cached processed files when they are already
available. Historical OSM downloads and spatial processing may require
substantial execution time, storage, and internet access.

## Manual Validation Stage

The Google Street View assessment is a manual component of the study
rather than an automated computational step.

The repository therefore provides:

- sampled validation locations
- coder workbooks
- the GSV coding protocol
- reconciled or adjudicated validation results

The manuscript render uses the available completed validation materials
to reproduce the reported validation metrics. Repeating the entire study
from the original sampled locations would also require manually
reviewing the relevant historical GSV panoramas.

------------------------------------------------------------------------

# Sensitivity Analyses

The repository includes additional scripts for analyses that are not
sourced during the default manuscript render:

- `R/03b_change_detection_sensitivity.R` – sensitivity to geometric
  change-detection parameters
- `R/06b_sampling_sensitivity.R` – validation-sampling design
  sensitivity
- `R/06c_sampling_extension.R` – extension of the original tract sample

These scripts should be run after the prerequisite objects have been
created by the main workflow.

------------------------------------------------------------------------

# Validation Materials

The `outputs/` and `supplements/` directories contain materials
supporting the validation process, including:

- Google Street View validation protocol
- sampled-location and coder workbooks
- reconciled or adjudicated validation results
- sensitivity-analysis outputs
- interactive infrastructure-change map
- interactive validation-location map

These materials document how candidate additions, removals, and control
locations were assessed and how the final accuracy estimates were
obtained.

------------------------------------------------------------------------

# Data Notes

- Historical OpenStreetMap data are obtained from publicly available
  dated extracts.
- Official administrative, population, and cycling-infrastructure data
  originate from public data providers.
- Google Street View imagery is accessed directly through Google’s
  platform and is not redistributed in this repository.
- Availability of particular historical panoramas may change over time.
- The repository includes the processed data and validation materials
  used to reproduce the reported analyses.
- Third-party data remain subject to the terms and licences of their
  original providers.

------------------------------------------------------------------------

# Transferability

The repository implements the workflow used for Barcelona between 2015
and 2023. Applying the framework to another city may require adapting:

- study-area boundaries
- coordinate reference systems
- OSM classification rules
- snapshot dates
- population and administrative datasets
- stratification variables
- street-level imagery sources and temporal coverage
- validation sampling parameters

The modular organisation of the scripts is intended to facilitate these
adaptations.

------------------------------------------------------------------------

# Licence

The code in this repository is licensed under the MIT License.

See the `LICENSE` file for details.

Third-party datasets and materials remain subject to the licences and
terms of their original providers.

------------------------------------------------------------------------

# Citation

# Citation

If you use this repository, its workflow, or its validation materials,
please cite:

> Vidal-Tortosa, E., Gonzàlez-Parra, V., & Marquet, O. (2026).
> *Quantifying the accuracy of OpenStreetMap for longitudinal
> cycling-infrastructure change: A reproducible validation framework
> using Google Street View.* *Journal of Transport Geography, 136,
> 104775.* https://doi.org/10.1016/j.jtrangeo.2026.104775
