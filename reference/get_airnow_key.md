# Manage your AirNow API key

`get_airnow_key()` returns the configured AirNow API key. If no key is
set and `ask` is `TRUE` in an interactive session, you are prompted for
one; otherwise an error is raised.

The key is read from the `AIRNOW_API_KEY` environment variable. To set
it permanently, add `AIRNOW_API_KEY=your-key` to your `~/.Renviron`
file. Keys are issued at <https://docs.airnowapi.org/account/request/>.

`set_airnow_key()` sets the AirNow API key for the current session.

## Usage

``` r
get_airnow_key(ask = is_interactive())

set_airnow_key(key = NULL, ask = is_interactive())
```

## Arguments

- ask:

  Whether to prompt for the key if none is set. Prompting only works in
  interactive sessions.

- key:

  The API key to use. If `NULL` and `ask` is `TRUE`, you are prompted
  for one.

## Value

`get_airnow_key()` returns a string.

`set_airnow_key()` returns the key, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
get_airnow_key()
} # }
if (FALSE) { # \dontrun{
set_airnow_key(key = "4d36e978-e325-11ce-bfc1-08002be10318")
} # }
```
