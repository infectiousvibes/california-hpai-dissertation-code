#!/usr/bin/env Rscript

# Create dissertation-ready GIS map figures from ArcGIS/spatial analysis layers.

suppressPackageStartupMessages({
  required <- c("dplyr", "readr", "sf")
  missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop("Missing required R package(s): ", paste(missing, collapse = ", "), call. = FALSE)
  }
  library(dplyr)
  library(readr)
  library(sf)
})

fig_dir <- "analysis_outputs/arcgis/figures"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

gpkg <- "analysis_outputs/arcgis/hpai_rice_goose_arcgis_layers.gpkg"
county_totals <- sf::st_read(gpkg, layer = "dissertation_convergence_county_totals", quiet = TRUE)
winter_layers <- list(
  "2022-2023" = sf::st_read(gpkg, layer = "convergence_2022_2023", quiet = TRUE),
  "2023-2024" = sf::st_read(gpkg, layer = "convergence_2023_2024", quiet = TRUE),
  "2024-2025" = sf::st_read(gpkg, layer = "convergence_2024_2025", quiet = TRUE)
)
dwr_2024 <- sf::st_read(gpkg, layer = "dwr_cdl_validation_2024", quiet = TRUE)

county_totals <- sf::st_transform(county_totals, 3310)
winter_layers <- lapply(winter_layers, sf::st_transform, crs = 3310)
dwr_2024 <- sf::st_transform(dwr_2024, 3310)

pal_rice <- colorRampPalette(c("#f7fbff", "#c6dbef", "#6baed6", "#2171b5", "#08306b"))
pal_goose <- colorRampPalette(c("#fff7ec", "#fdd49e", "#fc8d59", "#d7301f", "#7f0000"))
pal_conv <- colorRampPalette(c("#f7fcf5", "#c7e9c0", "#74c476", "#238b45", "#00441b"))
pal_valid <- colorRampPalette(c("#8c2d04", "#d94801", "#fdd0a2", "#f7f7f7", "#c7e9c0", "#41ab5d", "#005a32"))

breaks_quantile <- function(x, n = 5) {
  x <- x[is.finite(x)]
  br <- unique(as.numeric(quantile(x, probs = seq(0, 1, length.out = n + 1), na.rm = TRUE)))
  if (length(br) < 3) br <- pretty(x, n = n)
  br
}

assign_cols <- function(x, breaks, palette_fun) {
  cols <- palette_fun(length(breaks) - 1)
  idx <- cut(x, breaks = breaks, include.lowest = TRUE, labels = FALSE)
  out <- cols[idx]
  out[is.na(out)] <- "#eeeeee"
  out
}

add_north_arrow <- function(x = "left", y = "top") {
  usr <- par("usr")
  px <- if (x == "left") usr[1] + 0.08 * diff(usr[1:2]) else usr[2] - 0.08 * diff(usr[1:2])
  py <- if (y == "top") usr[4] - 0.08 * diff(usr[3:4]) else usr[3] + 0.08 * diff(usr[3:4])
  arrows(px, py - 0.07 * diff(usr[3:4]), px, py, length = 0.08, lwd = 2)
  text(px, py + 0.025 * diff(usr[3:4]), "N", cex = 0.9, font = 2)
}

add_scale_note <- function() {
  mtext("California counties; county-level ecological analysis", side = 1, line = 3, cex = 0.75, col = "#555555")
}

save_map <- function(filename, width = 1800, height = 1400, expr) {
  png(file.path(fig_dir, filename), width = width, height = height, res = 180)
  op <- par(no.readonly = TRUE)
  on.exit({ par(op); dev.off() }, add = TRUE)
  par(mar = c(4, 1, 4, 1), bg = "white")
  force(expr)
}

choropleth <- function(sfobj, value, title, subtitle, palette_fun, legend_title, filename, breaks = NULL, points_value = NULL) {
  x <- sfobj[[value]]
  if (is.null(breaks)) breaks <- breaks_quantile(x)
  fill <- assign_cols(x, breaks, palette_fun)
  save_map(filename, expr = {
    plot(sf::st_geometry(sfobj), col = fill, border = "#ffffff", lwd = 0.5, main = title)
    title(sub = subtitle, line = 1, cex.sub = 0.85)
    add_north_arrow()
    if (!is.null(points_value)) {
      pts <- sf::st_point_on_surface(sfobj)
      pv <- sfobj[[points_value]]
      size <- ifelse(is.na(pv) | pv <= 0, 0, sqrt(pv) * 0.28 + 0.7)
      plot(sf::st_geometry(pts[pv > 0, ]), add = TRUE, pch = 21, bg = "#b2182b", col = "white", cex = size[pv > 0])
      legend("bottomleft", legend = c("Outbreak count symbol"), pt.bg = "#b2182b", pch = 21, pt.cex = 1.3, bty = "n", cex = 0.75)
    }
    legend(
      "right",
      legend = paste0(format(round(head(breaks, -1), 2), trim = TRUE), " - ", format(round(tail(breaks, -1), 2), trim = TRUE)),
      fill = palette_fun(length(breaks) - 1),
      title = legend_title,
      bty = "n",
      cex = 0.72
    )
    add_scale_note()
  })
}

choropleth(
  county_totals,
  "rice_acres_cdl",
  "Figure 1. County-Level Rice Acreage, 2022-2025 Primary Window",
  "USDA CDL rice acreage averaged across complete analysis winters; darker counties have greater rice acreage.",
  pal_rice,
  "CDL rice acres",
  "figure_1_rice_acreage_counties.png",
  points_value = "poultry_outbreaks"
)

