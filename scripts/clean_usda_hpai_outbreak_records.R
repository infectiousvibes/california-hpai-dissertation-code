#!/usr/bin/env Rscript

# Clean APHIS HPAI poultry flock and wild bird detection exports for a
# California county-level poultry/wild bird study. Raw files are left untouched.

raw_base <- Sys.getenv("HPAI_RAW_DIR", unset = "raw_data/hpai")
output_dir <- Sys.getenv("HPAI_CLEAN_DIR", unset = "data/prepared/hpai")

poultry_raw <- file.path(raw_base, "Poultry HPAI Outbreak Dataset", "ExportToCsv.csv")
wildbird_raw <- file.path(raw_base, "Wildbird HPAI Outbreak Dataset", "HPAI Detections in Wild Birds (1).csv")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

parse_date <- function(x) {
  x <- trimws(as.character(x))
  x[x %in% c("", "NA", "Unknown", "unknown")] <- NA_character_
  out <- rep(as.Date(NA), length(x))
  for (fmt in c("%d-%b-%y", "%m/%d/%y", "%m/%d/%Y", "%Y-%m-%d")) {
    idx <- is.na(out) & !is.na(x)
    out[idx] <- as.Date(x[idx], format = fmt)
  }
  out
}

clean_names <- function(x) {
  x <- trimws(x)
  x <- gsub("[^A-Za-z0-9]+", "_", x)
  x <- gsub("_+", "_", x)
  x <- gsub("^_|_$", "", x)
  tolower(x)
}

month_start <- function(d) as.Date(sprintf("%04d-%02d-01", as.integer(format(d, "%Y")), as.integer(format(d, "%m"))))

winter_start_year <- function(d) {
  yr <- as.integer(format(d, "%Y"))
  mo <- as.integer(format(d, "%m"))
  ifelse(mo >= 11, yr, ifelse(mo <= 2, yr - 1L, NA_integer_))
}

winter_season <- function(d) {
  start <- winter_start_year(d)
  ifelse(is.na(start), NA_character_, paste0(start, "-", start + 1L))
}

write_csv <- function(df, path) {
  write.csv(df, path, row.names = FALSE, na = "")
}

summarise_group <- function(df, group_cols, value_cols) {
  if (nrow(df) == 0) return(data.frame())
  split_key <- interaction(df[group_cols], drop = TRUE, lex.order = TRUE)
  rows <- lapply(split(seq_len(nrow(df)), split_key), function(idx) {
    out <- as.list(df[idx[1], group_cols, drop = FALSE])
    for (v in names(value_cols)) out[[v]] <- value_cols[[v]](df[idx, , drop = FALSE])
    as.data.frame(out, stringsAsFactors = FALSE)
  })
  do.call(rbind, rows)
}

poultry <- read.csv(poultry_raw, check.names = FALSE, fileEncoding = "UTF-8-BOM", stringsAsFactors = FALSE)
names(poultry)[names(poultry) == ""] <- "Birds Affected"
names(poultry) <- clean_names(names(poultry))

poultry$confirmed_diagnosis_date <- parse_date(poultry$confirmed_diagnosis)
poultry$birds_affected <- as.numeric(gsub(",", "", poultry$birds_affected))
poultry$county <- trimws(poultry$county_name)
poultry$state <- trimws(poultry$state)
poultry$production <- trimws(poultry$production)
poultry$control_area_released <- trimws(poultry$control_area_released)
poultry$control_area_released[poultry$control_area_released %in% c("", "NA")] <- NA_character_
poultry$control_area_status <- ifelse(
  is.na(poultry$control_area_released), "not_reported",
  ifelse(tolower(poultry$control_area_released) == "active", "active", "released")
)
poultry$flock_sector <- ifelse(grepl("^Commercial", poultry$production), "commercial",
  ifelse(grepl("^Live Bird", poultry$production), "live_bird_market_or_sales",
    ifelse(poultry$production == "WOAH Poultry", "woah_poultry",
      ifelse(poultry$production == "WOAH Non-Poultry", "woah_non_poultry", "other"))))
poultry$study_poultry_case <- poultry$production != "WOAH Non-Poultry"
poultry$event_month <- month_start(poultry$confirmed_diagnosis_date)
poultry$winter_start_year <- winter_start_year(poultry$confirmed_diagnosis_date)
poultry$winter_season <- winter_season(poultry$confirmed_diagnosis_date)
poultry$aphis_source <- "USDA APHIS Confirmations of HPAI in Commercial and Backyard Flocks"
poultry$source_file <- basename(poultry_raw)

