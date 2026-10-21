#!/usr/bin/env Rscript

# Download California DWR Statewide Crop Mapping GIS shapefiles for supplemental
# rice acreage validation. These are field-scale crop maps, not direct winter
# inundation/flooding observations.

sources <- data.frame(
  year = c(2020, 2021, 2022, 2023, 2024),
  status = c("final", "final", "final", "final", "provisional"),
  url = c(
    "https://data.cnra.ca.gov/dataset/6c3d65e3-35bb-49e1-a51e-49d5a2cf09a9/resource/11dde2fe-dc07-4b10-b54e-ede2b4ce5fe6/download/i15_crop_mapping_2020.zip",
    "https://data.cnra.ca.gov/dataset/6c3d65e3-35bb-49e1-a51e-49d5a2cf09a9/resource/eebd40ab-35a3-4e62-a625-0275b2849531/download/i15_crop_mapping_2021_shp.zip",
    "https://data.cnra.ca.gov/dataset/6c3d65e3-35bb-49e1-a51e-49d5a2cf09a9/resource/b92e0daf-6e2e-4b5c-a112-09474138d1cd/download/i15_crop_mapping_2022_shp.zip",
    "https://data.cnra.ca.gov/dataset/6c3d65e3-35bb-49e1-a51e-49d5a2cf09a9/resource/25d0f174-4bec-4987-a402-602cd1372786/download/i15_crop_mapping_final_2023.zip",
    "https://data.cnra.ca.gov/dataset/6c3d65e3-35bb-49e1-a51e-49d5a2cf09a9/resource/1a1c259c-4279-4868-a25f-b1f71665ca25/download/i15_crop_mapping_2024_provisional.zip"
  )
)

out_dir <- "raw_data/dwr_statewide_crop_mapping"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

for (i in seq_len(nrow(sources))) {
  item <- sources[i, ]
  dest <- file.path(out_dir, sprintf("dwr_statewide_crop_mapping_%s_%s.zip", item$year, item$status))
  if (!file.exists(dest)) {
    message("Downloading ", item$year, " DWR crop mapping (", item$status, ")")
    utils::download.file(item$url, dest, mode = "wb", quiet = FALSE)
  } else {
    message("Already exists: ", dest)
  }
}

write.csv(sources, file.path(out_dir, "dwr_statewide_crop_mapping_sources.csv"), row.names = FALSE)
cat("DWR source manifest written to:", normalizePath(out_dir, mustWork = FALSE), "\n")
