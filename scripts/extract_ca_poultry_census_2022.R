input <- "ca_agcensus_2022_county_all_tables.txt"
output <- "ca_county_poultry_census_2022.csv"

lines <- readLines(input, warn = FALSE)

table_start <- grep("^Table 19\\.  Poultry - Inventory and Number Sold", lines)[1]
table_end <- grep("^Table 20\\.  Miscellaneous Poultry", lines)[1]
table_lines <- lines[table_start:(table_end - 1)]

fields <- c(
  poultry_farms_any_2022 = "Any poultry farms",
  layer_farms_2022 = "Layer farms",
  layer_inventory_2022 = "Layer inventory",
  pullet_replacement_farms_2022 = "Pullet replacement farms",
  pullet_replacement_inventory_2022 = "Pullet replacement inventory",
  broiler_farms_2022 = "Broiler farms",
  broiler_inventory_2022 = "Broiler inventory",
  turkey_farms_2022 = "Turkey farms",
  turkey_inventory_2022 = "Turkey inventory",
  misc_poultry_farms_2022 = "Misc poultry farms",
  poultry_sold_farms_any_2022 = "Any poultry sold farms",
  layers_sold_farms_2022 = "Layers sold farms",
  layers_sold_number_2022 = "Layers sold number",
  pullet_replacement_sold_farms_2022 = "Pullet replacement sold farms",
  pullet_replacement_sold_number_2022 = "Pullet replacement sold number",
  broilers_sold_farms_2022 = "Broilers sold farms",
  broilers_sold_number_2022 = "Broilers sold number",
  turkeys_sold_farms_2022 = "Turkeys sold farms",
  turkeys_sold_number_2022 = "Turkeys sold number",
  misc_poultry_sold_farms_2022 = "Misc poultry sold farms"
)

records <- data.frame(
  county = character(),
  stringsAsFactors = FALSE
)

ensure_counties <- function(counties) {
  for (county in counties) {
    if (!county %in% records$county) {
      row <- as.list(rep(NA_character_, length(fields) + 1))
      names(row) <- c("county", names(fields))
      row$county <- county
      records <<- rbind(records, as.data.frame(row, stringsAsFactors = FALSE))
    }
  }
}

store_values <- function(counties, field, values) {
  values <- trimws(values)
  values[values == ""] <- NA_character_
  values[values == "-"] <- "0"
  for (idx in seq_along(counties)) {
    records[records$county == counties[idx], field] <<- values[idx]
  }
}

current_counties <- character()
section <- NA_character_
category <- NA_character_

