#!/usr/bin/env Rscript

# First-pass county-winter analysis for California HPAI, poultry exposure,
# Snow Goose winter abundance, and APHIS wild-bird detections.

project_dir <- normalizePath(".", mustWork = TRUE)
out_dir <- file.path(project_dir, "analysis_outputs")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

hpai_dir <- Sys.getenv("HPAI_CLEAN_DIR", unset = "data/prepared/hpai")

read_csv <- function(path) read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
write_csv <- function(df, path) write.csv(df, path, row.names = FALSE, na = "")

safe_log1p <- function(x) log1p(ifelse(is.na(x), 0, x))
z <- function(x) as.numeric(scale(x))

snow <- read_csv(file.path(project_dir, "california_county_winter_snow_goose_2020_2025.csv"))
poultry <- read_csv(file.path(project_dir, "ca_county_poultry_census_2022.csv"))
hpai <- read_csv(file.path(hpai_dir, "county_winter_hpai_ca_summary.csv"))

all_counties <- sort(unique(poultry$county))
all_seasons <- sort(unique(snow$winter_season))
grid <- expand.grid(county = all_counties, winter_season = all_seasons, stringsAsFactors = FALSE)
grid$winter_start_year <- as.integer(substr(grid$winter_season, 1, 4))

snow_keep <- snow[, c(
  "county", "winter_season", "winter_start_year", "months_present", "months_included",
  "is_boundary_partial_winter", "winter_completeness_note",
  "mean_snow_goose_count_per_complete_checklist",
  "total_snow_goose_count_known_complete",
  "complete_checklists", "snow_goose_detection_rate_complete",
  "mean_duration_minutes", "mean_effort_distance_km", "mean_number_observers"
)]

poultry_keep <- poultry[, c(
  "county", "poultry_farms_any_2022", "layer_farms_2022", "broiler_farms_2022",
  "turkey_farms_2022", "poultry_inventory_known_sum_2022",
  "poultry_inventory_known_sum_incomplete", "poultry_sales_known_sum_2022",
  "poultry_sales_known_sum_incomplete"
)]

hpai_keep <- hpai[, c(
  "county", "winter_season", "poultry_outbreaks", "poultry_birds_affected",
  "commercial_outbreaks", "woah_poultry_outbreaks", "wildbird_detections",
  "waterfowl_detections", "snow_goose_detections", "captive_wildbird_detections"
)]

dat <- merge(grid, snow_keep, by = c("county", "winter_season", "winter_start_year"), all.x = TRUE)
dat <- merge(dat, poultry_keep, by = "county", all.x = TRUE)
dat <- merge(dat, hpai_keep, by = c("county", "winter_season"), all.x = TRUE)

count_cols <- c(
  "poultry_outbreaks", "poultry_birds_affected", "commercial_outbreaks",
  "woah_poultry_outbreaks", "wildbird_detections", "waterfowl_detections",
  "snow_goose_detections", "captive_wildbird_detections"
)
dat[count_cols][is.na(dat[count_cols])] <- 0

dat$any_poultry_outbreak <- as.integer(dat$poultry_outbreaks > 0)
dat$complete_ebird_winter <- !is.na(dat$is_boundary_partial_winter) & !dat$is_boundary_partial_winter & dat$months_present == 4
dat$analysis_window_primary <- dat$complete_ebird_winter & dat$winter_season %in% c("2022-2023", "2023-2024", "2024-2025")
dat$analysis_window_sensitivity <- dat$complete_ebird_winter & dat$winter_season %in% c("2022-2023", "2023-2024", "2024-2025", "2025-2026")
dat$log_poultry_farms <- safe_log1p(dat$poultry_farms_any_2022)
dat$log_poultry_inventory_known <- safe_log1p(dat$poultry_inventory_known_sum_2022)
dat$log_snow_goose_mean_complete <- safe_log1p(dat$mean_snow_goose_count_per_complete_checklist)
dat$log_snow_goose_total_complete <- safe_log1p(dat$total_snow_goose_count_known_complete)
dat$log_complete_checklists <- safe_log1p(dat$complete_checklists)
dat$log_wildbird_detections <- safe_log1p(dat$wildbird_detections)
dat$log_waterfowl_detections <- safe_log1p(dat$waterfowl_detections)

