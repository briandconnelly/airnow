function(resp) {
  # Applied by httptest2 to both requests (when computing the mock file
  # path) and responses (when writing the file). Redacting the key keeps
  # it out of paths and files; shortening the host keeps every fixture path
  # under the 100-byte tarball limit that R CMD check enforces.
  resp <- httptest2::gsub_response(resp, "api_key=[^&]+", "api_key=REDACTED")
  httptest2::gsub_response(resp, "https://www.airnowapi.org/aq/", "https://an/")
}
