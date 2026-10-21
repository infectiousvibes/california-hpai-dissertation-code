#!/usr/bin/env Rscript
# Run from the repository root; prepared county summaries are included.
args <- commandArgs(trailingOnly = TRUE)
if (length(setdiff(args, "--spatial"))) stop("Usage: Rscript scripts/run_analysis.R [--spatial]")
if (!file.exists("data/prepared/cdl_county_rice_acres_2020_2025.csv")) {
  stop("Run this command from the dissertation-code repository root.")
}
if (!file.exists("spatial_boundaries/ca_counties_2024.gpkg")) {
  stop("County boundaries missing. Run Rscript scripts/prepare_county_boundaries.R first.")
}
set.seed(20261021)
dir.create("analysis_outputs", recursive = TRUE, showWarnings = FALSE)
inputs <- c("cdl_county_rice_acres_2020_2025.csv", "prism_county_winter_2020_2025.csv")
for (name in inputs) {
  if (!file.copy(file.path("data/prepared", name), file.path("analysis_outputs", name), overwrite = TRUE)) {
    stop("Could not copy prepared input: ", name)
  }
}
source("scripts/analyze_county_winter_hpai.R")
source("scripts/dissertation_final_analysis.R")
if ("--spatial" %in% args) {
  dir.create("analysis_outputs/dwr_validation", recursive = TRUE, showWarnings = FALSE)
  name <- "dwr_vs_cdl_county_rice_acres_2020_2024.csv"
  if (!file.copy(file.path("results/reference/dwr_validation", name),
                 file.path("analysis_outputs/dwr_validation", name), overwrite = TRUE)) {
    stop("Missing archived DWR comparison table.")
  }
  source("scripts/export_arcgis_layers.R")
  source("scripts/arcgis_dissertation_spatial_analysis.R")
  source("scripts/create_arcgis_dissertation_visuals.R")
}
writeLines(capture.output(sessionInfo()), "analysis_outputs/sessionInfo.txt")
cat("Completed. Results: analysis_outputs/dissertation_analysis/\n")
