#!/usr/bin/env Rscript
# Create the exact California-only subset used by the analyses, without simplification.
if (!requireNamespace("sf", quietly = TRUE)) stop("Install the sf package first.")
args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 1) stop("Usage: Rscript scripts/prepare_county_boundaries.R [county_shapefile]")
if (length(args)) {
  source <- args[[1]]
} else {
  dest <- "raw_data/census"
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)
  archive <- file.path(dest, "tl_2024_us_county.zip")
  if (!file.exists(archive)) {
    download.file("https://www2.census.gov/geo/tiger/TIGER2024/COUNTY/tl_2024_us_county.zip",
                  archive, mode = "wb")
  }
  unzip(archive, exdir = dest)
  source <- file.path(dest, "tl_2024_us_county.shp")
}
counties <- sf::st_read(source, quiet = TRUE)
ca <- counties[counties$STATEFP == "06", ]
stopifnot(nrow(ca) == 58, !anyDuplicated(ca$GEOID))
dir.create("spatial_boundaries", showWarnings = FALSE)
sf::st_write(ca, "spatial_boundaries/ca_counties_2024.gpkg", layer = "ca_counties",
             delete_dsn = TRUE, layer_options = "GEOMETRY_NAME=geometry", quiet = TRUE)
cat("Wrote 58 California counties to spatial_boundaries/ca_counties_2024.gpkg\n")
