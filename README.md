# California HPAI, Rice Habitat, and Snow Goose Dissertation Code

Dissertation research code by **Mariati Messinger** examining county-level
associations between rice habitat, winter Snow Goose activity, and reported
poultry highly pathogenic avian influenza (HPAI) outbreaks in California.

This repository was assembled from the supplied `Plan_data_analysis` archive
on October 21, 2026. It contains the existing analysis code, prepared county
summaries, archived reference results, and optional manuscript automation.
Original files in the supplied archive were left unchanged.

## Run the analysis

Use R with the required packages installed. R 4.6.0 was used for verification;
observed package versions are recorded in `docs/r-package-versions.csv`.

```sh
Rscript scripts/install_dependencies.R
Rscript scripts/run_analysis.R
```

Run commands from the repository root, or open `dissertation-code.Rproj` in
RStudio. Installing spatial packages may require GDAL, GEOS, PROJ, and platform
build tools. New output goes to `analysis_outputs/`, which Git ignores.

To also regenerate GIS layers and map figures:

```sh
Rscript scripts/run_analysis.R --spatial
```

The default run reconstructs the county-winter model data from the included
poultry census, eBird county summary, and APHIS county-winter summary, then
fits the dissertation models using the included CDL rice and PRISM climate
summaries. It does not download the large raw datasets. The spatial option
uses the archived DWR/CDL comparison table for the validation map.

## Study design represented by the code

- Unit: California county-winter; winter is November through February.
- Primary window: complete winters 2022–2023, 2023–2024, and 2024–2025.
- Primary sample: 36 county-winters from 12 counties with at least 1,000 CDL
  rice acres in any primary crop year, 2022–2024.
- Statewide sensitivity sample: 174 county-winters across 58 counties.
- RQ1: rice acreage; RQ2: Snow Goose activity; RQ3: their interaction.
- Main outcome: poultry outbreak counts, modeled with negative binomial
  regression. Logistic models use any reported poultry outbreak.

The later manuscript revisions frame this as a wild-bird migration and
agricultural-habitat study; poultry outbreaks remain the measured outcome.
Rice acreage measures potential habitat, not observed winter flooding.
The Snow Goose variable is mean count per complete eBird checklist, not a
measured density per unit area. APHIS wild-bird detections are surveillance
context and do not measure true prevalence. See [methods notes](docs/methods.md).

## Repository contents

| Location | Purpose |
| --- | --- |
| `scripts/*.R` | Fourteen supplied R scripts plus setup and runner scripts |
| `scripts/manuscript/` | Five historical Python scripts for draft/checklist edits |
| `data/prepared/` | Small archived county summary inputs |
| `spatial_boundaries/ca_counties_2024.gpkg` | All 58 California counties, filtered from supplied 2024 TIGER boundaries |
| Root CSVs and census text | Existing eBird and poultry census inputs |
| `results/reference/` | Archived analysis tables, figures, and notes for comparison |
| `analysis_outputs/` | Newly generated results; created when run, ignored by Git |
| `source_manifest.csv` | Source-relative paths and checksums of copied/adapted files |
| `docs/` | Data provenance, execution order, and verification notes |

The full US boundary file, raw raster/GIS archives, flock-level raw exports,
chat transcripts, dissertation drafts, institutional templates, and rendered
page previews are not included. Raw data and private manuscripts belong in
ignored local folders. See [data sources](docs/data-sources.md).

## Rebuild from raw sources

See [the execution guide](docs/reproducing.md) for the raw-data stages and
required directory layout. The eBird raw species and sampling exports were
not supplied in this archive; the provided aggregate CSV allows the main
analysis to run without them. Large CDL inputs are also external.

The archived R scripts are retained with path changes needed for portability.
The runner sets a fixed random seed for the permutation diagnostic; the
original permutation p-value can differ because its seed was not recorded.
Scientific model specifications were not changed.

## Optional manuscript scripts

Install `requirements-manuscript.txt` only if using the Word-document scripts.
These are historical edits for particular manuscript/template versions,
including fixed paragraph and table references. Required DOCX inputs are
excluded. Their syntax was checked; document edits were not rerun or verified.
See [the manuscript notes](docs/reproducing.md#manuscript-automation).

## Rights

No open-source license has been selected. The code and third-party data have
separate rights; see [LICENSE-NOTICE.md](LICENSE-NOTICE.md).