choropleth(
  county_totals,
  "mean_snow_goose_count_per_complete_checklist",
  "Figure 2. Snow Goose Activity by County",
  "Mean Snow Goose count per complete eBird checklist across complete analysis winters.",
  pal_goose,
  "Mean count/checklist",
  "figure_2_snow_goose_activity.png",
  points_value = "poultry_outbreaks"
)

choropleth(
  county_totals,
  "one_health_convergence",
  "Figure 3. One Health Spatial Convergence Index",
  "Index combines county ranks for rice acreage, Snow Goose activity, and poultry inventory; outbreak counts shown as symbols.",
  pal_conv,
  "Convergence index",
  "figure_3_one_health_convergence.png",
  breaks = seq(0, 1, by = 0.2),
  points_value = "poultry_outbreaks"
)

class_colors <- c(
  "High rice + high goose + high poultry + outbreak" = "#67000d",
  "High goose + high poultry + outbreak" = "#cb181d",
  "High rice + high poultry + outbreak" = "#ef3b2c",
  "High rice + high goose + outbreak" = "#fb6a4a",
  "High rice + high goose" = "#fdae6b",
  "High rice + high goose + high poultry, no outbreak" = "#9ecae1",
  "Outbreak without top-quartile rice/goose/poultry overlap" = "#756bb1",
  "Lower measured convergence" = "#d9d9d9"
)

save_map("figure_4_convergence_classes.png", expr = {
  cls <- county_totals$convergence_class
  fill <- class_colors[cls]
  fill[is.na(fill)] <- "#eeeeee"
  plot(sf::st_geometry(county_totals), col = fill, border = "#ffffff", lwd = 0.5, main = "Figure 4. Spatial Convergence Classes")
  title(sub = "Categorical overlap of high rice acreage, Snow Goose activity, poultry inventory, and outbreaks.", line = 1, cex.sub = 0.85)
  add_north_arrow()
  legend("right", legend = names(class_colors), fill = class_colors, bty = "n", cex = 0.58)
  add_scale_note()
})

save_map("figure_5_winter_progression_outbreaks.png", width = 2200, height = 1000, expr = {
  par(mfrow = c(1, 3), mar = c(3, 1, 4, 1))
  max_outbreaks <- max(unlist(lapply(winter_layers, function(x) x$poultry_outbreaks)), na.rm = TRUE)
  br <- c(0, 1, 3, 6, 10, max_outbreaks + 0.01)
  cols <- c("#f7f7f7", "#fee5d9", "#fcae91", "#fb6a4a", "#cb181d")
  for (season in names(winter_layers)) {
    lyr <- winter_layers[[season]]
    fill <- cols[cut(lyr$poultry_outbreaks, breaks = br, include.lowest = TRUE, labels = FALSE)]
    fill[is.na(fill)] <- "#eeeeee"
    plot(sf::st_geometry(lyr), col = fill, border = "#ffffff", lwd = 0.4, main = paste("Winter", season))
    legend("bottomleft", legend = c("0", "1-2", "3-5", "6-9", "10+"), fill = cols, bty = "n", cex = 0.75)
  }
  mtext("Figure 5. Seasonal Progression of Poultry HPAI Outbreak Counts", outer = TRUE, line = -1.5, cex = 1.2, font = 2)
})

choropleth(
  dwr_2024,
  "dwr_to_cdl_ratio",
  "Figure 6. DWR-CDL Rice Acreage Validation, 2024",
  "Ratio of DWR provisional rice acres to USDA CDL rice acres; values near 1 indicate close agreement.",
  pal_valid,
  "DWR/CDL ratio",
  "figure_6_dwr_cdl_validation_2024.png",
  breaks = c(0, 0.5, 0.8, 0.95, 1.05, 1.2, 2)
)

caption_lines <- c(
  "# Dissertation GIS Figure Captions",
  "",
  "**Figure 1. County-Level Rice Acreage, 2022-2025 Primary Window.** Counties are shaded by mean USDA Cropland Data Layer rice acreage across the complete winter analysis period. Poultry HPAI outbreak counts are overlaid as proportional red symbols.",
  "",
  "**Figure 2. Snow Goose Activity by County.** Counties are shaded by mean Snow Goose count per complete eBird checklist across the complete winter analysis period. Poultry HPAI outbreak counts are overlaid as proportional red symbols.",
  "",
  "**Figure 3. One Health Spatial Convergence Index.** The convergence index combines ranked county values for rice acreage, Snow Goose activity, and poultry inventory. Higher values indicate stronger spatial overlap among ecological and agricultural risk components. Poultry HPAI outbreak counts are shown as proportional symbols.",
  "",
  "**Figure 4. Spatial Convergence Classes.** Counties are categorized according to whether they fall in the top quartile for rice acreage, Snow Goose activity, and poultry inventory, and whether poultry HPAI outbreaks occurred during the primary analysis period.",
  "",
  "**Figure 5. Seasonal Progression of Poultry HPAI Outbreak Counts.** County-level outbreak counts are shown separately for the 2022-2023, 2023-2024, and 2024-2025 winter seasons.",
  "",
  "**Figure 6. DWR-CDL Rice Acreage Validation, 2024.** Counties are shaded by the ratio of California Department of Water Resources provisional 2024 rice acreage to USDA CDL 2024 rice acreage. This map supports comparison of the primary CDL rice-acreage measure with the California-specific DWR crop mapping source.",
  "",
  "Note. CDL and DWR crop maps measure rice acreage, not directly observed winter flooding. Interpret these figures as potential rice-field habitat unless a winter inundation layer is added."
)
writeLines(caption_lines, file.path(fig_dir, "figure_captions.md"))

cat("Wrote dissertation GIS figures to:", normalizePath(fig_dir, mustWork = FALSE), "\n")
