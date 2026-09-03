# NOTES
# Script takes ~1 minute to run on an M5 MackBook Pro
# Any "PROBLEMS" showing in Positron resolve after source("track_lost_braces.R") is run
# Script requires a Google account for authentication
# Tracking spreadsheet is
# https://docs.google.com/spreadsheets/d/1qL5s2okfQmh_ufwh3MS6rJPzIlLmJzIN2g9u2loFzkA/edit?gid=500184850#gid=500184850

source("track_lost_braces.R")

# Next packages to submit manual PRs to:
track_lost_braces |>
  arrange(desc(downloads_last_month)) |>
  filter(is.na(PR_status)) |>
  select(Package, BugReports, URL) |>
  head()

# For CRAN team:
# packages that have fixed the issue on repo but not released to CRAN
track_lost_braces |>
  filter(has_lb_NOTE) |>
  filter(PR_status %in% c("PR merged", "Fixed by maintainer on repo"))

# packages that have an open PR which they are yet to merge
track_lost_braces |>
  filter(has_lb_NOTE) |>
  filter(PR_status == "PR opened")

# For R Contributors: keep track of successes!
track_lost_braces |>
  filter(!has_lb_NOTE & !is.na(PR_status))
