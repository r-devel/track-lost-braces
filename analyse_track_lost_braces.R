# NOTES
# Script takes ~1 minute to run on an M5 MackBook Pro
# Any "PROBLEMS" showing in Positron resolve after source("track_lost_braces.R") is run
# Script requires access to the rowforwards Google account for authentication
# See https://docs.google.com/spreadsheets/d/1qL5s2okfQmh_ufwh3MS6rJPzIlLmJzIN2g9u2loFzkA/edit?gid=500184850#gid=500184850
# for latest tracking data without needing access to the account

source("track_lost_braces.R")

# Next packages to submit manual PRs to:
track_lost_braces |>
  arrange(desc(downloads_last_month)) |>
  filter(is.na(PR_status)) |>
  head() |>
  select(Package, BugReports)

# For CRAN team: packages that need to make a release or merge a PR
updated_rows |>
  filter(has_lb_NOTE & !is.na(PR_status))

# For R Contributors: keep track of successes!
updated_rows |>
  filter(!has_lb_NOTE & !is.na(PR_status))

updated_rows |>
  filter(Package == "survMisc") |>
  View()
