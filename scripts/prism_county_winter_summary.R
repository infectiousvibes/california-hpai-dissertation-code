#!/usr/bin/env Rscript

# Build California county winter climate summaries from PRISM monthly rasters.
#
# Expected PRISM filenames:
#   prism_tmean_us_25m_YYYYMM.zip
#   prism_ppt_us_25m_YYYYMM.zip
#
# Output columns:
#   county, winter_season, winter_tmean, winter_ppt
#
# Usage:
#   Rscript scripts/prism_county_winter_summary.R \
#     --prism-dir prism_4km_monthly_2020_2025 \
#     --county-shp /path/to/california_counties.shp \
#     --output california_county_winter_prism_2020_2025.csv

suppressPackageStartupMessages({
  required_packages <- c(
    "dplyr",
    "exactextractr",
    "purrr",
    "readr",
    "sf",
    "stringr",
    "terra",
    "tidyr"
  )

  missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing_packages) > 0) {
    stop(
      "Missing required R package(s): ",
      paste(missing_packages, collapse = ", "),
      "\nInstall them first, for example:\n",
      "install.packages(c(",
      paste(sprintf('\"%s\"', missing_packages), collapse = ", "),
      "))",
      call. = FALSE
    )
  }

  library(dplyr)
  library(exactextractr)
  library(purrr)
  library(readr)
  library(sf)
  library(stringr)
  library(terra)
  library(tidyr)
})

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  defaults <- list(
    prism_dir = "prism_4km_monthly_2020_2025",
    county_shp = NA_character_,
    output = "california_county_winter_prism_2020_2025.csv",
    county_name_col = NA_character_,
    raster_cache = "prism_raster_cache"
  )

  if (length(args) == 0) {
    return(defaults)
  }

  parsed <- defaults
  i <- 1
  while (i <= length(args)) {
    key <- args[[i]]
    value <- args[[i + 1]]

    if (is.na(value) || !startsWith(key, "--")) {
      stop("Arguments must be provided as --name value pairs.", call. = FALSE)
    }

    name <- gsub("-", "_", sub("^--", "", key))
    if (!name %in% names(parsed)) {
      stop("Unknown argument: ", key, call. = FALSE)
    }

    parsed[[name]] <- value
    i <- i + 2
  }

  parsed
}

require_existing_dir <- function(path, label) {
  if (is.na(path) || !dir.exists(path)) {
    stop(label, " does not exist: ", path, call. = FALSE)
  }
}

require_existing_file <- function(path, label) {
  if (is.na(path) || !file.exists(path)) {
    stop(label, " does not exist: ", path, call. = FALSE)
  }
}

find_county_name_col <- function(counties, requested_col = NA_character_) {
  if (!is.na(requested_col)) {
    if (!requested_col %in% names(counties)) {
      stop("Requested county name column was not found: ", requested_col, call. = FALSE)
    }
    return(requested_col)
  }

  candidates <- c("NAME", "Name", "name", "COUNTY", "County", "county", "NAMELSAD", "GEOID")
  found <- candidates[candidates %in% names(counties)]

  if (length(found) == 0) {
    stop(
      "Could not infer the county name column. ",
      "Pass --county-name-col with the field name from your shapefile.",
      call. = FALSE
    )
  }

  found[[1]]
}

list_prism_files <- function(prism_dir) {
  files <- list.files(
    prism_dir,
    pattern = "^prism_(tmean|ppt)_us_25m_[0-9]{6}\\.zip$",
    full.names = TRUE
  )

  if (length(files) == 0) {
    stop("No monthly PRISM tmean/ppt ZIP files found in: ", prism_dir, call. = FALSE)
  }

  tibble(path = files) %>%
    mutate(
      filename = basename(path),
      variable = str_match(filename, "^prism_(tmean|ppt)_us_25m_([0-9]{4})([0-9]{2})\\.zip$")[, 2],
      year = as.integer(str_match(filename, "^prism_(tmean|ppt)_us_25m_([0-9]{4})([0-9]{2})\\.zip$")[, 3]),
      month = as.integer(str_match(filename, "^prism_(tmean|ppt)_us_25m_([0-9]{4})([0-9]{2})\\.zip$")[, 4])
    ) %>%
    filter(!is.na(variable), !is.na(year), !is.na(month), month %in% c(1, 2, 11, 12))
}

