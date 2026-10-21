#!/usr/bin/env Rscript

# Build DWR Statewide Crop Mapping rice-acreage validation table.
# DWR MAIN_CROP code R1 is used as the rice crop class.

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

raw_dir <- "raw_data/dwr_statewide_crop_mapping"
out_dir <- "analysis_outputs/dwr_validation"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

zip_info <- data.frame(
  year = c(2020, 2021, 2022, 2023, 2024),
  status = c("final", "final", "final", "final", "provisional"),
  zip = file.path(raw_dir, c(
    "dwr_statewide_crop_mapping_2020_final.zip",
    "dwr_statewide_crop_mapping_2021_final.zip",
    "dwr_statewide_crop_mapping_2022_final.zip",
    "dwr_statewide_crop_mapping_2023_final.zip",
    "dwr_statewide_crop_mapping_2024_provisional.zip"
  ))
)

read_one <- function(year, status, zip) {
  message("Reading DWR crop mapping ", year, " (", status, ")")
  extract_dir <- file.path(raw_dir, "extracted", paste0("dwr_", year, "_", status))
  if (!dir.exists(extract_dir) || length(list.files(extract_dir, pattern = "\\.shp$", recursive = TRUE)) == 0) {
    dir.create(extract_dir, recursive = TRUE, showWarnings = FALSE)
    utils::unzip(zip, exdir = extract_dir)
  }
  shp <- list.files(extract_dir, pattern = "\\.shp$", recursive = TRUE, full.names = TRUE)[[1]]
  x <- sf::st_read(shp, quiet = TRUE)
  d <- sf::st_drop_geometry(x)
  if (!all(c("COUNTY", "ACRES", "MAIN_CROP") %in% names(d))) {
    stop("Expected COUNTY, ACRES, and MAIN_CROP fields in ", zip, call. = FALSE)
  }
  d %>%
    mutate(
      county = tools::toTitleCase(tolower(COUNTY)),
      dwr_rice_flag = MAIN_CROP == "R1",
      ACRES = as.numeric(ACRES)
    ) %>%
    group_by(county) %>%
    summarise(
      year = year,
      dwr_status = status,
      rice_acres_dwr = sum(ACRES[dwr_rice_flag], na.rm = TRUE),
      crop_mapping_acres_total = sum(ACRES, na.rm = TRUE),
      dwr_rice_polygons = sum(dwr_rice_flag, na.rm = TRUE),
      .groups = "drop"
    )
}

dwr <- dplyr::bind_rows(lapply(seq_len(nrow(zip_info)), function(i) {
  read_one(zip_info$year[i], zip_info$status[i], zip_info$zip[i])
}))

readr::write_csv(dwr, file.path(out_dir, "dwr_county_rice_acres_2020_2024.csv"))

cdl <- readr::read_csv("analysis_outputs/cdl_county_rice_acres_2020_2025.csv", show_col_types = FALSE) %>%
  select(county, year, rice_acres_cdl)

compare <- merge(dwr, cdl, by = c("county", "year"), all.x = TRUE) %>%
  mutate(
    dwr_minus_cdl_acres = rice_acres_dwr - rice_acres_cdl,
    dwr_to_cdl_ratio = ifelse(rice_acres_cdl > 0, rice_acres_dwr / rice_acres_cdl, NA_real_)
  ) %>%
  arrange(year, desc(rice_acres_dwr))

validation_summary <- compare %>%
  group_by(year, dwr_status) %>%
  summarise(
    counties = n(),
    dwr_total_rice_acres = sum(rice_acres_dwr, na.rm = TRUE),
    cdl_total_rice_acres = sum(rice_acres_cdl, na.rm = TRUE),
    difference_acres = dwr_total_rice_acres - cdl_total_rice_acres,
    correlation_county_acres = cor(rice_acres_dwr, rice_acres_cdl, use = "complete.obs", method = "spearman"),
    .groups = "drop"
  )

readr::write_csv(compare, file.path(out_dir, "dwr_vs_cdl_county_rice_acres_2020_2024.csv"))
readr::write_csv(validation_summary, file.path(out_dir, "dwr_vs_cdl_validation_summary.csv"))

cat("Wrote DWR validation outputs to:", normalizePath(out_dir, mustWork = FALSE), "\n")
