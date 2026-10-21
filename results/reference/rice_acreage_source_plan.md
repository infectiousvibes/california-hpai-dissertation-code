# Rice Acreage Source Plan

## Decision

Use USDA NASS Cropland Data Layer (CDL) as the primary annual rice acreage source for 2020-2025. Use California Department of Water Resources (DWR) Statewide Crop Mapping as a California-specific supplemental/validation source for 2020-2024, with 2024 treated as provisional if used.

## Important variable wording

The current defensible variable from CDL and DWR crop mapping is rice acreage or potential rice-field habitat acreage. These sources identify crop/land-use class, not whether a rice field was actually flooded during the post-harvest winter period.

Recommended dissertation wording until a winter inundation layer is added:

- `rice_acres_cdl`: annual county-level rice acreage from USDA CDL class code 3.
- `rice_acres_dwr`: annual county-level rice acreage from DWR Statewide Crop Mapping.
- `potential_flooded_rice_habitat`: interpretive proxy if the committee accepts rice acreage as a proxy for rice-field habitat that may be post-harvest flooded.

Avoid calling the CDL/DWR variable `flooded_rice_acres` unless a flooding/inundation data layer is added or the method explicitly justifies rice acreage as a proxy.

## Current scripts

- `scripts/build_cdl_rice_county_acres.R`: extracts annual CDL rice acreage by California county.
- `scripts/download_dwr_crop_mapping_sources.R`: downloads DWR Statewide Crop Mapping shapefiles for supplemental validation.

## Source notes

USDA CDL is an annual raster land-cover product. CDL class code 3 represents rice.

DWR Statewide Crop Mapping provides field-scale statewide land-use/crop mapping used for water-use planning and related analyses. The 2024 statewide crop mapping release is provisional.

## Next method step

After county-level rice acreage is produced, join it to the county-winter analytic table by assigning each winter season to the rice crop year from the winter start year, for example:

- winter 2022-2023 uses 2022 rice acreage;
- winter 2023-2024 uses 2023 rice acreage;
- winter 2024-2025 uses 2024 rice acreage.

This matches the dissertation's county-winter unit of analysis while preserving the annual timing of the CDL/DWR crop maps.
