# Chapter 4 Results Interpretation Draft

## Analysis Status

The current analysis includes the core dissertation variables that are available and analysis-ready:

- HPAI poultry outbreak incidence from cleaned USDA APHIS records.
- USDA CDL rice acreage for 2020-2025.
- eBird Snow Goose county-winter metrics for complete winter seasons.
- USDA NASS 2022 poultry exposure covariates.
- PRISM winter temperature and precipitation summaries.

The primary analysis window is complete winter seasons 2022-2023, 2023-2024, and 2024-2025. The 2025-2026 winter is not used in the primary models because the eBird winter file is partial for that season.

The primary dissertation-focused population is rice-producing counties, defined as California counties with at least 1,000 CDL rice acres in any primary crop year from 2022 through 2024. This produced 36 county-winter observations across 12 counties. A statewide sensitivity analysis was also conducted using 174 county-winter observations across all 58 California counties.

## Descriptive Findings

In the rice-producing county primary dataset, poultry HPAI outbreaks increased across the study period:

- 2022-2023: 3 outbreaks across 3 counties.
- 2023-2024: 10 outbreaks across 3 counties.
- 2024-2025: 31 outbreaks across 6 counties.

In the statewide sensitivity dataset, poultry HPAI outbreaks also increased:

- 2022-2023: 5 outbreaks across 5 counties.
- 2023-2024: 25 outbreaks across 7 counties.
- 2024-2025: 60 outbreaks across 13 counties.

The highest outbreak-burden counties in the statewide dataset were Merced, Stanislaus, Fresno, Sonoma, Tulare, San Joaquin, Riverside, Kern, Sacramento, Kings, Marin, Butte, and Glenn.

## Assumption and Model Selection Findings

The count outcome was sparse and overdispersed. In the rice-producing county primary dataset, 66.7% of county-winter observations had zero poultry outbreaks. In the statewide sensitivity dataset, 85.6% of county-winter observations had zero poultry outbreaks.

Poisson overdispersion ratios were above 1 for all research-question models:

- Rice-producing primary dataset: approximately 1.90 to 2.18.
- Statewide sensitivity dataset: approximately 4.84 to 5.22.

Because of this overdispersion, negative binomial regression is more appropriate than ordinary Poisson regression for the poultry outbreak count outcome. Logistic regression was retained as a secondary analysis for the binary outcome of any poultry outbreak.

The statewide Moran's I diagnostic for mean county-level Pearson residuals from the RQ3 negative binomial model was near zero and not statistically significant (Moran's I = 0.021, permutation p = 0.820), suggesting no strong residual spatial autocorrelation in the statewide sensitivity model.

## RQ1 Interpretation

RQ1 asked whether rice acreage was associated with HPAI poultry outbreak incidence.

In the primary rice-producing county negative binomial model, CDL rice acreage was not statistically significant after adjustment for poultry inventory, eBird checklist effort, winter temperature, and winter precipitation. The adjusted rate ratio for rice acreage was 0.75, p = .271.

The statewide sensitivity negative binomial model also did not show a statistically significant adjusted association between CDL rice acreage and outbreak count. The adjusted rate ratio was 1.25, p = .383.

Current interpretation: The analysis does not provide evidence to reject the null hypothesis for RQ1 in the adjusted negative binomial models. Poultry inventory, rather than rice acreage, showed the clearest association with outbreak count.

## RQ2 Interpretation

RQ2 asked whether Lesser Snow Goose density was associated with HPAI poultry outbreak incidence.

In the primary rice-producing county negative binomial model, the Snow Goose metric was not statistically significant after adjustment for poultry inventory, eBird checklist effort, winter temperature, and winter precipitation. The adjusted rate ratio was 1.10, p = .762.

In the statewide sensitivity negative binomial model, the Snow Goose metric was also not statistically significant. The adjusted rate ratio was 1.02, p = .943.

Current interpretation: The analysis does not provide evidence to reject the null hypothesis for RQ2 in the adjusted models. The eBird Snow Goose metric may still be ecologically meaningful, but it did not independently explain county-winter poultry outbreak incidence after adjustment.

## RQ3 Interpretation

RQ3 asked whether the relationship between rice acreage and HPAI poultry outbreak incidence varied by Snow Goose density.

In the primary rice-producing county negative binomial model, the rice acreage by Snow Goose interaction was not statistically significant. The interaction rate ratio was 1.47, p = .426.

In the statewide sensitivity negative binomial model, the interaction was also not statistically significant. The interaction rate ratio was 0.81, p = .426.

Current interpretation: The analysis does not provide evidence to reject the null hypothesis for RQ3. The current data do not show a statistically significant interaction between CDL rice acreage and the Snow Goose metric in predicting poultry HPAI outbreak counts.

## Covariate Findings

Across most models, poultry inventory was the most consistent predictor of outbreak incidence. In the primary rice-producing county models, the poultry inventory adjusted rate ratio ranged from approximately 2.69 to 4.28 depending on model specification. In statewide sensitivity models, poultry inventory was also consistently significant.

Winter precipitation was negatively associated with poultry outbreak count in multiple count models. This result should be interpreted cautiously because precipitation may be acting as a seasonal/ecological proxy rather than a direct causal factor.

## DWR Validation

DWR Statewide Crop Mapping was processed as a supplemental validation source for 2020-2024. DWR rice acreage totals were consistently lower than CDL totals, but the county-level rankings were strongly aligned.

Total DWR versus CDL rice acreage:

- 2020: DWR 512,331 acres; CDL 542,376 acres; Spearman rho = 0.748.
- 2021: DWR 406,386 acres; CDL 430,914 acres; Spearman rho = 0.733.
- 2022: DWR 249,832 acres; CDL 273,095 acres; Spearman rho = 0.712.
- 2023: DWR 518,119 acres; CDL 557,372 acres; Spearman rho = 0.710.
- 2024: DWR 468,797 acres; CDL 500,541 acres; Spearman rho = 0.800. The 2024 DWR layer is provisional.

This supports use of CDL as the primary source while using DWR as a California-specific validation source. The two sources are not identical, but they identify the same main rice-producing counties.

## Reporting Caution

The CDL- and DWR-derived variables should be reported as rice acreage or potential rice-field habitat, not directly observed flooded rice acreage. A true flooded-rice measure would require a winter inundation or post-harvest flooding data layer.
