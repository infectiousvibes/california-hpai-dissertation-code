#!/usr/bin/env Rscript
# Integration check against the supplied dissertation result snapshots.
base <- "analysis_outputs/dissertation_analysis"
if (!file.exists(file.path(base, "rq_model_results.csv"))) stop("Run scripts/run_analysis.R first.")
primary <- read.csv(file.path(base, "primary_rice_producing_county_dataset.csv"))
statewide <- read.csv(file.path(base, "statewide_sensitivity_dataset.csv"))
stopifnot(nrow(primary) == 36, length(unique(primary$county)) == 12,
          nrow(statewide) == 174, length(unique(statewide$county)) == 58,
          !anyDuplicated(primary[c("county", "winter_season")]),
          !anyDuplicated(statewide[c("county", "winter_season")]))
for (name in c("rq_model_results.csv", "model_fit_summary.csv", "full_county_winter_analysis_dataset.csv")) {
  actual <- read.csv(file.path(base, name), check.names = FALSE)
  expected <- read.csv(file.path("results/reference/dissertation_analysis", name), check.names = FALSE)
  check <- all.equal(actual, expected, tolerance = 1e-8, check.attributes = FALSE)
  if (!isTRUE(check)) stop(name, " differs from archived results: ", paste(check, collapse = "; "))
  cat("PASS ", name, " (", nrow(actual), " rows)\n", sep = "")
}
fit <- read.csv(file.path(base, "model_fit_summary.csv"))
stopifnot(nrow(fit) == 12, all(fit$converged), all(is.na(fit$error) | fit$error == ""))
cat("PASS sample sizes, unique county-winter keys, and all 12 model fits.\n")
