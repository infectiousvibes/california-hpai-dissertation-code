#!/usr/bin/env Rscript

# Build county-year rice acreage from USDA NASS Cropland Data Layer rasters.
#
# Primary dissertation use:
#   - CDL class code 3 = Rice.
#   - Output is annual rice acreage by California county.
#   - This is rice habitat acreage, not directly observed post-harvest flooding.
#     If a winter inundation/flooding layer is added later, use that to derive
#     flooded_rice_acres separately.

suppressPackageStartupMessages({
  required <- c("dplyr", "exactextractr", "readr", "sf", "terra")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop("Missing required R package(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  library(dplyr)
  library(exactextractr)
  library(readr)
  library(sf)
  library(terra)
})

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  out <- list(
    cdl_dir = Sys.getenv("CDL_DIR", unset = "raw_data/cdl"),
    years = 2020:2025,
    boundaries_dir = "spatial_boundaries",
    output = "analysis_outputs/cdl_county_rice_acres_2020_2025.csv"
  )
  if (length(args) == 0) return(out)
  i <- 1
  while (i <= length(args)) {
    key <- args[[i]]
    val <- args[[i + 1]]
    if (is.na(val) || !startsWith(key, "--")) {
      stop("Arguments must be provided as --name value pairs.", call. = FALSE)
    }
    name <- gsub("-", "_", sub("^--", "", key))
    if (!name %in% names(out)) stop("Unknown argument: ", key, call. = FALSE)
    if (name == "years") {
      out[[name]] <- as.integer(strsplit(val, ",")[[1]])
    } else {
      out[[name]] <- val
    }
    i <- i + 2
  }
  out
}

download_counties <- function(boundaries_dir) {
  dir.create(boundaries_dir, recursive = TRUE, showWarnings = FALSE)
  zip_path <- file.path(boundaries_dir, "tl_2024_us_county.zip")
  shp_path <- file.path(boundaries_dir, "tl_2024_us_county.shp")

  if (!file.exists(shp_path)) {
    url <- "https://www2.census.gov/geo/tiger/TIGER2024/COUNTY/tl_2024_us_county.zip"
    message("Downloading Census TIGER county boundaries: ", url)
    utils::download.file(url, zip_path, mode = "wb", quiet = TRUE)
    utils::unzip(zip_path, exdir = boundaries_dir)
  }

  counties <- sf::read_sf(shp_path) %>%
    filter(STATEFP == "06") %>%
    mutate(
      county = sub(" County$", "", NAME),
      county_fips = GEOID
    ) %>%
    select(county, county_fips, geometry)

  counties
}

cdl_vsi_path <- function(cdl_dir, year) {
  zip_path <- file.path(cdl_dir, sprintf("%s_30m_cdls.zip", year))
  if (!file.exists(zip_path)) {
    stop("Missing CDL ZIP for ", year, ": ", zip_path, call. = FALSE)
  }
  sprintf("/vsizip/%s/%s_30m_cdls.tif", zip_path, year)
}

extract_one_year <- function(year, cdl_dir, counties) {
  message("Processing CDL rice acreage for ", year)
  cdl <- terra::rast(cdl_vsi_path(cdl_dir, year))
  counties_raster_crs <- sf::st_transform(counties, terra::crs(cdl))
  counties_vect <- terra::vect(counties_raster_crs)

  # Crop first; the CDL files are national rasters and direct exact extraction
  # against the full raster is unnecessarily slow for California-only summaries.
  cdl_ca <- terra::crop(cdl, counties_vect)
  rice <- terra::ifel(cdl_ca == 3, 1, 0)
  names(rice) <- "rice"

  cell_area_acres <- prod(terra::res(cdl)) / 4046.8564224
  rice_cell_equiv <- exactextractr::exact_extract(rice, counties_raster_crs, "sum")

  tibble(
    county = counties$county,
    county_fips = counties$county_fips,
    year = year,
    cdl_rice_cell_equivalent = as.numeric(rice_cell_equiv),
    rice_acres_cdl = as.numeric(rice_cell_equiv) * cell_area_acres,
    source = "USDA NASS Cropland Data Layer",
    source_variable = "CDL class code 3 (Rice)",
    notes = "Annual CDL rice acreage by county. This measures rice land cover, not direct winter flooding."
  )
}

args <- parse_args()
dir.create(dirname(args$output), recursive = TRUE, showWarnings = FALSE)

counties <- download_counties(args$boundaries_dir)
out <- dplyr::bind_rows(lapply(args$years, extract_one_year, cdl_dir = args$cdl_dir, counties = counties)) %>%
  arrange(county, year)

readr::write_csv(out, args$output)

cat("Wrote:", normalizePath(args$output, mustWork = FALSE), "\n")
cat("Rows:", nrow(out), "\n")
cat("Years:", paste(sort(unique(out$year)), collapse = ", "), "\n")
