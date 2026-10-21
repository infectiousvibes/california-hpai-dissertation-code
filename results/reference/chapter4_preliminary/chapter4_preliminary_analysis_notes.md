# Chapter 4 preliminary analysis notes

These outputs are aligned to the quantitative checklist requirement to report descriptive statistics, assumption checks, and statistical findings organized by research question/hypothesis.

## Software recommendation

Use R as the primary statistical workflow and ArcGIS Pro for mapping/spatial diagnostics. Use SPSS only as an optional screening or committee-facing export. R is the better main platform here because the dissertation requires reproducible merging, count models, interaction terms, model diagnostics, and repeated updates as new spatial variables are added.

## Current analysis readiness

RQ1 and RQ3 are not final-testable yet because the flooded rice acreage/proportion variable is not present in the analytic dataset. RQ2 can be screened using the current Snow Goose and HPAI data.

## Primary analysis window

The current primary window is complete eBird winter seasons 2022-2023, 2023-2024, and 2024-2025. The 2025-2026 winter is partial in the eBird file and should be handled as a sensitivity period only after the full winter is available.

## Preliminary model interpretation guardrails

The currently available models should be treated as preliminary because the dissertation-specified flooded rice variable and climate covariates are not yet joined. The negative binomial count model is preferred over plain Poisson if the Poisson overdispersion ratio is meaningfully greater than 1.

## Next outputs to create

1. Add flooded rice acreage/proportion by county-winter.
2. Add PRISM winter temperature/precipitation summaries.
3. Restrict or flag the final dissertation population as Central Valley/rice-relevant counties.
4. Run final RQ1/RQ2/RQ3 models with centered predictors and the rice x goose interaction.
5. Export ArcGIS-ready county-winter layers and Moran's I/spatial clustering diagnostics.

