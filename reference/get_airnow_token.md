# Manage AirNow API Tokens

`get_airnow_token()` returns the configured AirNow API token or errors
if it is not set.

`set_airnow_token()` sets the AirNow API token to the given value for
the current session. To use this permanently, save it as
`AIRNOW_API_KEY` in your `~/.Renviron` file.

## Usage

``` r
get_airnow_token(ask = is_interactive())

set_airnow_token(token = NULL, ask = is_interactive())
```

## Arguments

- ask:

  Whether or not to ask for the key if none is provided. Note that this
  only works for interactive sessions.

- token:

  Token to use

## Value

`get_airnow_token()` returns a string containing the current user or
group key or an empty string if not set. If the user is not set but
`ask` is `TRUE`, the user will be prompted for a key.

## Examples

``` r
if (FALSE) { # \dontrun{
get_airnow_token()
} # }
if (FALSE) { # \dontrun{
set_airnow_token(token = "4d36e978-e325-11cec1-08002be10318")
} # }
```