poultry_ca_all <- poultry[poultry$state == "California", c(
  "special_id", "state", "county", "production", "flock_sector", "study_poultry_case",
  "confirmed_diagnosis_date", "event_month", "winter_start_year", "winter_season",
  "control_area_status", "control_area_released", "birds_affected", "aphis_source", "source_file"
)]
poultry_ca_study <- poultry_ca_all[poultry_ca_all$study_poultry_case, ]

wild <- read.csv(wildbird_raw, check.names = FALSE, fileEncoding = "UTF-8-BOM", stringsAsFactors = FALSE)
names(wild) <- clean_names(names(wild))
wild$state <- trimws(wild$state)
wild$county <- trimws(wild$county)
wild$collection_date_clean <- parse_date(wild$collection_date)
wild$date_detected_clean <- parse_date(wild$date_detected)
wild$bird_species <- trimws(wild$bird_species)
wild$woah_classification_clean <- tolower(trimws(wild$woah_classification))
wild$is_captive_wild_bird <- wild$woah_classification_clean == "captive wild bird"
wild$species_lower <- tolower(wild$bird_species)
wild$is_snow_goose <- wild$species_lower == "snow goose"
wild$is_goose <- grepl("goose", wild$species_lower)
wild$is_duck <- grepl("duck|mallard|teal|wigeon|pintail|shoveler|gadwall|merganser|scaup|bufflehead|goldeneye|canvasback|redhead|eider|scoter", wild$species_lower)
wild$is_waterfowl <- wild$is_goose | wild$is_duck | grepl("swan", wild$species_lower)
wild$species_group <- ifelse(wild$is_snow_goose, "snow_goose",
  ifelse(wild$is_waterfowl, "other_waterfowl",
    ifelse(grepl("eagle|hawk|owl|falcon|vulture|kite|osprey", wild$species_lower), "raptor_or_scavenger",
      ifelse(grepl("gull|tern|shorebird|plover|sandpiper|turnstone|godwit|dowitcher|avocet|stilt", wild$species_lower), "gull_shorebird", "other_wild_bird"))))
wild$event_month <- month_start(wild$date_detected_clean)
wild$winter_start_year <- winter_start_year(wild$date_detected_clean)
wild$winter_season <- winter_season(wild$date_detected_clean)
wild$exact_duplicate_line <- duplicated(wild) | duplicated(wild, fromLast = TRUE)
wild$aphis_source <- "USDA APHIS Detections of HPAI in Wild Birds"
wild$source_file <- basename(wildbird_raw)
wild$record_id <- sprintf("wildbird_%05d", seq_len(nrow(wild)))

wild_ca <- wild[wild$state == "California", c(
  "record_id", "state", "county", "collection_date_clean", "date_detected_clean",
  "event_month", "winter_start_year", "winter_season", "hpai_strain", "bird_species",
  "species_group", "is_snow_goose", "is_waterfowl", "is_captive_wild_bird",
  "woah_classification", "sampling_method", "submitting_agency", "exact_duplicate_line",
  "aphis_source", "source_file"
)]

poultry_month <- summarise_group(
  poultry_ca_study,
  c("state", "county", "event_month"),
  list(
    poultry_outbreaks = function(x) nrow(x),
    poultry_birds_affected = function(x) sum(x$birds_affected, na.rm = TRUE),
    commercial_outbreaks = function(x) sum(x$flock_sector == "commercial", na.rm = TRUE),
    woah_poultry_outbreaks = function(x) sum(x$flock_sector == "woah_poultry", na.rm = TRUE)
  )
)

wild_month <- summarise_group(
  wild_ca,
  c("state", "county", "event_month"),
  list(
    wildbird_detections = function(x) nrow(x),
    waterfowl_detections = function(x) sum(x$is_waterfowl, na.rm = TRUE),
    snow_goose_detections = function(x) sum(x$is_snow_goose, na.rm = TRUE),
    captive_wildbird_detections = function(x) sum(x$is_captive_wild_bird, na.rm = TRUE)
  )
)

all_month_keys <- unique(rbind(
  poultry_month[c("state", "county", "event_month")],
  wild_month[c("state", "county", "event_month")]
))
county_month <- merge(all_month_keys, poultry_month, all.x = TRUE)
county_month <- merge(county_month, wild_month, all.x = TRUE)
count_cols <- setdiff(names(county_month), c("state", "county", "event_month"))
county_month[count_cols][is.na(county_month[count_cols])] <- 0

