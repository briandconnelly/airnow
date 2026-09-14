# Build the `airnow_areas` dataset and internal ZIP-to-area crosswalk from
# AirNow's reporting-area metadata files.
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
zip_url <- "https://files.airnowtech.org/airnow/today/cityzipcodes.csv"
retrieved <- Sys.Date()

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

# The source rounds several fractional UTC offsets down to whole hours. Restore
# the precise standard offsets for zones whose standard and daylight labels are
# identical and which do not observe DST. Without this, derived UTC timestamps
# are 30 or 45 minutes late for India, Sri Lanka, Nepal, Afghanistan, and
# Myanmar.
gmt_offset <- as.numeric(raw$gmt_offset)
fractional_offsets <- c(AFT = 4.5, IST = 5.5, MMT = 6.5, NPT = 5.75)
uses_fractional_offset <- raw$observes_dst == "No" &
  raw$tz_standard == raw$tz_daylight &
  raw$tz_standard %in% names(fractional_offsets)
gmt_offset[uses_fractional_offset] <- unname(
  fractional_offsets[raw$tz_standard[uses_fractional_offset]]
)

airnow_areas <- tibble::tibble(
  reporting_area = raw$reporting_area,
  state_code = raw$state_code,
  country_code = raw$country_code,
  latitude = as.numeric(raw$latitude),
  longitude = as.numeric(raw$longitude),
  gmt_offset = gmt_offset,
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

# AirNow documents cityzipcodes.csv as its ZIP-to-reporting-area crosswalk.
# The City column contains the reporting-area name, not an arbitrary USPS
# place name. Pair it with State because 26 area names occur in multiple
# states.
zip_raw <- utils::read.delim(
  zip_url,
  sep = "|",
  header = TRUE,
  quote = "",
  comment.char = "",
  colClasses = "character",
  encoding = "UTF-8",
  stringsAsFactors = FALSE
)

stopifnot(identical(
  names(zip_raw),
  c("City", "State", "Zipcode", "Latitude", "Longitude")
))
stopifnot(all(grepl("^[0-9]{5}$", zip_raw$Zipcode)))
stopifnot(anyDuplicated(zip_raw$Zipcode) == 0)

area_key <- paste(
  airnow_areas$reporting_area, airnow_areas$state_code, sep = "\r"
)
zip_key <- paste(zip_raw$City, zip_raw$State, sep = "\r")
stopifnot(anyDuplicated(area_key) == 0)

area_idx <- match(zip_key, area_key)
stopifnot(!anyNA(area_idx))

airnow_zip_areas <- data.frame(
  zip = zip_raw$Zipcode,
  latitude = as.numeric(zip_raw$Latitude),
  longitude = as.numeric(zip_raw$Longitude),
  reporting_area_code = airnow_areas$reporting_area_code[area_idx],
  stringsAsFactors = FALSE
)
stopifnot(!anyNA(airnow_zip_areas))
stopifnot(all(airnow_zip_areas$reporting_area_code %in%
                airnow_areas$reporting_area_code))

attr(airnow_zip_areas, "source") <- zip_url
attr(airnow_zip_areas, "retrieved") <- retrieved

message("ZIP rows: ", nrow(airnow_zip_areas))
usethis::use_data(airnow_zip_areas, internal = TRUE, overwrite = TRUE)
