#!/usr/bin/env Rscript

# Export ArcGIS-ready county layers from dissertation analysis outputs.
# Creates a GeoPackage with annual/winter layers and a county-total layer.

suppressPackageStartupMessages({
  required <- c("dplyr", "readr", "sf")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop("Missing required R package(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  library(dplyr)
  library(readr)
  library(sf)
})

out_dir <- "analysis_outputs/arcgis"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
gpkg <- file.path(out_dir, "hpai_rice_goose_arcgis_layers.gpkg")
if (file.exists(gpkg)) file.remove(gpkg)

counties <- sf::read_sf("spatial_boundaries/ca_counties_2024.gpkg") %>%
  filter(STATEFP == "06") %>%
  mutate(
    county = sub(" County$", "", NAME),
    county_fips = as.integer(GEOID)
  ) %>%
  select(county, county_fips, geometry)

dat <- readr::read_csv("analysis_outputs/dissertation_analysis/full_county_winter_analysis_dataset.csv", show_col_types = FALSE)
totals <- readr::read_csv("analysis_outputs/dissertation_analysis/table_3_county_totals_ranked.csv", show_col_types = FALSE)

map_fields <- c(
  "county", "county_fips", "winter_start_year", "winter_season",
  "primary_complete_winter", "rice_producing_county",
  "rice_acres_cdl", "max_rice_acres_2022_2024",
  "mean_snow_goose_count_per_complete_checklist",
  "total_snow_goose_count_known_complete", "complete_checklists",
  "poultry_inventory_known_sum_2022", "poultry_farms_any_2022",
  "poultry_outbreaks", "any_poultry_outbreak", "poultry_birds_affected",
  "wildbird_detections", "waterfowl_detections", "snow_goose_detections",
  "winter_tmean_c", "winter_ppt_mm"
)

primary <- dat %>%
  filter(primary_complete_winter == TRUE) %>%
  select(any_of(map_fields))

write_layer <- function(df, layer_name) {
  join_cols <- if ("county_fips" %in% names(df)) c("county", "county_fips") else "county"
  layer <- counties %>%
    left_join(df, by = join_cols)
  sf::st_write(layer, gpkg, layer = layer_name, quiet = TRUE)
}

write_layer(totals, "county_totals_2022_2025")

for (season in sort(unique(primary$winter_season))) {
  layer_df <- primary %>% filter(winter_season == season)
  layer_name <- paste0("winter_", gsub("-", "_", season))
  write_layer(layer_df, layer_name)
}

rice_validation <- readr::read_csv("analysis_outputs/dwr_validation/dwr_vs_cdl_county_rice_acres_2020_2024.csv", show_col_types = FALSE)
if (nrow(rice_validation) > 0) {
  for (yr in sort(unique(rice_validation$year))) {
    layer_df <- rice_validation %>%
      filter(year == yr) %>%
      select(county, year, rice_acres_dwr, rice_acres_cdl, dwr_minus_cdl_acres, dwr_to_cdl_ratio)
    write_layer(layer_df, paste0("dwr_cdl_validation_", yr))
  }
}

readme <- c(
  "ArcGIS layer export",
  "",
  paste("GeoPackage:", normalizePath(gpkg, mustWork = FALSE)),
  "",
  "Recommended map sequence:",
  "1. county_totals_2022_2025: total outbreak burden and overall rice/goose context.",
  "2. winter_2022_2023, winter_2023_2024, winter_2024_2025: seasonal progression maps.",
  "3. dwr_cdl_validation_2020 through dwr_cdl_validation_2024: source validation maps.",
  "",
  "Suggested symbology:",
  "- Graduated color: rice_acres_cdl or max_rice_acres_2022_2024.",
  "- Graduated symbols: poultry_outbreaks or poultry_birds_affected.",
  "- Transparency/outline: rice_producing_county.",
  "- Separate map: mean_snow_goose_count_per_complete_checklist.",
  "- Validation map: dwr_to_cdl_ratio or dwr_minus_cdl_acres.",
  "",
  "Interpretation caution:",
  "CDL/DWR measure rice acreage, not direct winter flooding. Use these maps as potential rice-field habitat unless an inundation layer is added."
)
writeLines(readme, file.path(out_dir, "arcgis_layer_readme.txt"))

cat("Wrote ArcGIS GeoPackage:", normalizePath(gpkg, mustWork = FALSE), "\n")
