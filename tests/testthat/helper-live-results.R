assert_live_results <- function(results) {
  results <- as.data.frame(results)
  required <- c("nb", "failed", "skipped", "error", "warning")
  missing <- setdiff(required, names(results))
  if (length(missing) > 0) {
    stop(
      "Live-test results lack required columns: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  if (nrow(results) == 0) {
    stop("No live tests matched the configured filter", call. = FALSE)
  }
  if (anyNA(results[required])) {
    stop("Live-test result counts must not contain NA", call. = FALSE)
  }

  totals <- vapply(results[required], function(x) sum(as.numeric(x)), numeric(1)) # nolint
  if (totals[["nb"]] < 1) {
    stop("The live tests executed no expectations", call. = FALSE)
  }
  failures <- totals[c("failed", "skipped", "error", "warning")]
  if (any(failures != 0)) {
    stop(
      "Live tests were not clean: ",
      paste(names(failures), failures, sep = "=", collapse = ", "),
      call. = FALSE
    )
  }

  invisible(results)
}
