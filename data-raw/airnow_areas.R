# Build the `airnow_areas` dataset from AirNow's reporting-area metadata file.
#
# Run from the package root with:
#   Rscript data-raw/airnow_areas.R
#
# The file is public (no key needed), pipe-delimited, has no header, uses
# CRLF line endings, contains one exact duplicate row (Monterrey, mx002),
# and one non-ASCII row (Guanajuato). read.delim() handles CRLF on every
# platform; strsplit() must NOT be used because it drops trailing empty
# fields (68 rows have an empty last field).

url <- "https://files.airnowtech.org/airnow/today/reportingarea_metadata.dat"

raw <- utils::read.delim(
  url,
  sep = "|",
  header = FALSE,
  quote = "",
  comment.char = "",
  na.strings = "",
  colClasses = "character",
  encoding = "UTF-8",
  stringsAsFactors = FALSE
)

stopifnot(ncol(raw) == 14)

names(raw) <- c(
  "reporting_area", "state_code", "country_code", "latitude", "longitude",
  "gmt_offset", "observes_dst", "tz_standard", "tz_daylight",
  "reporting_area_code", "agency", "lookup_behavior",
  "considered_monitors", "lookup_boundary"
)

# Defensive: strip any carriage return that survived, then mark encoding.
for (col in names(raw)) {
  raw[[col]] <- sub("\r$", "", raw[[col]])
  raw[[col]] <- enc2utf8(raw[[col]])
}

raw <- raw[!duplicated(raw), ]
stopifnot(anyDuplicated(raw$reporting_area_code) == 0)
stopifnot(all(grepl("^[a-z]{2}[0-9]{3}$", raw$reporting_area_code)))
stopifnot(all(raw$observes_dst %in% c("Yes", "No")))

airnow_areas <- tibble::tibble(
  reporting_area = raw$reporting_area,
  state_code = raw$state_code,
  country_code = raw$country_code,
  latitude = as.numeric(raw$latitude),
  longitude = as.numeric(raw$longitude),
  gmt_offset = as.integer(raw$gmt_offset),
  observes_dst = raw$observes_dst == "Yes",
  tz_standard = raw$tz_standard,
  tz_daylight = raw$tz_daylight,
  reporting_area_code = raw$reporting_area_code,
  agency = raw$agency,
  lookup_behavior = raw$lookup_behavior,
  considered_monitors = raw$considered_monitors,
  lookup_boundary = raw$lookup_boundary
)

stopifnot(!anyNA(airnow_areas$latitude), !anyNA(airnow_areas$longitude))
stopifnot(!anyNA(airnow_areas$gmt_offset))

message("Rows: ", nrow(airnow_areas), " (expected 1036 as of 2026-09-12)")

usethis::use_data(airnow_areas, overwrite = TRUE)
