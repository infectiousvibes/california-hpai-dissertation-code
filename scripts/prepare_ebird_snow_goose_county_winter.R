#!/usr/bin/env Rscript

# Prepare eBird Snow Goose data for county-winter-season analysis.
#
# Study design:
#   Species: Snow Goose (Anser caerulescens)
#   Geography: California
#   Raw date range: Jan 2020 through Dec 2025
#   Winter definition: November-February
#   Study unit: county-winter-season
#
# Output:
#   One county-winter-season CSV with an effort-aware Snow Goose variable:
#   mean known Snow Goose count per checklist.
#
# Dissertation decisions made explicit in this script:
#   1. Jan/Feb are assigned to the winter that began in the previous calendar year.
#      Example: Jan 2021 is winter_season 2020-2021.
#   2. The raw 2020-2025 date range creates two partial boundary winters:
#      2019-2020 has only Jan-Feb 2020, and 2025-2026 has only Nov-Dec 2025.
#   3. The primary denominator is all sampled checklists in the sampling file.
#      A complete-checklists-only sensitivity version is also included.
#   4. Observation Count values of "X" are presence records with unknown count.
#      They contribute to detection checklist counts, but not to known count totals.

suppressPackageStartupMessages({
  required_packages <- c("dplyr", "readr", "stringr", "tidyr", "vroom")
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
  library(readr)
  library(stringr)
  library(tidyr)
  library(vroom)
})

default_ebird_dir <- Sys.getenv("EBIRD_DIR", unset = "raw_data/ebird")

