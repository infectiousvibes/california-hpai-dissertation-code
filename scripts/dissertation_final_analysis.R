#!/usr/bin/env Rscript

# Dissertation analysis pipeline:
# RQ1: rice acreage and HPAI outbreak incidence
# RQ2: Snow Goose density and HPAI outbreak incidence
# RQ3: rice acreage x Snow Goose density interaction

suppressPackageStartupMessages({
  required <- c("MASS", "dplyr", "readr", "sf")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop("Missing required R package(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  library(MASS)
  library(dplyr)
  library(readr)
  library(sf)
})

project_dir <- normalizePath(".", mustWork = TRUE)
out_dir <- file.path(project_dir, "analysis_outputs", "dissertation_analysis")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

read_csv <- function(path) read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
write_csv <- function(df, path) write.csv(df, path, row.names = FALSE, na = "")

source_data <- read_csv(file.path(project_dir, "analysis_outputs", "analysis_county_winter_model_data.csv"))
rice <- read_csv(file.path(project_dir, "analysis_outputs", "cdl_county_rice_acres_2020_2025.csv"))
climate <- read_csv(file.path(project_dir, "analysis_outputs", "prism_county_winter_2020_2025.csv"))

rice_keep <- rice[, c("county", "county_fips", "year", "rice_acres_cdl")]
names(rice_keep)[names(rice_keep) == "year"] <- "winter_start_year"

dat <- merge(source_data, rice_keep, by = c("county", "winter_start_year"), all.x = TRUE)
dat <- merge(dat, climate[, c("county", "winter_start_year", "winter_tmean_c", "winter_ppt_mm")], by = c("county", "winter_start_year"), all.x = TRUE)

dat$any_poultry_outbreak <- as.integer(dat$poultry_outbreaks > 0)
dat$primary_complete_winter <- dat$winter_season %in% c("2022-2023", "2023-2024", "2024-2025") &
  dat$complete_ebird_winter == TRUE

primary_years <- 2022:2024
rice_counties <- rice %>%
  filter(year %in% primary_years) %>%
  group_by(county) %>%
  summarise(max_rice_acres_2022_2024 = max(rice_acres_cdl, na.rm = TRUE), .groups = "drop") %>%
  mutate(rice_producing_county = max_rice_acres_2022_2024 >= 1000)

dat <- merge(dat, rice_counties, by = "county", all.x = TRUE)
dat$rice_producing_county[is.na(dat$rice_producing_county)] <- FALSE
dat$log_rice_acres_cdl <- log1p(ifelse(is.na(dat$rice_acres_cdl), 0, dat$rice_acres_cdl))
dat$log_snow_goose_mean <- log1p(ifelse(is.na(dat$mean_snow_goose_count_per_complete_checklist), 0, dat$mean_snow_goose_count_per_complete_checklist))
dat$log_poultry_inventory <- log1p(ifelse(is.na(dat$poultry_inventory_known_sum_2022), 0, dat$poultry_inventory_known_sum_2022))
dat$log_poultry_farms <- log1p(ifelse(is.na(dat$poultry_farms_any_2022), 0, dat$poultry_farms_any_2022))
dat$log_checklists <- log1p(ifelse(is.na(dat$complete_checklists), 0, dat$complete_checklists))
dat$log_wildbird_detections <- log1p(ifelse(is.na(dat$wildbird_detections), 0, dat$wildbird_detections))

z <- function(x) as.numeric(scale(x))
scale_model_data <- function(x) {
  x$z_rice <- z(x$log_rice_acres_cdl)
  x$z_goose <- z(x$log_snow_goose_mean)
  x$z_poultry_inventory <- z(x$log_poultry_inventory)
  x$z_poultry_farms <- z(x$log_poultry_farms)
  x$z_checklists <- z(x$log_checklists)
  x$z_tmean <- z(x$winter_tmean_c)
  x$z_ppt <- z(log1p(ifelse(is.na(x$winter_ppt_mm), 0, x$winter_ppt_mm)))
  x$z_wildbird <- z(x$log_wildbird_detections)
  x$winter_season <- factor(x$winter_season)
  x
}

statewide <- dat[dat$primary_complete_winter == TRUE, ]
rice_primary <- statewide[statewide$rice_producing_county == TRUE, ]
statewide <- scale_model_data(statewide)
rice_primary <- scale_model_data(rice_primary)

tidy_glm <- function(fit, model_name, population, rq, exponentiate = TRUE) {
  co <- coef(summary(fit))
  p_col <- grep("^Pr", colnames(co), value = TRUE)[1]
  stat_col <- if ("z value" %in% colnames(co)) "z value" else "t value"
  out <- data.frame(
    research_question = rq,
    population = population,
    model = model_name,
    term = rownames(co),
    estimate = co[, "Estimate"],
    std_error = co[, "Std. Error"],
    statistic = co[, stat_col],
    p_value = co[, p_col],
    row.names = NULL
  )
  out$conf_low <- out$estimate - 1.96 * out$std_error
  out$conf_high <- out$estimate + 1.96 * out$std_error
  if (exponentiate) {
    out$rate_or_odds_ratio <- exp(out$estimate)
    out$rr_or_or_low <- exp(out$conf_low)
    out$rr_or_or_high <- exp(out$conf_high)
  }
  out
}

fit_nb_safe <- function(formula, data) {
  tryCatch(
    suppressWarnings(MASS::glm.nb(formula, data = data, control = glm.control(maxit = 100))),
    error = function(e) e
  )
}

fit_logit_safe <- function(formula, data) {
  tryCatch(
    suppressWarnings(glm(formula, data = data, family = binomial(), control = glm.control(maxit = 100))),
    error = function(e) e
  )
}

model_specs <- list(
  RQ1 = list(
    count = poultry_outbreaks ~ z_rice + z_poultry_inventory + z_checklists + z_tmean + z_ppt,
    binary = any_poultry_outbreak ~ z_rice + z_poultry_inventory + z_checklists + z_tmean + z_ppt
  ),
  RQ2 = list(
    count = poultry_outbreaks ~ z_goose + z_poultry_inventory + z_checklists + z_tmean + z_ppt,
    binary = any_poultry_outbreak ~ z_goose + z_poultry_inventory + z_checklists + z_tmean + z_ppt
  ),
  RQ3 = list(
    count = poultry_outbreaks ~ z_rice * z_goose + z_poultry_inventory + z_checklists + z_tmean + z_ppt,
    binary = any_poultry_outbreak ~ z_rice * z_goose + z_poultry_inventory + z_checklists + z_tmean + z_ppt
  )
)

populations <- list(
  rice_producing_counties_primary = rice_primary,
  statewide_sensitivity = statewide
)

model_tables <- list()
fit_tables <- list()
fits <- list()

for (pop_name in names(populations)) {
  pop_data <- populations[[pop_name]]
  for (rq in names(model_specs)) {
    nb <- fit_nb_safe(model_specs[[rq]]$count, pop_data)
    logit <- fit_logit_safe(model_specs[[rq]]$binary, pop_data)

    if (!inherits(nb, "error")) {
      model_tables[[length(model_tables) + 1]] <- tidy_glm(nb, "negative_binomial_count", pop_name, rq)
      fit_tables[[length(fit_tables) + 1]] <- data.frame(
        research_question = rq,
        population = pop_name,
        model = "negative_binomial_count",
        n = nobs(nb),
        aic = AIC(nb),
        bic = BIC(nb),
        theta = nb$theta,
        converged = nb$converged,
        error = NA_character_
      )
      fits[[paste(pop_name, rq, "nb", sep = "_")]] <- nb
    } else {
      fit_tables[[length(fit_tables) + 1]] <- data.frame(research_question = rq, population = pop_name, model = "negative_binomial_count", n = nrow(pop_data), aic = NA, bic = NA, theta = NA, converged = FALSE, error = nb$message)
    }

    if (!inherits(logit, "error")) {
      model_tables[[length(model_tables) + 1]] <- tidy_glm(logit, "logistic_binary", pop_name, rq)
      fit_tables[[length(fit_tables) + 1]] <- data.frame(
        research_question = rq,
        population = pop_name,
        model = "logistic_binary",
        n = nobs(logit),
        aic = AIC(logit),
        bic = BIC(logit),
        theta = NA,
        converged = logit$converged,
        error = NA_character_
      )
      fits[[paste(pop_name, rq, "logit", sep = "_")]] <- logit
    } else {
      fit_tables[[length(fit_tables) + 1]] <- data.frame(research_question = rq, population = pop_name, model = "logistic_binary", n = nrow(pop_data), aic = NA, bic = NA, theta = NA, converged = FALSE, error = logit$message)
    }
  }
}

model_results <- dplyr::bind_rows(model_tables)
model_fit <- dplyr::bind_rows(fit_tables)

poisson_overdispersion <- function(formula, data) {
  fit <- glm(formula, data = data, family = poisson())
  sum(residuals(fit, type = "pearson")^2) / fit$df.residual
}

assumptions <- dplyr::bind_rows(lapply(names(populations), function(pop_name) {
  pop_data <- populations[[pop_name]]
  dplyr::bind_rows(lapply(names(model_specs), function(rq) {
    data.frame(
      population = pop_name,
      research_question = rq,
      n = nrow(pop_data),
      zero_count_outcome_n = sum(pop_data$poultry_outbreaks == 0),
      zero_count_outcome_pct = mean(pop_data$poultry_outbreaks == 0) * 100,
      poisson_overdispersion_ratio = poisson_overdispersion(model_specs[[rq]]$count, pop_data),
      missing_model_variables_n = sum(!complete.cases(model.frame(model_specs[[rq]]$count, pop_data)))
    )
  }))
}))

describe <- function(x) {
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

desc_vars <- c(
  "rice_acres_cdl", "mean_snow_goose_count_per_complete_checklist",
  "poultry_outbreaks", "poultry_birds_affected", "poultry_inventory_known_sum_2022",
  "complete_checklists", "winter_tmean_c", "winter_ppt_mm", "wildbird_detections"
)

descriptives <- dplyr::bind_rows(lapply(names(populations), function(pop_name) {
  pop_data <- populations[[pop_name]]
  dplyr::bind_rows(lapply(desc_vars, function(v) {
    out <- describe(pop_data[[v]])
    out$population <- pop_name
    out$variable <- v
    out[, c("population", "variable", setdiff(names(out), c("population", "variable")))]
  }))
}))

by_winter <- dplyr::bind_rows(lapply(names(populations), function(pop_name) {
  populations[[pop_name]] %>%
    group_by(winter_season) %>%
    summarise(
      population = pop_name,
      county_winters = n(),
      counties_with_outbreak = sum(any_poultry_outbreak),
      poultry_outbreaks = sum(poultry_outbreaks),
      poultry_birds_affected = sum(poultry_birds_affected),
      rice_acres_cdl = sum(rice_acres_cdl, na.rm = TRUE),
      mean_snow_goose_per_checklist = mean(mean_snow_goose_count_per_complete_checklist, na.rm = TRUE),
      winter_ppt_mm_mean = mean(winter_ppt_mm, na.rm = TRUE),
      winter_tmean_c_mean = mean(winter_tmean_c, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    select(population, everything())
}))

county_totals <- statewide %>%
  group_by(county, county_fips, rice_producing_county, max_rice_acres_2022_2024) %>%
  summarise(
    poultry_outbreaks = sum(poultry_outbreaks),
    poultry_birds_affected = sum(poultry_birds_affected),
    mean_rice_acres_cdl = mean(rice_acres_cdl, na.rm = TRUE),
    mean_snow_goose_per_checklist = mean(mean_snow_goose_count_per_complete_checklist, na.rm = TRUE),
    wildbird_detections = sum(wildbird_detections),
    .groups = "drop"
  ) %>%
  arrange(desc(poultry_outbreaks), desc(poultry_birds_affected))

cor_vars <- c("log_rice_acres_cdl", "log_snow_goose_mean", "log_poultry_inventory", "log_checklists", "winter_tmean_c", "winter_ppt_mm", "poultry_outbreaks")
cor_screen <- dplyr::bind_rows(lapply(names(populations), function(pop_name) {
  cmat <- cor(populations[[pop_name]][, cor_vars], use = "pairwise.complete.obs", method = "spearman")
  out <- do.call(rbind, lapply(seq_len(nrow(cmat)), function(i) {
    data.frame(population = pop_name, variable_1 = rownames(cmat)[i], variable_2 = colnames(cmat), spearman_rho = cmat[i, ])
  }))
  out[out$variable_1 < out$variable_2, ]
}))

custom_moran <- function(county_values, value_col, permutations = 999) {
  counties <- sf::read_sf(file.path(project_dir, "spatial_boundaries", "ca_counties_2024.gpkg")) %>%
    filter(STATEFP == "06") %>%
    mutate(county = sub(" County$", "", NAME)) %>%
    inner_join(county_values, by = "county")

  nb <- sf::st_touches(counties)
  x <- counties[[value_col]]
  keep <- !is.na(x)
  counties <- counties[keep, ]
  x <- x[keep]
  nb <- sf::st_touches(counties)
  n <- length(x)
  x_centered <- x - mean(x)
  denom <- sum(x_centered^2)
  links <- do.call(rbind, lapply(seq_along(nb), function(i) {
    if (length(nb[[i]]) == 0) return(NULL)
    cbind(i, nb[[i]])
  }))
  if (is.null(links) || nrow(links) == 0 || denom == 0) {
    return(data.frame(n = n, moran_i = NA, permutation_p_two_sided = NA))
  }
  links <- links[links[, 1] != links[, 2], , drop = FALSE]
  s0 <- nrow(links)
  obs <- (n / s0) * sum(x_centered[links[, 1]] * x_centered[links[, 2]]) / denom
  perm <- replicate(permutations, {
    xp <- sample(x_centered)
    (n / s0) * sum(xp[links[, 1]] * xp[links[, 2]]) / sum(xp^2)
  })
  data.frame(n = n, moran_i = obs, permutation_p_two_sided = mean(abs(perm) >= abs(obs)))
}

spatial_rows <- list()
for (key in names(fits)) {
  if (grepl("RQ3_nb$", key)) {
    fit <- fits[[key]]
    mf <- model.frame(fit)
    residual_values <- data.frame(
      county = rownames(mf),
      residual = residuals(fit, type = "pearson")
    )
  }
}

# Explicit county-residual Moran's I for the statewide RQ3 negative-binomial model.
if ("statewide_sensitivity_RQ3_nb" %in% names(fits)) {
  fit <- fits[["statewide_sensitivity_RQ3_nb"]]
  d <- statewide
  needed <- c("poultry_outbreaks", "z_rice", "z_goose", "z_poultry_inventory", "z_checklists", "z_tmean", "z_ppt")
  d_model <- d[complete.cases(d[, needed]), ]
  if (nrow(d_model) == length(residuals(fit, type = "pearson"))) {
    d_model$residual_rq3_nb <- residuals(fit, type = "pearson")
    county_resid <- d_model %>%
      group_by(county) %>%
      summarise(residual_rq3_nb = mean(residual_rq3_nb, na.rm = TRUE), .groups = "drop")
    spatial_rows[[1]] <- cbind(
      population = "statewide_sensitivity",
      model = "RQ3 negative_binomial_count mean county Pearson residuals",
      custom_moran(county_resid, "residual_rq3_nb", permutations = 499)
    )
  }
}
spatial_diagnostics <- if (length(spatial_rows) > 0) dplyr::bind_rows(spatial_rows) else data.frame()

write_csv(dat, file.path(out_dir, "full_county_winter_analysis_dataset.csv"))
write_csv(rice_primary, file.path(out_dir, "primary_rice_producing_county_dataset.csv"))
write_csv(statewide, file.path(out_dir, "statewide_sensitivity_dataset.csv"))
write_csv(descriptives, file.path(out_dir, "table_1_descriptive_statistics_by_population.csv"))
write_csv(by_winter, file.path(out_dir, "table_2_descriptive_by_winter.csv"))
write_csv(county_totals, file.path(out_dir, "table_3_county_totals_ranked.csv"))
write_csv(cor_screen, file.path(out_dir, "assumption_spearman_correlation_screening.csv"))
write_csv(assumptions, file.path(out_dir, "assumption_count_model_overdispersion.csv"))
write_csv(model_fit, file.path(out_dir, "model_fit_summary.csv"))
write_csv(model_results, file.path(out_dir, "rq_model_results.csv"))
write_csv(spatial_diagnostics, file.path(out_dir, "spatial_residual_diagnostics_moran_i.csv"))

summary_lines <- c(
  "# Dissertation Analysis Summary",
  "",
  "Primary analysis window: complete winters 2022-2023, 2023-2024, and 2024-2025.",
  "",
  paste0("Statewide sensitivity dataset: ", nrow(statewide), " county-winters across ", length(unique(statewide$county)), " counties."),
  paste0("Rice-producing primary dataset: ", nrow(rice_primary), " county-winters across ", length(unique(rice_primary$county)), " counties."),
  "",
  "Rice-producing counties were defined as counties with at least 1,000 CDL rice acres in any primary analysis crop year (2022-2024). This keeps the primary dissertation analysis aligned with the rice-field ecology research questions while retaining statewide results as sensitivity analyses.",
  "",
  "USDA CDL and DWR crop maps should be described as rice acreage / potential rice-field habitat unless a winter inundation layer is added. The current models use CDL rice acreage as the primary source.",
  "",
  "Negative binomial regression is preferred for count outcomes when Poisson overdispersion is present. Logistic regression is retained as a secondary binary-outcome analysis for any poultry outbreak.",
  ""
)
writeLines(summary_lines, file.path(out_dir, "analysis_summary.md"))

png(file.path(out_dir, "figure_outbreaks_by_winter_primary.png"), width = 1400, height = 900, res = 150)
tmp <- by_winter[by_winter$population == "rice_producing_counties_primary", ]
barplot(tmp$poultry_outbreaks, names.arg = tmp$winter_season, col = "#4B8BBE", border = NA, ylab = "Poultry HPAI outbreaks", xlab = "Winter season", main = "Poultry HPAI outbreaks in rice-producing counties")
dev.off()

png(file.path(out_dir, "figure_rice_vs_outbreaks_primary.png"), width = 1400, height = 900, res = 150)
plot(rice_primary$rice_acres_cdl, rice_primary$poultry_outbreaks, pch = 19, col = "#4B8BBE", xlab = "CDL rice acreage", ylab = "Poultry HPAI outbreaks", main = "County-winter outbreaks vs. CDL rice acreage")
grid()
dev.off()

png(file.path(out_dir, "figure_goose_vs_outbreaks_primary.png"), width = 1400, height = 900, res = 150)
plot(rice_primary$mean_snow_goose_count_per_complete_checklist, rice_primary$poultry_outbreaks, pch = 19, col = "#C44E52", xlab = "Mean Snow Goose count per complete checklist", ylab = "Poultry HPAI outbreaks", main = "County-winter outbreaks vs. Snow Goose metric")
grid()
dev.off()

cat("Wrote dissertation analysis outputs to:", out_dir, "\n")
cat("Primary rice-producing county-winters:", nrow(rice_primary), "\n")
cat("Statewide sensitivity county-winters:", nrow(statewide), "\n")