primary <- dat[dat$analysis_window_primary, ]

by_winter <- aggregate(
  cbind(
    county_winters = rep(1, nrow(primary)),
    counties_with_poultry_outbreak = primary$any_poultry_outbreak,
    poultry_outbreaks = primary$poultry_outbreaks,
    poultry_birds_affected = primary$poultry_birds_affected,
    wildbird_detections = primary$wildbird_detections,
    waterfowl_detections = primary$waterfowl_detections,
    snow_goose_hpai_detections = primary$snow_goose_detections,
    ebird_snow_goose_count = primary$total_snow_goose_count_known_complete,
    ebird_complete_checklists = primary$complete_checklists
  ) ~ winter_season,
  data = primary,
  FUN = sum
)

county_summary <- aggregate(
  cbind(
    poultry_outbreaks = primary$poultry_outbreaks,
    poultry_birds_affected = primary$poultry_birds_affected,
    wildbird_detections = primary$wildbird_detections,
    waterfowl_detections = primary$waterfowl_detections,
    snow_goose_hpai_detections = primary$snow_goose_detections,
    ebird_snow_goose_count = primary$total_snow_goose_count_known_complete
  ) ~ county,
  data = primary,
  FUN = sum
)
county_summary <- merge(county_summary, poultry_keep, by = "county", all.x = TRUE)
county_summary <- county_summary[order(-county_summary$poultry_outbreaks, -county_summary$poultry_birds_affected), ]

model_rows <- primary[
  !is.na(primary$poultry_farms_any_2022) &
    !is.na(primary$mean_snow_goose_count_per_complete_checklist) &
    !is.na(primary$complete_checklists),
]

model_rows$z_log_poultry_farms <- z(model_rows$log_poultry_farms)
model_rows$z_log_poultry_inventory <- z(model_rows$log_poultry_inventory_known)
model_rows$z_log_snow_goose_mean <- z(model_rows$log_snow_goose_mean_complete)
model_rows$z_log_wildbird_detections <- z(model_rows$log_wildbird_detections)
model_rows$z_log_complete_checklists <- z(model_rows$log_complete_checklists)
model_rows$winter_season <- factor(model_rows$winter_season)

fit_logit <- glm(
  any_poultry_outbreak ~ z_log_poultry_farms + z_log_poultry_inventory +
    z_log_snow_goose_mean + z_log_complete_checklists + winter_season,
  data = model_rows,
  family = binomial()
)

fit_logit_wild <- glm(
  any_poultry_outbreak ~ z_log_poultry_farms + z_log_poultry_inventory +
    z_log_snow_goose_mean + z_log_wildbird_detections +
    z_log_complete_checklists + winter_season,
  data = model_rows,
  family = binomial()
)

tidy_glm <- function(fit, model_name) {
  co <- coef(summary(fit))
  out <- data.frame(
    model = model_name,
    term = rownames(co),
    estimate = co[, "Estimate"],
    std_error = co[, "Std. Error"],
    statistic = co[, "z value"],
    p_value = co[, "Pr(>|z|)"],
    odds_ratio = exp(co[, "Estimate"]),
    conf_low_or = exp(co[, "Estimate"] - 1.96 * co[, "Std. Error"]),
    conf_high_or = exp(co[, "Estimate"] + 1.96 * co[, "Std. Error"]),
    row.names = NULL
  )
  out
}

model_summary <- rbind(
  tidy_glm(fit_logit, "primary_logistic_no_wild_hpai_detection"),
  tidy_glm(fit_logit_wild, "primary_logistic_with_wild_hpai_detection")
)

write_csv(dat, file.path(out_dir, "analysis_county_winter_model_data.csv"))
write_csv(by_winter, file.path(out_dir, "descriptive_by_winter_primary.csv"))
write_csv(county_summary, file.path(out_dir, "descriptive_by_county_primary.csv"))
write_csv(head(county_summary, 15), file.path(out_dir, "top_counties_poultry_outbreaks_primary.csv"))
write_csv(model_summary, file.path(out_dir, "primary_logistic_model_summary.csv"))

