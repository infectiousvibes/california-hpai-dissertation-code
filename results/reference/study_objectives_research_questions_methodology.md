# First-pass analysis plan

## Study framing inferred from current files

Objective 1: Describe California county-winter HPAI poultry outbreak patterns during the current outbreak era.

Objective 2: Estimate whether county-level poultry exposure is associated with poultry HPAI outbreak occurrence.

Objective 3: Estimate whether winter Snow Goose abundance/observation pressure is associated with poultry HPAI outbreak occurrence after accounting for poultry exposure and eBird effort.

Objective 4: Use APHIS wild-bird detections as a sensitivity/secondary indicator of local viral activity, not as the clean primary exposure, because those detections are surveillance-dependent and can be downstream of outbreak attention.

## Proposed research questions

RQ1: Which California counties and winter seasons had the highest poultry HPAI outbreak burden?

RQ2: Are counties with more poultry farms or larger known poultry inventories more likely to report poultry HPAI outbreaks?

RQ3: Are county-winters with greater Snow Goose abundance in eBird more likely to experience poultry HPAI outbreaks, controlling for poultry exposure and checklist effort?

RQ4: Do APHIS wild-bird detections add explanatory signal beyond Snow Goose abundance and poultry exposure?

## Primary methodology

Unit of analysis: California county-winter.

Winter definition: November-February. November/December are assigned to that year's winter start; January/February are assigned to the prior winter.

Primary analysis window: complete eBird winters overlapping APHIS poultry outbreak data, currently 2022-2023, 2023-2024, and 2024-2025. The 2025-2026 Snow Goose file is partial and should not be used in the primary analysis until complete.

Primary outcome: any poultry HPAI outbreak in the county-winter. Secondary outcome: outbreak count.

Primary predictors: 2022 poultry farms, known poultry inventory, mean Snow Goose count per complete checklist, and complete eBird checklist count as effort adjustment.

Initial model: logistic regression for any poultry outbreak. Treat results as exploratory because outcomes are sparse, poultry inventory has USDA suppression, and counties are repeated over winters.

Next stronger model: if the committee wants inference rather than exploration, use a repeated-measures model such as GEE or mixed-effects logistic regression, and add spatial sensitivity checks.

## Data limitations to report

USDA Ag Census poultry inventory is from 2022 only and has suppressed cells; use the known-sum inventory variables carefully.

eBird counts are effort-dependent; include checklist effort and prefer complete-checklist metrics.

APHIS wild-bird detections reflect surveillance and mortality reporting, not true wild-bird prevalence.

PRISM climate summaries are not yet in the analytic table because a county boundary file/output climate CSV is not present in this project folder.

