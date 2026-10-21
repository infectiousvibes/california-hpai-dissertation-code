# ArcGIS Dissertation Spatial Analysis

Purpose: These outputs support the dissertation's spatial interpretation by showing where rice acreage, Snow Goose activity, poultry exposure, and poultry HPAI outbreaks converge geographically.

Key GIS layers added to the GeoPackage:

- dissertation_convergence_county_totals
- convergence_2022_2023
- convergence_2023_2024
- convergence_2024_2025

Important fields:

- rice_rank: county percentile-like rank for CDL rice acreage.
- goose_rank: rank for mean Snow Goose count per complete checklist.
- poultry_inventory_rank: rank for poultry inventory exposure.
- rice_goose_convergence: average of rice and Snow Goose ranks.
- one_health_convergence: average of rice, Snow Goose, and poultry inventory ranks.
- convergence_class: qualitative class for map symbology and interpretation.

How this relates to the dissertation:

The regression models test whether rice acreage, Snow Goose activity, and their interaction independently predict outbreak incidence after adjustment. The GIS analysis asks a complementary spatial question: where do the ecological and agricultural risk components overlap? A map may show spatial convergence even when adjusted regression coefficients are not statistically significant.

Recommended ArcGIS maps:

1. Symbolize dissertation_convergence_county_totals by one_health_convergence using graduated color.
2. Overlay graduated symbols for poultry_outbreaks.
3. Make separate maps for convergence_2022_2023, convergence_2023_2024, and convergence_2024_2025 to show seasonal progression.
4. Symbolize convergence_class with unique values for a dissertation-friendly categorical map.

Interpretation caution: This remains ecological, county-level evidence. It supports visual/spatial interpretation and hypothesis generation; it does not override the adjusted regression results.