png(file.path(out_dir, "poultry_outbreaks_by_winter.png"), width = 1400, height = 900, res = 150)
barplot(
  by_winter$poultry_outbreaks,
  names.arg = by_winter$winter_season,
  col = "#4B8BBE",
  border = NA,
  ylab = "Poultry HPAI outbreaks",
  xlab = "Winter season",
  main = "California poultry HPAI outbreaks by complete winter"
)
dev.off()

png(file.path(out_dir, "poultry_vs_snow_goose_pressure.png"), width = 1400, height = 900, res = 150)
plot(
  primary$mean_snow_goose_count_per_complete_checklist,
  primary$poultry_outbreaks,
  pch = 19,
  col = ifelse(primary$poultry_outbreaks > 0, "#C44E52", "#4B8BBE"),
  xlab = "Mean Snow Goose count per complete eBird checklist",
  ylab = "Poultry HPAI outbreaks",
  main = "County-winter poultry outbreaks vs. Snow Goose observation pressure"
)
grid()
dev.off()

plan <- c(
  "# First-pass analysis plan",
  "",
  "## Study framing inferred from current files",
  "",
  "Objective 1: Describe California county-winter HPAI poultry outbreak patterns during the current outbreak era.",
  "",
  "Objective 2: Estimate whether county-level poultry exposure is associated with poultry HPAI outbreak occurrence.",
  "",
  "Objective 3: Estimate whether winter Snow Goose abundance/observation pressure is associated with poultry HPAI outbreak occurrence after accounting for poultry exposure and eBird effort.",
  "",
  "Objective 4: Use APHIS wild-bird detections as a sensitivity/secondary indicator of local viral activity, not as the clean primary exposure, because those detections are surveillance-dependent and can be downstream of outbreak attention.",
  "",
  "## Proposed research questions",
  "",
  "RQ1: Which California counties and winter seasons had the highest poultry HPAI outbreak burden?",
  "",
  "RQ2: Are counties with more poultry farms or larger known poultry inventories more likely to report poultry HPAI outbreaks?",
  "",
  "RQ3: Are county-winters with greater Snow Goose abundance in eBird more likely to experience poultry HPAI outbreaks, controlling for poultry exposure and checklist effort?",
  "",
  "RQ4: Do APHIS wild-bird detections add explanatory signal beyond Snow Goose abundance and poultry exposure?",
  "",
  "## Primary methodology",
  "",
  "Unit of analysis: California county-winter.",
  "",
  "Winter definition: November-February. November/December are assigned to that year's winter start; January/February are assigned to the prior winter.",
  "",
  "Primary analysis window: complete eBird winters overlapping APHIS poultry outbreak data, currently 2022-2023, 2023-2024, and 2024-2025. The 2025-2026 Snow Goose file is partial and should not be used in the primary analysis until complete.",
  "",
  "Primary outcome: any poultry HPAI outbreak in the county-winter. Secondary outcome: outbreak count.",
  "",
  "Primary predictors: 2022 poultry farms, known poultry inventory, mean Snow Goose count per complete checklist, and complete eBird checklist count as effort adjustment.",
  "",
  "Initial model: logistic regression for any poultry outbreak. Treat results as exploratory because outcomes are sparse, poultry inventory has USDA suppression, and counties are repeated over winters.",
  "",
  "Next stronger model: if the committee wants inference rather than exploration, use a repeated-measures model such as GEE or mixed-effects logistic regression, and add spatial sensitivity checks.",
  "",
  "## Data limitations to report",
  "",
  "USDA Ag Census poultry inventory is from 2022 only and has suppressed cells; use the known-sum inventory variables carefully.",
  "",
  "eBird counts are effort-dependent; include checklist effort and prefer complete-checklist metrics.",
  "",
  "APHIS wild-bird detections reflect surveillance and mortality reporting, not true wild-bird prevalence.",
  "",
  "PRISM climate summaries are not yet in the analytic table because a county boundary file/output climate CSV is not present in this project folder.",
  ""
)
writeLines(plan, file.path(out_dir, "study_objectives_research_questions_methodology.md"))

cat("Wrote analysis outputs to:", out_dir, "\n")
cat("Primary county-winters:", nrow(primary), "\n")
cat("Counties with >=1 poultry outbreak in primary window:", sum(county_summary$poultry_outbreaks > 0), "\n")
cat("Total primary-window poultry outbreaks:", sum(primary$poultry_outbreaks), "\n")
