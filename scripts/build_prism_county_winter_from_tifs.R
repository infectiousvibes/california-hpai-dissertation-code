#!/usr/bin/env Rscript

# Build California county winter climate summaries from already-extracted PRISM
# monthly tmean and ppt GeoTIFF files.

suppressPackageStartupMessages({
  required <- c("dplyr", "exactextractr", "readr", "sf", "stringr", "terra", "tidyr")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop("Missing required R package(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  library(dplyr)
  library(exactextractr)
  library(readr)
  library(sf)
  library(stringr)
  library(terra)
  library(tidyr)
})

prism_dir <- "prism_4km_monthly_2020_2025"
county_shp <- "spatial_boundaries/ca_counties_2024.gpkg"
output <- "analysis_outputs/prism_county_winter_2020_2025.csv"

dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)

counties <- sf::read_sf(county_shp) %>%
  filter(STATEFP == "06") %>%
  mutate(
    county = sub(" County$", "", NAME),
    county_fips = GEOID
  ) %>%
  select(county, county_fips, geometry)

files <- list.files(
  prism_dir,
  pattern = "^prism_(tmean|ppt)_us_25m_[0-9]{6}\\.tif$",
  recursive = TRUE,
  full.names = TRUE
)

inventory <- tibble(path = files, filename = basename(files)) %>%
  mutate(
    variable = stringr::str_match(filename, "^prism_(tmean|ppt)_us_25m_([0-9]{4})([0-9]{2})\\.tif$")[, 2],
    year = as.integer(stringr::str_match(filename, "^prism_(tmean|ppt)_us_25m_([0-9]{4})([0-9]{2})\\.tif$")[, 3]),
    month = as.integer(stringr::str_match(filename, "^prism_(tmean|ppt)_us_25m_([0-9]{4})([0-9]{2})\\.tif$")[, 4])
  ) %>%
  filter(variable %in% c("tmean", "ppt"), month %in% c(1, 2, 11, 12))

if (nrow(inventory) == 0) stop("No PRISM monthly tmean/ppt TIF files found.", call. = FALSE)

extract_one <- function(item) {
  message("Extracting PRISM ", item$variable, " ", item$year, "-", sprintf("%02d", item$month))
  r <- terra::rast(item$path)
  counties_raster_crs <- sf::st_transform(counties, terra::crs(r))
  means <- exactextractr::exact_extract(r, counties_raster_crs, "mean")
  tibble(
    county = counties$county,
    county_fips = counties$county_fips,
    year = item$year,
    month = item$month,
    variable = item$variable,
    value = as.numeric(means)
  )
}

monthly_long <- dplyr::bind_rows(lapply(seq_len(nrow(inventory)), function(i) extract_one(inventory[i, ])))

monthly <- monthly_long %>%
  tidyr::pivot_wider(names_from = variable, values_from = value) %>%
  mutate(
    winter_start_year = if_else(month %in% c(11, 12), year, year - 1L),
    winter_season = paste0(winter_start_year, "-", winter_start_year + 1L)
  )

winter <- monthly %>%
  group_by(county, county_fips, winter_start_year, winter_season) %>%
  summarise(
    prism_months_present = n_distinct(month),
    winter_tmean_c = mean(tmean, na.rm = TRUE),
    winter_ppt_mm = sum(ppt, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  filter(prism_months_present == 4) %>%
  arrange(county, winter_start_year)

readr::write_csv(winter, output)
cat("Wrote:", normalizePath(output, mustWork = FALSE), "\n")
cat("Rows:", nrow(winter), "\n")
