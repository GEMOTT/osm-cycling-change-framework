# Load packages
library(sf); sf::sf_use_s2(FALSE)
library(dplyr); library(tidyr); library(stringr)
library(ggplot2); library(cowplot)
library(osmdata); library(osmextract)
library(readxl); library(openxlsx)
library(leaflet); library(htmlwidgets)
library(DiagrammeR); library(biscale);
library(tibble)
# etc

# Global options
options(sf_max_proj_search = 100)
Sys.setenv(OGR_ENABLE_PARTITION = "TRUE")
if (!exists("crs_work")) crs_work <- 25831
proc_dir <- "data/processed"
dir.create(proc_dir, recursive = TRUE, showWarnings = FALSE)

# City + versions
city_tag  <- "barcelona"
city_name <- "Barcelona"
ver15     <- "15"
ver23     <- "23"
ver_code_15 <- "160101"
ver_code_23 <- "240101"
