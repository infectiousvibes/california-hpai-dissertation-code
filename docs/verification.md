# Verification performed October 21, 2026

Verified locally using R 4.6.0 and the package versions in
`r-package-versions.csv`.

- `Rscript scripts/run_analysis.R --spatial` completed successfully.
- `Rscript scripts/verify_reproduction.R` passed: all 80 model-result rows,
  all 12 model-fit rows, and the full 406-row county-winter dataset matched
  archived reference tables within numeric tolerance 1e-8.
- Sample counts were 36 county-winters / 12 primary counties and
  174 county-winters / 58 statewide counties; county-winter keys were unique.
- All 12 fitted regression models reported convergence and no recorded errors.
- The GeoPackage and all six map figures were generated successfully.
- All 18 R scripts parsed; all five Python scripts passed AST syntax checks.
- All 82 imported/adapted file hashes matched the repository manifest.
- The California boundary subset contains all 58 counties; derivation hashes
  are recorded in `boundary-provenance.json`.

The spatial plotting run emitted three standard sf warnings that point-on-surface
assumes attributes are constant over geometry; these arise when placing county
map symbols. The run completed. The local R startup also emitted locale warnings.

Raw CDL, PRISM, DWR, eBird, and APHIS source rebuilds were not rerun. Main
analysis verification uses the supplied county summaries. Historical manuscript
programs were syntax-checked only; no DOCX generation or layout verification
was performed. Permutation p-values are stochastic and were excluded from
comparison to the original unseeded run.