poultry_winter <- poultry_ca_study[!is.na(poultry_ca_study$winter_season), ]
wild_winter <- wild_ca[!is.na(wild_ca$winter_season), ]

poultry_winter_sum <- summarise_group(
  poultry_winter,
  c("state", "county", "winter_start_year", "winter_season"),
  list(
    poultry_outbreaks = function(x) nrow(x),
    poultry_birds_affected = function(x) sum(x$birds_affected, na.rm = TRUE),
    commercial_outbreaks = function(x) sum(x$flock_sector == "commercial", na.rm = TRUE),
    woah_poultry_outbreaks = function(x) sum(x$flock_sector == "woah_poultry", na.rm = TRUE)
  )
)

wild_winter_sum <- summarise_group(
  wild_winter,
  c("state", "county", "winter_start_year", "winter_season"),
  list(
    wildbird_detections = function(x) nrow(x),
    waterfowl_detections = function(x) sum(x$is_waterfowl, na.rm = TRUE),
    snow_goose_detections = function(x) sum(x$is_snow_goose, na.rm = TRUE),
    captive_wildbird_detections = function(x) sum(x$is_captive_wild_bird, na.rm = TRUE)
  )
)

all_winter_keys <- unique(rbind(
  poultry_winter_sum[c("state", "county", "winter_start_year", "winter_season")],
  wild_winter_sum[c("state", "county", "winter_start_year", "winter_season")]
))
county_winter <- merge(all_winter_keys, poultry_winter_sum, all.x = TRUE)
county_winter <- merge(county_winter, wild_winter_sum, all.x = TRUE)
count_cols <- setdiff(names(county_winter), c("state", "county", "winter_start_year", "winter_season"))
county_winter[count_cols][is.na(county_winter[count_cols])] <- 0

write_csv(poultry_ca_all, file.path(output_dir, "clean_poultry_hpai_ca_all_flock_records_with_flags.csv"))
write_csv(poultry_ca_study, file.path(output_dir, "clean_poultry_hpai_ca_study_cases.csv"))
write_csv(wild_ca, file.path(output_dir, "clean_wildbird_hpai_ca_detections.csv"))
write_csv(county_month[order(county_month$county, county_month$event_month), ], file.path(output_dir, "county_month_hpai_ca_summary.csv"))
write_csv(county_winter[order(county_winter$county, county_winter$winter_start_year), ], file.path(output_dir, "county_winter_hpai_ca_summary.csv"))

qa <- c(
  "USDA APHIS HPAI outbreak record cleaning QA",
  paste("Run date:", as.character(Sys.Date())),
  "",
  "Raw inputs:",
  paste("- Poultry:", poultry_raw),
  paste("- Wild birds:", wildbird_raw),
  "",
  "Core decisions:",
  "- Kept raw files unchanged.",
  "- Limited study-ready outputs to California county-level records.",
  "- Excluded Production == 'WOAH Non-Poultry' from the poultry study-case file.",
  "- Kept wild bird exact duplicate-looking lines because APHIS does not provide a specimen-level unique ID and repeated identical rows can represent multiple detections.",
  "- Used APHIS detection/confirmed diagnosis date as the event date for month and winter summaries.",
  "- Winter season is Nov-Feb: Nov/Dec assigned to the current year, Jan/Feb assigned to the prior winter start year.",
  "",
  "Record counts:",
  paste("- Raw poultry rows:", nrow(poultry)),
  paste("- California poultry all APHIS flock records:", nrow(poultry_ca_all)),
  paste("- California poultry study cases excluding WOAH Non-Poultry:", nrow(poultry_ca_study)),
  paste("- Raw wild bird rows:", nrow(wild)),
  paste("- California wild bird detection rows:", nrow(wild_ca)),
  paste("- California wild bird exact duplicate-looking rows kept:", sum(wild_ca$exact_duplicate_line)),
  paste("- County-month summary rows:", nrow(county_month)),
  paste("- County-winter summary rows:", nrow(county_winter)),
  "",
  "Date coverage:",
  paste("- Poultry confirmed diagnosis:", min(poultry$confirmed_diagnosis_date, na.rm = TRUE), "to", max(poultry$confirmed_diagnosis_date, na.rm = TRUE)),
  paste("- Wild bird date detected:", min(wild$date_detected_clean, na.rm = TRUE), "to", max(wild$date_detected_clean, na.rm = TRUE))
)
writeLines(qa, file.path(output_dir, "README_quality_check.txt"))

cat(paste(qa, collapse = "\n"))
cat("\n")