parse_args <- function() {
  defaults <- list(
    species_file = file.path(default_ebird_dir, "ebd_US-CA_snogoo_202001_202512_smp_relMar-2026.txt"),
    sampling_file = file.path(default_ebird_dir, "ebd_US-CA_snogoo_202001_202512_smp_relMar-2026_sampling.txt"),
    output = "california_county_winter_snow_goose_2020_2025.csv",
    output_checklist = NA_character_,
    include_partial_boundary = "true"
  )

  args <- commandArgs(trailingOnly = TRUE)
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

require_existing_file <- function(path, label) {
  if (is.na(path) || !file.exists(path)) {
    stop(label, " does not exist: ", path, call. = FALSE)
  }
}

as_logical_arg <- function(value, arg_name) {
  normalized <- str_to_lower(as.character(value))
  if (!normalized %in% c("true", "false")) {
    stop(arg_name, " must be true or false.", call. = FALSE)
  }
  identical(normalized, "true")
}

read_ebird_tsv <- function(path, cols_to_keep) {
  available_cols <- names(vroom::vroom(
    file = path,
    delim = "\t",
    quote = "",
    n_max = 0,
    altrep = FALSE,
    progress = FALSE,
    show_col_types = FALSE,
    .name_repair = "unique_quiet"
  ))

  missing_cols <- setdiff(cols_to_keep, available_cols)
  if (length(missing_cols) > 0) {
    stop(
      "File is missing expected column(s): ",
      paste(missing_cols, collapse = ", "),
      "\nFile: ", path,
      call. = FALSE
    )
  }

  vroom::vroom(
    file = path,
    delim = "\t",
    quote = "",
    col_select = all_of(cols_to_keep),
    col_types = cols(.default = col_character()),
    altrep = FALSE,
    progress = TRUE,
    show_col_types = FALSE,
    .name_repair = "unique_quiet"
  )
}

clean_count <- function(observation_count) {
  count_text <- str_trim(observation_count)
  count_text[count_text == ""] <- NA_character_
  suppressWarnings(as.numeric(count_text))
}

add_winter_vars <- function(data) {
  data %>%
    mutate(
      observation_date = as.Date(observation_date),
      year = as.integer(format(observation_date, "%Y")),
      month = as.integer(format(observation_date, "%m")),
      winter_start_year = if_else(month %in% c(11L, 12L), year, year - 1L),
      winter_season = paste0(winter_start_year, "-", winter_start_year + 1L),
      is_boundary_partial_winter = winter_season %in% c("2019-2020", "2025-2026")
    )
}

prepare_species_checklists <- function(species_file) {
  message("Reading Snow Goose observation file...")

  species_cols <- c(
    "SAMPLING EVENT IDENTIFIER",
    "COMMON NAME",
    "SCIENTIFIC NAME",
    "OBSERVATION COUNT"
  )

  read_ebird_tsv(species_file, species_cols) %>%
    transmute(
      checklist_id = `SAMPLING EVENT IDENTIFIER`,
      common_name = `COMMON NAME`,
      scientific_name = `SCIENTIFIC NAME`,
      observation_count_raw = `OBSERVATION COUNT`,
      snow_goose_count_known = clean_count(observation_count_raw),
      snow_goose_count_unknown = str_to_upper(str_trim(observation_count_raw)) == "X"
    ) %>%
    filter(
      common_name == "Snow Goose",
      scientific_name == "Anser caerulescens",
      !is.na(checklist_id),
      checklist_id != ""
    ) %>%
    group_by(checklist_id) %>%
    summarise(
      snow_goose_detected = TRUE,
      snow_goose_count_known = sum(snow_goose_count_known, na.rm = TRUE),
      snow_goose_count_unknown_records = sum(snow_goose_count_unknown, na.rm = TRUE),
      snow_goose_records = n(),
      .groups = "drop"
    ) %>%
    mutate(
      snow_goose_count_has_unknown = snow_goose_count_unknown_records > 0
    )
}

prepare_sampling_checklists <- function(sampling_file) {
  message("Reading eBird sampling/checklist file...")

  sampling_cols <- c(
    "SAMPLING EVENT IDENTIFIER",
    "STATE",
    "STATE CODE",
    "COUNTY",
    "COUNTY CODE",
    "LOCALITY ID",
    "LATITUDE",
    "LONGITUDE",
    "OBSERVATION DATE",
    "PROTOCOL NAME",
    "DURATION MINUTES",
    "EFFORT DISTANCE KM",
    "EFFORT AREA HA",
    "NUMBER OBSERVERS",
    "ALL SPECIES REPORTED"
  )

  read_ebird_tsv(sampling_file, sampling_cols) %>%
    transmute(
      checklist_id = `SAMPLING EVENT IDENTIFIER`,
      state = `STATE`,
      state_code = `STATE CODE`,
      county = `COUNTY`,
      county_code = `COUNTY CODE`,
      locality_id = `LOCALITY ID`,
      latitude = parse_number(`LATITUDE`),
      longitude = parse_number(`LONGITUDE`),
      observation_date = `OBSERVATION DATE`,
      protocol_name = `PROTOCOL NAME`,
      duration_minutes = parse_number(`DURATION MINUTES`),
      effort_distance_km = parse_number(`EFFORT DISTANCE KM`),
      effort_area_ha = parse_number(`EFFORT AREA HA`),
      number_observers = parse_number(`NUMBER OBSERVERS`),
      all_species_reported = parse_number(`ALL SPECIES REPORTED`) == 1
    ) %>%
    add_winter_vars() %>%
    filter(
      state == "California",
      state_code == "US-CA",
      year >= 2020,
      year <= 2025,
      month %in% c(1L, 2L, 11L, 12L),
      !is.na(checklist_id),
      checklist_id != "",
      !is.na(county),
      county != ""
    )
}

build_checklist_table <- function(sampling, snow_goose_by_checklist) {
  message("Joining Snow Goose detections to sampling/checklist records...")

  sampling %>%
    left_join(snow_goose_by_checklist, by = "checklist_id") %>%
    mutate(
      snow_goose_detected = coalesce(snow_goose_detected, FALSE),
      snow_goose_count_known = coalesce(snow_goose_count_known, 0),
      snow_goose_count_unknown_records = coalesce(snow_goose_count_unknown_records, 0L),
      snow_goose_records = coalesce(snow_goose_records, 0L),
      snow_goose_count_has_unknown = coalesce(snow_goose_count_has_unknown, FALSE)
    )
}

summarise_county_winter <- function(checklists, include_partial_boundary) {
  message("Summarising to county-winter-season...")

  summary <- checklists %>%
    group_by(county, county_code, winter_start_year, winter_season) %>%
    summarise(
      months_present = n_distinct(month),
      months_included = paste(sort(unique(month)), collapse = ","),
      is_boundary_partial_winter = any(is_boundary_partial_winter),
      total_checklists = n_distinct(checklist_id),
      complete_checklists = n_distinct(checklist_id[all_species_reported]),
      snow_goose_checklists = n_distinct(checklist_id[snow_goose_detected]),
      snow_goose_checklists_complete = n_distinct(checklist_id[snow_goose_detected & all_species_reported]),
      total_snow_goose_count_known = sum(snow_goose_count_known, na.rm = TRUE),
      total_snow_goose_count_known_complete = sum(snow_goose_count_known[all_species_reported], na.rm = TRUE),
      snow_goose_unknown_count_records = sum(snow_goose_count_unknown_records, na.rm = TRUE),
      snow_goose_checklists_with_unknown_count = n_distinct(checklist_id[snow_goose_count_has_unknown]),
      mean_snow_goose_count_per_checklist = total_snow_goose_count_known / total_checklists,
      mean_snow_goose_count_per_complete_checklist = if_else(
        complete_checklists > 0,
        total_snow_goose_count_known_complete / complete_checklists,
        NA_real_
      ),
      snow_goose_detection_rate = snow_goose_checklists / total_checklists,
      snow_goose_detection_rate_complete = if_else(
        complete_checklists > 0,
        snow_goose_checklists_complete / complete_checklists,
        NA_real_
      ),
      mean_duration_minutes = mean(duration_minutes, na.rm = TRUE),
      mean_effort_distance_km = mean(effort_distance_km, na.rm = TRUE),
      mean_number_observers = mean(number_observers, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      winter_completeness_note = case_when(
        is_boundary_partial_winter ~ "Boundary partial winter caused by Jan 2020-Dec 2025 data window",
        months_present == 4 ~ "Complete Nov-Feb winter represented",
        TRUE ~ "Non-boundary winter missing one or more Nov-Feb months"
      )
    ) %>%
    arrange(county, winter_start_year)

  if (!include_partial_boundary) {
    summary <- summary %>% filter(!is_boundary_partial_winter, months_present == 4)
  }

  summary %>%
    select(
      county,
      county_code,
      winter_season,
      winter_start_year,
      months_present,
      months_included,
      is_boundary_partial_winter,
      winter_completeness_note,
      mean_snow_goose_count_per_checklist,
      snow_goose_checklists,
      total_snow_goose_count_known,
      total_checklists,
      mean_snow_goose_count_per_complete_checklist,
      snow_goose_checklists_complete,
      total_snow_goose_count_known_complete,
      complete_checklists,
      snow_goose_detection_rate,
      snow_goose_detection_rate_complete,
      snow_goose_unknown_count_records,
      snow_goose_checklists_with_unknown_count,
      mean_duration_minutes,
      mean_effort_distance_km,
      mean_number_observers
    )
}

main <- function() {
  args <- parse_args()
  include_partial_boundary <- as_logical_arg(args$include_partial_boundary, "--include-partial-boundary")

  require_existing_file(args$species_file, "Species/observation file")
  require_existing_file(args$sampling_file, "Sampling/checklist file")

  snow_goose_by_checklist <- prepare_species_checklists(args$species_file)
  sampling <- prepare_sampling_checklists(args$sampling_file)
  checklists <- build_checklist_table(sampling, snow_goose_by_checklist)
  county_winter <- summarise_county_winter(checklists, include_partial_boundary)

  readr::write_csv(county_winter, args$output, na = "")
  message("Wrote ", nrow(county_winter), " county-winter rows to: ", args$output)

  if (!is.na(args$output_checklist) && args$output_checklist != "") {
    readr::write_csv(checklists, args$output_checklist, na = "")
    message("Wrote checklist-level joined data to: ", args$output_checklist)
  }
}

tryCatch(
  main(),
  error = function(e) {
    message("ERROR: ", conditionMessage(e))
    quit(status = 1)
  }
)
