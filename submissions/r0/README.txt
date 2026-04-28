# Supplementary Code Archive  
## Quantifying the accuracy of OpenStreetMap for longitudinal cycling-infrastructure change (Barcelona, 2015–2023)

This archive contains the R code used to reproduce the analysis presented in the manuscript.

The workflow implements:

- Reconstruction of baseline (2015 proxy) and follow-up (2023 proxy) cycling-infrastructure networks from dated OpenStreetMap (OSM) extracts  
- Geometric snapshot differencing to detect additions and removals  
- Stratified sampling of validation locations (population density × centrality)  
- Computation of validation metrics (precision, recall, F1 score) based on adjudicated Google Street View (GSV) coding  
- Generation of the main tables and figures reported in the paper  

All analyses were conducted in **R (version 4.3.3)**.

---

## File Structure

- `run_all.R` – Executes the full analytical pipeline  
- `R/` – Sequential scripts implementing network reconstruction, differencing, sampling, and validation metrics  
- `session_info.txt` – Record of R session and package versions used for analysis  

Scripts in the `R/` directory are numbered and intended to be run sequentially.

---

## Data Notes

- Historical OSM extracts are retrieved programmatically using the `osmextract` package (Geofabrik snapshots for 1 January 2016 and 1 January 2024).  
- Google Street View imagery is used for manual validation but is not redistributed.  
- The adjudicated validation coding used to compute performance metrics is included in processed form where permitted.  

---

## Reproducibility

To reproduce the analysis:

1. Open R (version 4.3.3 or compatible).
2. Set the working directory to the root of this archive.
3. Run:

```r
source("run_all.R")