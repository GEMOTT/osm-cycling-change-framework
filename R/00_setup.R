## 00_setup.R
## Basic packages, options and project-wide settings

# ----------------------------
# Packages
# ----------------------------

library(sf); sf::sf_use_s2(FALSE)
library(dplyr); library(tidyr); library(stringr); library(tibble)
library(ggplot2); library(cowplot)
library(osmdata); library(osmextract)
library(readxl); library(openxlsx)
library(leaflet); library(htmlwidgets)
library(DiagrammeR); library(biscale)

# ----------------------------
# Global options
# ----------------------------

options(sf_max_proj_search = 100)
Sys.setenv(OGR_ENABLE_PARTITION = "TRUE")

# Main working CRS (ETRS89 / UTM zone 31N)
crs_work <- 25831


# Processed-data directory
proc_dir <- "../data/processed"
dir.create(proc_dir, recursive = TRUE, showWarnings = FALSE)

# Output-data directory
outdir <- "../outputs"
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# ----------------------------
# Project settings
# ----------------------------

# City
city_tag  <- "barcelona"   # folder / file prefix
city_name <- "Barcelona"   # nice name for titles

# Versions (labels used in plots, tables, etc.)
ver15 <- "15"
ver23 <- "23"

# OSM snapshot codes (yyyymmdd → without century)
ver_code_15 <- "160101"    # 2016-01-01 as "160101"
ver_code_23 <- "240101"    # 2024-01-01 as "240101"

# Flags (force re-download / recompute)
FORCE_DOWNLOAD <- FALSE
FORCE_PERIM    <- FALSE

# Geometry thresholds
tol_m   <- 10   # tolerance in metres for snapping / simplification
min_len <- 10   # minimum segment length in metres
