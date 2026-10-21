# Methods and interpretation

The main entry point is `scripts/dissertation_final_analysis.R`; the runner
first rebuilds its base model dataset with `analyze_county_winter_hpai.R`.
Earlier first-pass and Chapter 4 scripts preserve the development history and
may write notes describing data as unavailable when they were written. Use
the final analysis and the actual included inputs for the current workflow.

The final model formulas test standardized log-transformed rice acreage,
Snow Goose count per complete checklist, and their interaction, adjusting
for known poultry inventory, complete checklist effort, mean temperature,
and precipitation. Variables are standardized separately within the primary
and statewide populations. The final formulas do not include winter fixed
effects or repeated-county random effects.

The supplied code replaces missing values with zero for several transformations
and treats missing outbreak counts as zero. This behavior is preserved for
reproducibility; it is not a new assessment of whether zero is appropriate.
USDA suppressed inventory cells remain flagged in the poultry census input;
known-sum inventories are incomplete where suppression is present.

These are ecological observational associations. Sparse outcomes, repeated
county observations, surveillance differences, and the small primary sample
limit interpretation. Null hypothesis tests do not establish absence of an
association or mechanism. Descriptive spatial convergence maps do not replace
adjusted regression findings.

The statewide RQ3 negative binomial model also has a residual Moran's I
permutation diagnostic using county adjacency and mean county residuals.
The runner uses seed 20261021. Reference permutation p-values may differ
because the original code did not set a seed.

No scientific formulas, sample thresholds, outcomes, or imputation rules were
changed during repository preparation. Portability changes are documented
in the source manifest and execution guide.
