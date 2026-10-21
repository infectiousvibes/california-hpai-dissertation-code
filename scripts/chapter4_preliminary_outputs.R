#!/usr/bin/env Rscript

# Dissertation-aligned preliminary outputs for Chapter 4.
# This script uses the currently available analysis dataset and clearly flags
# which dissertation RQs still require flooded-rice data before final testing.

suppressPackageStartupMessages({
  if (!requireNamespace("MASS", quietly = TRUE)) {
    stop("Package MASS is required for negative binomial models.", call. = FALSE)
  }
})

project_dir <- normalizePath(".", mustWork = TRUE)
out_dir <- file.path(project_dir, "analysis_outputs", "chapter4_preliminary")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

source_script <- file.path(project_dir, "scripts", "analyze_county_winter_hpai.R")
if (!file.exists(file.path(project_dir, "analysis_outputs", "analysis_county_winter_model_data.csv"))) {
  source(source_script)
}

read_csv <- function(path) read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
write_csv <- function(df, path) write.csv(df, path, row.names = FALSE, na = "")

dat <- read_csv(file.path(project_dir, "analysis_outputs", "analysis_county_winter_model_data.csv"))

rice_path <- file.path(project_dir, "analysis_outputs", "cdl_county_rice_acres_2020_2025.csv")
has_rice <- file.exists(rice_path)
if (has_rice) {
  rice <- read_csv(rice_path)
  rice_keep <- rice[, c("county", "year", "rice_acres_cdl")]
  names(rice_keep)[names(rice_keep) == "year"] <- "winter_start_year"
  dat <- merge(dat, rice_keep, by = c("county", "winter_start_year"), all.x = TRUE)
  dat$log_rice_acres_cdl <- log1p(ifelse(is.na(dat$rice_acres_cdl), 0, dat$rice_acres_cdl))
}

primary <- dat[dat$analysis_window_primary == TRUE, ]

num_vars <- c(
  "rice_acres_cdl",
  "poultry_outbreaks",
  "poultry_birds_affected",
  "wildbird_detections",
  "waterfowl_detections",
  "snow_goose_detections",
  "mean_snow_goose_count_per_complete_checklist",
  "total_snow_goose_count_known_complete",
  "complete_checklists",
  "poultry_farms_any_2022",
  "poultry_inventory_known_sum_2022",
  "poultry_sales_known_sum_2022"
)
num_vars <- num_vars[num_vars %in% names(primary)]

describe_var <- function(x) {
  x <- as.numeric(x)
  data.frame(
    n = sum(!is.na(x)),
    missing = sum(is.na(x)),
    mean = mean(x, na.rm = TRUE),
    sd = sd(x, na.rm = TRUE),
    median = median(x, na.rm = TRUE),
    min = min(x, na.rm = TRUE),
    q1 = as.numeric(quantile(x, 0.25, na.rm = TRUE)),
    q3 = as.numeric(quantile(x, 0.75, na.rm = TRUE)),
    max = max(x, na.rm = TRUE)
  )
}

descriptives <- do.call(rbind, lapply(num_vars, function(v) {
  out <- describe_var(primary[[v]])
  out$variable <- v
  out[, c("variable", setdiff(names(out), "variable"))]
}))

missingness <- data.frame(
  variable = names(primary),
  missing_n = vapply(primary, function(x) sum(is.na(x)), numeric(1)),
  missing_pct = round(vapply(primary, function(x) mean(is.na(x)) * 100, numeric(1)), 2)
)
missingness <- missingness[order(-missingness$missing_pct, missingness$variable), ]

