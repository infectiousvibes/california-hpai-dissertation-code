#!/usr/bin/env Rscript

# Dissertation-specific GIS/spatial analysis.
# Focus: spatial convergence of rice acreage, Snow Goose activity, poultry
# exposure, and poultry HPAI outbreaks for Chapter 4/5 interpretation.

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

counties <- sf::read_sf("spatial_boundaries/ca_counties_2024.gpkg") %>%
  filter(STATEFP == "06") %>%
  mutate(
    county = sub(" County$", "", NAME),
    county_fips = as.integer(GEOID)
  ) %>%
  select(county, county_fips, geometry)

dat <- readr::read_csv("analysis_outputs/dissertation_analysis/full_county_winter_analysis_dataset.csv", show_col_types = FALSE) %>%
  filter(primary_complete_winter == TRUE)

rank01 <- function(x) {
  if (all(is.na(x))) return(rep(NA_real_, length(x)))
  r <- rank(x, ties.method = "average", na.last = "keep")
  (r - min(r, na.rm = TRUE)) / (max(r, na.rm = TRUE) - min(r, na.rm = TRUE))
}

make_spatial_scores <- function(df) {
  df %>%
    mutate(
      rice_rank = rank01(rice_acres_cdl),
      goose_rank = rank01(mean_snow_goose_count_per_complete_checklist),
      poultry_inventory_rank = rank01(poultry_inventory_known_sum_2022),
      outbreak_rank = rank01(poultry_outbreaks),
      rice_goose_convergence = (rice_rank + goose_rank) / 2,
      one_health_convergence = (rice_rank + goose_rank + poultry_inventory_rank) / 3,
      high_rice = rice_rank >= 0.75,
      high_goose = goose_rank >= 0.75,
      high_poultry_inventory = poultry_inventory_rank >= 0.75,
      any_outbreak = poultry_outbreaks > 0,
      convergence_class = case_when(
        high_rice & high_goose & high_poultry_inventory & any_outbreak ~ "High rice + high goose + high poultry + outbreak",
        high_rice & high_goose & high_poultry_inventory ~ "High rice + high goose + high poultry, no outbreak",
        high_rice & high_goose & any_outbreak ~ "High rice + high goose + outbreak",
        high_rice & high_poultry_inventory & any_outbreak ~ "High rice + high poultry + outbreak",
        high_goose & high_poultry_inventory & any_outbreak ~ "High goose + high poultry + outbreak",
        high_rice & high_goose ~ "High rice + high goose",
        any_outbreak ~ "Outbreak without top-quartile rice/goose/poultry overlap",
        TRUE ~ "Lower measured convergence"
      )
    )
}

winter_scores <- dat %>%
  group_by(winter_season) %>%
  group_modify(~ make_spatial_scores(.x)) %>%
  ungroup()

county_scores <- dat %>%
  group_by(county, county_fips, rice_producing_county, max_rice_acres_2022_2024) %>%
  summarise(
    poultry_outbreaks = sum(poultry_outbreaks),
    poultry_birds_affected = sum(poultry_birds_affected),
    mean_rice_acres_cdl = mean(rice_acres_cdl, na.rm = TRUE),
    max_rice_acres_cdl = max(rice_acres_cdl, na.rm = TRUE),
    mean_goose_per_checklist = mean(mean_snow_goose_count_per_complete_checklist, na.rm = TRUE),
    max_goose_per_checklist = max(mean_snow_goose_count_per_complete_checklist, na.rm = TRUE),
    poultry_inventory_known_sum_2022 = max(poultry_inventory_known_sum_2022, na.rm = TRUE),
    wildbird_detections = sum(wildbird_detections),
    outbreak_winters = sum(poultry_outbreaks > 0),
    .groups = "drop"
  ) %>%
  rename(
    rice_acres_cdl = mean_rice_acres_cdl,
    mean_snow_goose_count_per_complete_checklist = mean_goose_per_checklist
  ) %>%
  make_spatial_scores() %>%
  arrange(desc(one_health_convergence), desc(poultry_outbreaks))

