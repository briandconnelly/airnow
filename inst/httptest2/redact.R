function(resp) {
  # Applied by httptest2 to both requests (when computing the mock file
  # path) and responses (when writing the file). Replacing the key in the URL
  # makes the fixture path independent of whichever key made the request and
  # keeps the key out of the recorded file.
  httptest2::gsub_response(resp, "api_key=[^&]+", "api_key=REDACTED")
}
