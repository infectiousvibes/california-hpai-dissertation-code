# Execution guide

Run every command below from the repository root.

## Main analysis from prepared data

```sh
Rscript scripts/install_dependencies.R
Rscript scripts/run_analysis.R
Rscript scripts/verify_reproduction.R
```

The runner uses included summary data, reproduces the first-pass merge and
final dissertation models, and records `analysis_outputs/sessionInfo.txt`.
The verification command checks sample sizes and compares generated model
coefficients and fit statistics with the archived tables using a numeric
tolerance. It excludes stochastic permutation p-values from that comparison.
Reference outputs under `results/reference/` are kept separate from reruns.

For all map layers and six spatial figures:

```sh
Rscript scripts/run_analysis.R --spatial
```

The spatial option builds the initial GeoPackage before appending convergence
layers. It copies the archived DWR/CDL county comparison into the working
output directory; this is not a new raw-DWR extraction.

## Optional raw-data stages

| Stage | Script | Prerequisites |
| --- | --- | --- |
| Poultry census | `extract_ca_poultry_census_2022.R` | Included root census text |
| APHIS cleaning | `clean_usda_hpai_outbreak_records.R` | Raw exports in layout below |
| eBird summary | `prepare_ebird_snow_goose_county_winter.R` | Species TSV and sampling TSV; use `--species-file` and `--sampling-file` |
| CDL rice | `build_cdl_rice_county_acres.R` | Raw annual CDL archives; use `--cdl-dir` and `--years` |
| PRISM GeoTIFFs | `build_prism_county_winter_from_tifs.R` | Extracted monthly rasters under `prism_4km_monthly_2020_2025/` |
| PRISM ZIP alternative | `prism_county_winter_summary.R` | ZIP archives; use `--county-shp spatial_boundaries/ca_counties_2024.gpkg` |
| DWR acquisition | `download_dwr_crop_mapping_sources.R` | Internet and storage for large downloads |
| DWR comparison | `build_dwr_rice_validation.R` | DWR archives and working CDL acreage table |

APHIS raw layout (ignored by Git):

```text
raw_data/hpai/
  Poultry HPAI Outbreak Dataset/ExportToCsv.csv
  Wildbird HPAI Outbreak Dataset/HPAI Detections in Wild Birds (1).csv
```

The cleaner defaults to writing `data/prepared/hpai/`. `HPAI_RAW_DIR` and
`HPAI_CLEAN_DIR` override these locations. Regenerating these summaries changes
tracked inputs; inspect the Git diff before committing. `EBIRD_DIR` and
`CDL_DIR` override the corresponding raw input directories. `.env.example`
documents names but is not loaded automatically.

The DWR extraction expects 2020–2023 final archives and the 2024 provisional
archive. The PRISM ZIP script and GeoTIFF script have different output schemas;
the final model expects `winter_tmean_c` and `winter_ppt_mm`, as written by
the GeoTIFF script. Running the main runner copies the committed prepared
CDL/PRISM snapshots into `analysis_outputs/`, replacing working versions.
For analyses using newly rebuilt summaries, run the individual analysis
scripts in order instead of the convenience runner:

```sh
Rscript scripts/analyze_county_winter_hpai.R
Rscript scripts/dissertation_final_analysis.R
```

To rebuild the small California boundary file from the supplied full US file:

```sh
Rscript scripts/prepare_county_boundaries.R /path/to/tl_2024_us_county.shp
```

Without an argument, the boundary script downloads the 2024 Census archive.
The original CDL extraction script can also download US boundaries for its
own extraction. Those large files are excluded from Git.

## Manuscript automation

The five supplied Python programs are preserved under `scripts/manuscript/`,
grouped by their original output folder. Paths are now relative to the
repository root. Install optional dependencies with:

```sh
python3 -m pip install -r requirements-manuscript.txt
```

Historical order: `revise_wildbird_framing.py`, `create_final_revised_draft.py`,
`fill_quant_checklist.py`, `update_checklist_detailed_prompt_notes.py`, then
`revise_committee2_feedback.py`. The checklist branch is independent of the
manuscript revision branch. Restore the appropriate input DOCX versions under
`analysis_outputs/chapter5_draft/` and `data/manuscripts/`. The scripts contain
fixed text and table references and can fail or overwrite outputs if used
with different document versions. They are not part of the analysis runner.