for (line in table_lines) {
  if (grepl("^\\s*Item\\s*:", line)) {
    current_counties <- trimws(strsplit(line, ":", fixed = TRUE)[[1]][-1])
    ensure_counties(current_counties)
    section <- NA_character_
    category <- NA_character_
    next
  }

  if (!length(current_counties)) next

  item <- trimws(sub(":.*$", "", line))
  item <- gsub("\\.{2,}", " ", item)
  item <- gsub("\\s+", " ", item)

  if (grepl("^INVENTORY", item)) {
    section <- "inventory"
    category <- NA_character_
    next
  }
  if (grepl("^NUMBER SOLD", item)) {
    section <- "sold"
    category <- NA_character_
    next
  }

  values_part <- sub("^.*:", "", line)
  values <- trimws(strsplit(trimws(values_part), "\\s{2,}", perl = TRUE)[[1]])
  if (length(values) != length(current_counties)) next

  if (grepl("^Any poultry farms, 2022$", item)) {
    store_values(current_counties, "poultry_farms_any_2022", values)
  } else if (grepl("^Layers farms, 2022$", item) && identical(section, "inventory")) {
    category <- "layers_inventory"
    store_values(current_counties, "layer_farms_2022", values)
  } else if (grepl("^Pullets for laying flock replacement farms, 2022$", item) && identical(section, "inventory")) {
    category <- "pullet_inventory"
    store_values(current_counties, "pullet_replacement_farms_2022", values)
  } else if (grepl("^Broilers and other meat-type chickens farms, 2022$", item) && identical(section, "inventory")) {
    category <- "broiler_inventory"
    store_values(current_counties, "broiler_farms_2022", values)
  } else if (grepl("^Turkeys farms, 2022$", item) && identical(section, "inventory")) {
    category <- "turkey_inventory"
    store_values(current_counties, "turkey_farms_2022", values)
  } else if (grepl("^poultry farms, 2022$", item) && identical(section, "inventory")) {
    category <- "misc_inventory"
    store_values(current_counties, "misc_poultry_farms_2022", values)
  } else if (grepl("^Any poultry sold farms, 2022$", item)) {
    store_values(current_counties, "poultry_sold_farms_any_2022", values)
  } else if (grepl("^Layers sold farms, 2022$", item)) {
    category <- "layers_sold"
    store_values(current_counties, "layers_sold_farms_2022", values)
  } else if (grepl("^Pullets for laying flock replacement sold farms, 2022$", item)) {
    category <- "pullet_sold"
    store_values(current_counties, "pullet_replacement_sold_farms_2022", values)
  } else if (grepl("^Broilers and other meat-type chickens sold farms, 2022$", item)) {
    category <- "broilers_sold"
    store_values(current_counties, "broilers_sold_farms_2022", values)
  } else if (grepl("^Turkeys sold farms, 2022$", item)) {
    category <- "turkeys_sold"
    store_values(current_counties, "turkeys_sold_farms_2022", values)
  } else if (grepl("^poultry sold farms, 2022$", item)) {
    category <- "misc_sold"
    store_values(current_counties, "misc_poultry_sold_farms_2022", values)
  } else if (grepl("^number, 2022$", item)) {
    field <- switch(
      category,
      layers_inventory = "layer_inventory_2022",
      pullet_inventory = "pullet_replacement_inventory_2022",
      broiler_inventory = "broiler_inventory_2022",
      turkey_inventory = "turkey_inventory_2022",
      layers_sold = "layers_sold_number_2022",
      pullet_sold = "pullet_replacement_sold_number_2022",
      broilers_sold = "broilers_sold_number_2022",
      turkeys_sold = "turkeys_sold_number_2022",
      NA_character_
    )
    if (!is.na(field)) store_values(current_counties, field, values)
  }
}

records <- records[records$county != "California", ]

for (field in names(fields)) {
  suppressed <- records[[field]] == "(D)"
  records[[paste0(field, "_suppressed")]] <- ifelse(is.na(records[[field]]), NA, suppressed)
  numeric_values <- gsub(",", "", records[[field]])
  numeric_values[suppressed] <- NA_character_
  records[[field]] <- as.numeric(numeric_values)
}

inventory_number_fields <- c(
  "layer_inventory_2022",
  "pullet_replacement_inventory_2022",
  "broiler_inventory_2022",
  "turkey_inventory_2022"
)
sales_number_fields <- c(
  "layers_sold_number_2022",
  "pullet_replacement_sold_number_2022",
  "broilers_sold_number_2022",
  "turkeys_sold_number_2022"
)

records$poultry_inventory_known_sum_2022 <- rowSums(records[inventory_number_fields], na.rm = TRUE)
records$poultry_sales_known_sum_2022 <- rowSums(records[sales_number_fields], na.rm = TRUE)
records$poultry_inventory_known_sum_incomplete <- rowSums(
  records[paste0(inventory_number_fields, "_suppressed")],
  na.rm = TRUE
) > 0
records$poultry_sales_known_sum_incomplete <- rowSums(
  records[paste0(sales_number_fields, "_suppressed")],
  na.rm = TRUE
) > 0

records$source <- "USDA NASS 2022 Census of Agriculture, Volume 1 Chapter 2 County Level Data, California, Table 19"
records$source_url <- "https://data.nass.usda.gov/Publications/AgCensus/2022/Full_Report/Volume_1%2C_Chapter_2_County_Level/California/st06_2_019_019.pdf"
records$notes <- "USDA symbol (D) is withheld to avoid disclosing data for individual operations; suppressed numeric cells are NA and marked by *_suppressed columns. Dash values were converted to 0. Known-sum columns add non-suppressed layers, pullets, broilers, and turkeys; they exclude miscellaneous poultry because Table 19 reports misc farms but not misc inventory/sales numbers."

write.csv(records, output, row.names = FALSE, na = "")
message("Wrote ", nrow(records), " county records to ", output)
