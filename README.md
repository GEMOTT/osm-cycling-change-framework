# OSM Cycling-Infrastructure Change Validation (Barcelona, 2015–2023)


# Overview

This repository contains the reproducible workflow and materials for:

**Quantifying the accuracy of OpenStreetMap for longitudinal
cycling-infrastructure change:  
A reproducible validation framework using Google Street View (Barcelona,
2015–2023).**

The study evaluates how well OpenStreetMap (OSM) snapshot differencing
detects cycling-infrastructure **additions** and **removals**, using
manual coding from historical Google Street View (GSV) imagery as
external validation. We estimate precision, recall, and F1 scores under
a probability-based stratified sampling design.

# Contents

- **Manuscript and outputs**
  - `paper.qmd` – full manuscript (Quarto)
  - `abstract.qmd` – abstract (Quarto)
  - `slides/slides.qmd` – presentation slides (revealjs)
- **Code**
  - `R/` – scripts for extraction, network construction, differencing,
    sampling, validation, and figures
  - `R/utils_*.R` – helper functions (sampling, metrics, confidence
    intervals, etc.)
- **Data and derived products**
  - `data/` – input data (boundaries, census data, etc.; see notes
    below)
  - `outputs/` – derived datasets and validation outputs (tables, XLSX
    exports)
  - `figs/` – figures used in the manuscript
  - `refs/` – bibliography files

# Workflow (high level)

1.  Build baseline and follow-up cycling-infrastructure networks from
    dated OSM extracts.
2.  Detect additions and removals using geometric snapshot differencing.
3.  Design a stratified sample across Barcelona’s census tracts (density
    × centrality).
4.  Validate sampled sites using dual-coder GSV interpretation (≈2015 vs
    ≈2023), then reconcile.
5.  Compute precision, recall, and F1 (with confidence intervals) for
    additions, removals, and pooled change.

# Reproduce the paper

## Requirements

- R (tested on 4.3.3)
- RStudio (recommended)
- Quarto

## Steps

1.  Open the RStudio project: `active-travel-infras-changes.Rproj`

2.  Render the manuscript:

    - `paper.qmd` (main paper)
    - `abstract.qmd` (short abstract)
    - `slides/slides.qmd` (presentation)

Most analysis steps are run via the sourced scripts in the setup chunk
of `paper.qmd`.

# Data notes

Some inputs may be redistributed under different licences or size
constraints. Where full raw inputs are not included, the repository
documents how to download or recreate them (e.g., dated OSM extracts,
boundary/census sources). Derived outputs used in the paper are provided
in `outputs/`.

# Licence

This project is licensed under the MIT License. See the `LICENSE` file
for details.
