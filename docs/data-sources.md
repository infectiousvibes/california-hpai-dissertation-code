# Data and provenance

The supplied archive is the source of the committed snapshots. Original paths
are recorded relative to that archive in `source_manifest.csv`; SHA-256 columns
identify the source bytes and repository bytes. Adapted scripts have different
checksums because personal paths were replaced. Newly written support files
are identified by their absence from that import manifest.

| Input | Source and role |
| --- | --- |
| `ca_county_poultry_census_2022.csv` | USDA 2022 Census of Agriculture; farm counts and known inventory sums; 58 counties |
| `ca_agcensus_2022_county_all_tables.txt` | Supplied extracted census text consumed by the census extraction script |
| `california_county_winter_snow_goose_2020_2025.csv` | Supplied eBird county-winter summary; 406 rows including partial boundary winters |
| `data/prepared/hpai/county_winter_hpai_ca_summary.csv` | Supplied cleaned APHIS poultry and wild-bird aggregate counts |
| `data/prepared/hpai/county_month_hpai_ca_summary.csv` | Supplied monthly APHIS aggregate for reference |
| `data/prepared/analysis_county_winter_model_data.csv` | Archived merged model input, retained for comparison; runner rebuilds it |
| `data/prepared/cdl_county_rice_acres_2020_2025.csv` | Supplied USDA CDL county-year rice acreage, class code 3 |
| `data/prepared/prism_county_winter_2020_2025.csv` | Supplied PRISM county-winter temperature and precipitation summaries |
| `results/reference/dwr_validation/` | Archived DWR rice acreage and CDL validation comparisons |
| `spatial_boundaries/ca_counties_2024.gpkg` | Derived from supplied TIGER/Line 2024 counties by filtering STATEFP == 06; no simplification or reprojection |

The boundary derivation is reproducible with
`scripts/prepare_county_boundaries.R`. Its source and output checksums are
recorded in `docs/boundary-provenance.json`.

Source links supplied with the materials or embedded in the original code:

- [DWR Statewide Crop Mapping](https://data.cnra.ca.gov/dataset/statewide-crop-mapping)
- [USDA NASS Cropland Data Layer](https://www.nass.usda.gov/Research_and_Science/Cropland/SARS1a.php)
- [2024 Census county boundaries](https://www2.census.gov/geo/tiger/TIGER2024/COUNTY/tl_2024_us_county.zip)

The original raw eBird export, source-selection/query details, and all download
dates cannot be reconstructed from the prepared CSV alone. This repository
supports rerunning from the supplied summary snapshots; full independence
from those snapshots requires obtaining and documenting the original raw
inputs. Links copied from source materials were not revalidated against live
provider websites during repository assembly.

The full archive remains local. Excluded material includes approximately
3.9 GiB of DWR source data, PRISM rasters, full US county boundaries, raw
flock-level exports, original manuscripts, chat exports, and page previews.
No rights to third-party data or templates are granted by this repository.
