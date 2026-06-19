# Data pipeline for the CU stat calculator


## Prerequisites

The scripts expect a linux environment (WSL or a Mac terminal should do) and require `curl` and `jq`.

You need to set environment variables with your CU credentials for this to work, `get_auth.sh` gives guidance on that. 
Don't screw up and loose your keys!

## Procedure:

`./hawking_pull.sh` pulls API data from Hawking into a file named `stats.json`. In case Hawking is down, this will fail (`stats.json` will contain HTML instead).

`./build_stat_formulas.sh` takes `stats.json` as input and creates the file that the stat calc relies on (`../stat_formulas.json`).

## Config:

`./stat_ui_config.json` drives the display groups with the derived stats the stat calculator shows