by_winter <- aggregate(
  cbind(
    county_winters = rep(1, nrow(primary)),
    counties_with_any_poultry_outbreak = primary$poultry_outbreaks > 0,
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

cor_vars <- c(
  "rice_acres_cdl",
  "poultry_outbreaks",
  "wildbird_detections",
  "waterfowl_detections",
  "mean_snow_goose_count_per_complete_checklist",
  "complete_checklists",
  "poultry_farms_any_2022",
  "poultry_inventory_known_sum_2022"
)
cor_vars <- cor_vars[cor_vars %in% names(primary)]
cor_data <- primary[, cor_vars]
cor_matrix <- cor(cor_data, use = "pairwise.complete.obs", method = "spearman")
cor_long <- do.call(rbind, lapply(seq_len(nrow(cor_matrix)), function(i) {
  data.frame(variable_1 = rownames(cor_matrix)[i], variable_2 = colnames(cor_matrix), spearman_rho = cor_matrix[i, ])
}))
cor_long <- cor_long[cor_long$variable_1 < cor_long$variable_2, ]

model_rows <- primary[
  !is.na(primary$poultry_farms_any_2022) &
    !is.na(primary$poultry_inventory_known_sum_2022) &
    !is.na(primary$mean_snow_goose_count_per_complete_checklist) &
    !is.na(primary$complete_checklists) &
    (!has_rice | !is.na(primary$rice_acres_cdl)),
]

scale_num <- function(x) as.numeric(scale(log1p(ifelse(is.na(x), 0, x))))
if (has_rice) {
  model_rows$z_rice_acres_cdl <- scale_num(model_rows$rice_acres_cdl)
}
model_rows$z_poultry_farms <- scale_num(model_rows$poultry_farms_any_2022)
model_rows$z_poultry_inventory <- scale_num(model_rows$poultry_inventory_known_sum_2022)
model_rows$z_snow_goose_mean <- scale_num(model_rows$mean_snow_goose_count_per_complete_checklist)
model_rows$z_checklists <- scale_num(model_rows$complete_checklists)
model_rows$z_wildbird_detections <- scale_num(model_rows$wildbird_detections)
model_rows$winter_season <- factor(model_rows$winter_season)
model_rows$any_poultry_outbreak <- as.integer(model_rows$poultry_outbreaks > 0)

if (has_rice) {
  count_formula <- poultry_outbreaks ~ z_rice_acres_cdl * z_snow_goose_mean +
    z_poultry_farms + z_poultry_inventory + z_checklists + winter_season
  binary_formula <- any_poultry_outbreak ~ z_rice_acres_cdl * z_snow_goose_mean +
    z_poultry_farms + z_poultry_inventory + z_checklists + winter_season
} else {
  count_formula <- poultry_outbreaks ~ z_poultry_farms + z_poultry_inventory +
    z_snow_goose_mean + z_checklists + winter_season
  binary_formula <- any_poultry_outbreak ~ z_poultry_farms + z_poultry_inventory +
    z_snow_goose_mean + z_checklists + winter_season
}

poisson_fit <- glm(count_formula, data = model_rows, family = poisson())

overdispersion <- sum(residuals(poisson_fit, type = "pearson")^2) / poisson_fit$df.residual

nb_fit <- MASS::glm.nb(count_formula, data = model_rows)

logit_fit <- glm(binary_formula, data = model_rows, family = binomial())

tidy_glm <- function(fit, model_name, exponentiate = FALSE) {
  co <- coef(summary(fit))
  estimate <- co[, "Estimate"]
  se <- co[, "Std. Error"]
  out <- data.frame(
    model = model_name,
    term = rownames(co),
    estimate = estimate,
    std_error = se,
    statistic = co[, if ("z value" %in% colnames(co)) "z value" else "t value"],
    p_value = co[, grep("^Pr", colnames(co), value = TRUE)[1]],
    conf_low = estimate - 1.96 * se,
    conf_high = estimate + 1.96 * se,
    row.names = NULL
  )
  if (exponentiate) {
    out$exp_estimate <- exp(out$estimate)
    out$exp_conf_low <- exp(out$conf_low)
    out$exp_conf_high <- exp(out$conf_high)
  }
  out
}

model_summary <- rbind(
  tidy_glm(poisson_fit, "poisson_count_primary_available_predictors", TRUE),
  tidy_glm(nb_fit, "negative_binomial_count_primary_available_predictors", TRUE),
  tidy_glm(logit_fit, "logistic_binary_primary_available_predictors", TRUE)
)

model_fit <- data.frame(
  model = c("poisson_count_primary_available_predictors", "negative_binomial_count_primary_available_predictors", "logistic_binary_primary_available_predictors"),
  n = c(nobs(poisson_fit), nobs(nb_fit), nobs(logit_fit)),
  aic = c(AIC(poisson_fit), AIC(nb_fit), AIC(logit_fit)),
  bic = c(BIC(poisson_fit), BIC(nb_fit), BIC(logit_fit)),
  poisson_overdispersion_ratio = c(overdispersion, NA, NA)
)

rq_status <- data.frame(
  research_question = c(
    "RQ1: flooded rice acreage and HPAI outbreak incidence",
    "RQ2: Lesser Snow Goose density and HPAI outbreak incidence",
    "RQ3: flooded rice acreage x Snow Goose density interaction"
  ),
  status = c(
    if (has_rice) "Testable with CDL primary source" else "Not final-testable yet",
    "Preliminary-testable with current eBird Snow Goose and HPAI data",
    if (has_rice) "Testable with CDL primary source" else "Not final-testable yet"
  ),
  reason = c(
    if (has_rice) "CDL annual rice acreage has been joined by county and winter start year; interpret as rice acreage/potential flooded rice habitat unless a winter inundation layer is added." else "Flooded rice acreage/proportion variable is not present in the project analytic data yet.",
    "Snow Goose county-winter metrics, poultry exposure covariates, and HPAI outcomes are present.",
    if (has_rice) "The centered CDL rice acreage x centered Snow Goose metric interaction is included in the dissertation-aligned models." else "Interaction requires both centered flooded rice variable and centered Snow Goose variable."
  ),
  immediate_output = c(
    if (has_rice) "Interpret CDL-based RQ1 model as primary rice-acreage analysis; add DWR as validation/sensitivity next." else "Prepare data structure and placeholder; do not interpret RQ1 hypothesis yet.",
    "Descriptives, Spearman correlations, logistic model, Poisson model, and negative binomial model.",
    if (has_rice) "Interpret interaction cautiously and validate with DWR/sensitivity source." else "Prepare model specification; run after rice variable is added."
  )
)

dictionary <- data.frame(
  variable = c(
    "county", "winter_season", "poultry_outbreaks", "any_poultry_outbreak",
    "mean_snow_goose_count_per_complete_checklist", "complete_checklists",
    "poultry_farms_any_2022", "poultry_inventory_known_sum_2022",
    "wildbird_detections", "waterfowl_detections",
    "flooded_rice_acreage_or_proportion"
  ),
  role = c(
    "Unit identifier", "Time identifier", "Primary count outcome", "Secondary binary outcome",
    "Primary available ecological predictor for RQ2", "eBird effort covariate",
    "Poultry exposure covariate", "Poultry exposure covariate",
    "Sensitivity ecological/surveillance covariate", "Sensitivity ecological/surveillance covariate",
    "Primary RQ1 predictor and RQ3 interaction component"
  ),
  source = c(
    "County names harmonized across datasets", "Derived Nov-Feb winter season",
    "USDA APHIS cleaned poultry records", "Derived from poultry_outbreaks",
    "eBird complete checklist county-winter summary", "eBird complete checklist county-winter summary",
    "USDA NASS 2022 Census of Agriculture Table 19", "USDA NASS 2022 Census of Agriculture Table 19",
    "USDA APHIS cleaned wild-bird records", "USDA APHIS cleaned wild-bird records",
    "Needed from USDA CDL/CropScape/DWR or other rice-flooding source"
  ),
  note = c(
    "Use county FIPS in final version if possible.", "Primary analysis currently complete winters 2022-2023 through 2024-2025.",
    "Sparse and overdispersed; negative binomial preferred over plain Poisson if overdispersion persists.",
    "Useful for logistic regression and easier committee interpretation.",
    "Effort-standardized proxy, not true population density.", "Controls observation effort.",
    "Static 2022 covariate; use cautiously across seasons.", "Known-sum variable has suppression/incompleteness flags.",
    "Surveillance-dependent; use as sensitivity, not clean exposure.", "Surveillance-dependent; waterfowl subset.",
    "Required before final RQ1/RQ3 hypothesis tests."
  )
)

write_csv(dat, file.path(out_dir, "spss_ready_county_winter_dataset.csv"))
write_csv(primary, file.path(out_dir, "primary_analysis_dataset.csv"))
write_csv(descriptives, file.path(out_dir, "table_1_descriptive_statistics.csv"))
write_csv(missingness, file.path(out_dir, "data_screening_missingness.csv"))
write_csv(by_winter, file.path(out_dir, "table_2_outbreaks_by_winter.csv"))
write_csv(cor_long, file.path(out_dir, "spearman_correlation_screening.csv"))
write_csv(model_summary, file.path(out_dir, "regression_model_outputs_available_predictors.csv"))
write_csv(model_fit, file.path(out_dir, "model_fit_and_assumption_checks.csv"))
write_csv(rq_status, file.path(out_dir, "research_question_analysis_status.csv"))
write_csv(dictionary, file.path(out_dir, "data_dictionary_current_and_needed_variables.csv"))

chapter4_notes <- c(
  "# Chapter 4 preliminary analysis notes",
  "",
  "These outputs are aligned to the quantitative checklist requirement to report descriptive statistics, assumption checks, and statistical findings organized by research question/hypothesis.",
  "",
  "## Software recommendation",
  "",
  "Use R as the primary statistical workflow and ArcGIS Pro for mapping/spatial diagnostics. Use SPSS only as an optional screening or committee-facing export. R is the better main platform here because the dissertation requires reproducible merging, count models, interaction terms, model diagnostics, and repeated updates as new spatial variables are added.",
  "",
  "## Current analysis readiness",
  "",
  "RQ1 and RQ3 are not final-testable yet because the flooded rice acreage/proportion variable is not present in the analytic dataset. RQ2 can be screened using the current Snow Goose and HPAI data.",
  "",
  "## Primary analysis window",
  "",
  "The current primary window is complete eBird winter seasons 2022-2023, 2023-2024, and 2024-2025. The 2025-2026 winter is partial in the eBird file and should be handled as a sensitivity period only after the full winter is available.",
  "",
  "## Preliminary model interpretation guardrails",
  "",
  "The currently available models should be treated as preliminary because the dissertation-specified flooded rice variable and climate covariates are not yet joined. The negative binomial count model is preferred over plain Poisson if the Poisson overdispersion ratio is meaningfully greater than 1.",
  "",
  "## Next outputs to create",
  "",
  "1. Add flooded rice acreage/proportion by county-winter.",
  "2. Add PRISM winter temperature/precipitation summaries.",
  "3. Restrict or flag the final dissertation population as Central Valley/rice-relevant counties.",
  "4. Run final RQ1/RQ2/RQ3 models with centered predictors and the rice x goose interaction.",
  "5. Export ArcGIS-ready county-winter layers and Moran's I/spatial clustering diagnostics.",
  ""
)
writeLines(chapter4_notes, file.path(out_dir, "chapter4_preliminary_analysis_notes.md"))

cat("Wrote Chapter 4 preliminary outputs to:", out_dir, "\n")
cat("Primary rows:", nrow(primary), "\n")
cat("Poisson overdispersion ratio:", round(overdispersion, 3), "\n")
cat("Use negative binomial if count outcome remains primary and overdispersion is present.\n")