extract_bil_from_zip <- function(zip_path, cache_dir) {
  zip_base <- tools::file_path_sans_ext(basename(zip_path))
  out_dir <- file.path(cache_dir, zip_base)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  zip_files <- utils::unzip(zip_path, list = TRUE)
  bil_files <- zip_files$Name[str_detect(zip_files$Name, "\\.bil$")]

  if (length(bil_files) != 1) {
    stop("Expected exactly one .bil file in ", zip_path, ", found ", length(bil_files), call. = FALSE)
  }

  bil_path <- file.path(out_dir, basename(bil_files[[1]]))

  if (!file.exists(bil_path)) {
    utils::unzip(zip_path, files = zip_files$Name, exdir = out_dir)
  }

  bil_path
}

extract_county_means <- function(prism_files, counties, county_col, cache_dir) {
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

  map_dfr(seq_len(nrow(prism_files)), function(i) {
    item <- prism_files[i, ]
    message("Extracting ", item$variable, " ", item$year, "-", sprintf("%02d", item$month))

    bil_path <- extract_bil_from_zip(item$path, cache_dir)
    raster <- terra::rast(bil_path)

    counties_for_raster <- sf::st_transform(counties, terra::crs(raster))
    means <- exactextractr::exact_extract(raster, counties_for_raster, "mean")

    tibble(
      county = as.character(counties[[county_col]]),
      year = item$year,
      month = item$month,
      variable = item$variable,
      value = as.numeric(means)
    )
  })
}

build_monthly_table <- function(extracted) {
  monthly <- extracted %>%
    tidyr::pivot_wider(names_from = variable, values_from = value) %>%
    arrange(county, year, month)

  required_cols <- c("county", "year", "month", "tmean", "ppt")
  missing_cols <- setdiff(required_cols, names(monthly))
  if (length(missing_cols) > 0) {
    stop("Monthly table is missing column(s): ", paste(missing_cols, collapse = ", "), call. = FALSE)
  }

  monthly %>%
    select(all_of(required_cols))
}

summarize_winter <- function(monthly) {
  monthly %>%
    mutate(
      winter_start_year = if_else(month %in% c(11, 12), year, year - 1L),
      winter_season = paste0(winter_start_year, "-", winter_start_year + 1L)
    ) %>%
    group_by(county, winter_start_year, winter_season) %>%
    summarise(
      months_present = n_distinct(month),
      winter_tmean = mean(tmean, na.rm = TRUE),
      winter_ppt = sum(ppt, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    filter(months_present == 4) %>%
    arrange(county, winter_start_year) %>%
    select(county, winter_season, winter_tmean, winter_ppt)
}

main <- function() {
  args <- parse_args()

  require_existing_dir(args$prism_dir, "PRISM directory")
  require_existing_file(args$county_shp, "California county shapefile")

  prism_files <- list_prism_files(args$prism_dir)
  expected_n <- 2 * 6 * 4
  if (nrow(prism_files) != expected_n) {
    warning(
      "Found ", nrow(prism_files), " matching PRISM files; expected ", expected_n,
      " for 2 variables x 6 years x 4 months."
    )
  }

  missing_pairs <- prism_files %>%
    count(year, month, variable) %>%
    tidyr::complete(year = 2020:2025, month = c(1, 2, 11, 12), variable = c("tmean", "ppt"), fill = list(n = 0)) %>%
    filter(n == 0)

  if (nrow(missing_pairs) > 0) {
    stop(
      "Missing PRISM variable/month files:\n",
      paste0(missing_pairs$variable, " ", missing_pairs$year, "-", sprintf("%02d", missing_pairs$month), collapse = "\n"),
      call. = FALSE
    )
  }

  counties <- sf::st_read(args$county_shp, quiet = TRUE)
  if (!inherits(counties, "sf") || nrow(counties) == 0) {
    stop("County shapefile loaded no features: ", args$county_shp, call. = FALSE)
  }

  counties <- sf::st_make_valid(counties)
  county_col <- find_county_name_col(counties, args$county_name_col)

  monthly <- extract_county_means(prism_files, counties, county_col, args$raster_cache) %>%
    build_monthly_table()

  winter <- summarize_winter(monthly)

  readr::write_csv(winter, args$output, na = "")
  message("Wrote ", nrow(winter), " county-winter rows to: ", args$output)
}

tryCatch(
  main(),
  error = function(e) {
    message("ERROR: ", conditionMessage(e))
    quit(status = 1)
  }
)
