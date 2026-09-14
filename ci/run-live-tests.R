source("tests/testthat/helper-live-results.R")

results <- devtools::test(filter = "live", reporter = "summary")
assert_live_results(results)