county_spatial <- counties %>% left_join(county_scores, by = c("county", "county_fips"))
winter_spatial <- counties %>% left_join(winter_scores, by = c("county", "county_fips"))

gpkg <- file.path(out_dir, "hpai_rice_goose_arcgis_layers.gpkg")
sf::st_write(county_spatial, gpkg, layer = "dissertation_convergence_county_totals", append = FALSE, quiet = TRUE)
for (season in sort(unique(winter_scores$winter_season))) {
  layer <- counties %>%
    left_join(winter_scores %>% filter(winter_season == season), by = c("county", "county_fips"))
  sf::st_write(layer, gpkg, layer = paste0("convergence_", gsub("-", "_", season)), append = FALSE, quiet = TRUE)
}

readr::write_csv(sf::st_drop_geometry(county_spatial), file.path(out_dir, "dissertation_spatial_convergence_county_totals.csv"))
readr::write_csv(sf::st_drop_geometry(winter_spatial), file.path(out_dir, "dissertation_spatial_convergence_by_winter.csv"))

summary_by_class <- county_scores %>%
  group_by(convergence_class) %>%
  summarise(
    counties = n(),
    poultry_outbreaks = sum(poultry_outbreaks),
    poultry_birds_affected = sum(poultry_birds_affected),
    mean_one_health_convergence = mean(one_health_convergence, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(poultry_outbreaks))

readr::write_csv(summary_by_class, file.path(out_dir, "dissertation_spatial_convergence_class_summary.csv"))

top_convergence <- county_scores %>%
  select(
    county, rice_producing_county, poultry_outbreaks, poultry_birds_affected,
    rice_acres_cdl, mean_snow_goose_count_per_complete_checklist,
    poultry_inventory_known_sum_2022, rice_goose_convergence,
    one_health_convergence, convergence_class
  ) %>%
  arrange(desc(one_health_convergence), desc(poultry_outbreaks))

readr::write_csv(top_convergence, file.path(out_dir, "dissertation_top_convergence_counties.csv"))

notes <- c(
  "# ArcGIS Dissertation Spatial Analysis",
  "",
  "Purpose: These outputs support the dissertation's spatial interpretation by showing where rice acreage, Snow Goose activity, poultry exposure, and poultry HPAI outbreaks converge geographically.",
  "",
  "Key GIS layers added to the GeoPackage:",
  "",
  "- dissertation_convergence_county_totals",
  "- convergence_2022_2023",
  "- convergence_2023_2024",
  "- convergence_2024_2025",
  "",
  "Important fields:",
  "",
  "- rice_rank: county percentile-like rank for CDL rice acreage.",
  "- goose_rank: rank for mean Snow Goose count per complete checklist.",
  "- poultry_inventory_rank: rank for poultry inventory exposure.",
  "- rice_goose_convergence: average of rice and Snow Goose ranks.",
  "- one_health_convergence: average of rice, Snow Goose, and poultry inventory ranks.",
  "- convergence_class: qualitative class for map symbology and interpretation.",
  "",
  "How this relates to the dissertation:",
  "",
  "The regression models test whether rice acreage, Snow Goose activity, and their interaction independently predict outbreak incidence after adjustment. The GIS analysis asks a complementary spatial question: where do the ecological and agricultural risk components overlap? A map may show spatial convergence even when adjusted regression coefficients are not statistically significant.",
  "",
  "Recommended ArcGIS maps:",
  "",
  "1. Symbolize dissertation_convergence_county_totals by one_health_convergence using graduated color.",
  "2. Overlay graduated symbols for poultry_outbreaks.",
  "3. Make separate maps for convergence_2022_2023, convergence_2023_2024, and convergence_2024_2025 to show seasonal progression.",
  "4. Symbolize convergence_class with unique values for a dissertation-friendly categorical map.",
  "",
  "Interpretation caution: This remains ecological, county-level evidence. It supports visual/spatial interpretation and hypothesis generation; it does not override the adjusted regression results.",
  ""
)
writeLines(notes, file.path(out_dir, "dissertation_arcgis_analysis_notes.md"))

cat("Wrote ArcGIS dissertation spatial analysis outputs to:", normalizePath(out_dir, mustWork = FALSE), "\n")
