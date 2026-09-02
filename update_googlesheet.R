library(googlesheets4)
library(tools)
library(dplyr)
library(stringr)
library(cranlogs)

source("track_PRs.R")

# NOTE: lb is shorthand for Lost Braces, a type of documentation NOTE
# NOTE: vc is shorthand Version Controlled (in GitHub/GitLab/BitBucket)

# Latest CRAN details
details <- tools::CRAN_check_details(
  flavors = "r-devel-linux-x86_64-debian-gcc"
)
Rd_NOTE <- subset(details, Check == "Rd files" & Status == "NOTE")

pdb <- CRAN_package_db()
Rd_NOTE <- merge(Rd_NOTE, pdb)

# Find packages with "Lost braces" in the Rd NOTE
Rd_NOTE_lb <- Rd_NOTE[
  grepl("Lost braces", Rd_NOTE$Output),
]

# restrict to packages that use GitHub or equivalent
Rd_NOTE_lb_vc <- Rd_NOTE_lb[
  grepl("github|gitlab|bitbucket|codeberg", Rd_NOTE_lb$BugReports) |
    grepl("github|gitlab|bitbucket|codeberg", Rd_NOTE_lb$URL),
]

# CRAN info for GoogleSheet
from_CRAN <- Rd_NOTE_lb_vc |>
  select(Package, Version, Maintainer, Output, URL, BugReports)

# read in sheet
current_sheet <- read_sheet(
  "https://docs.google.com/spreadsheets/d/1qL5s2okfQmh_ufwh3MS6rJPzIlLmJzIN2g9u2loFzkA/edit?gid=1451772479#gid=1451772479",
  col_types = "cclcTccccccii"
)

# Find packages which still have this NOTE *or* have a PR_status
# (keep if PR_status as record of R contributor effort)
rows_to_keep <- current_sheet |>
  filter((Package %in% from_CRAN$Package) | !is.na(PR_status))

# CRAN packages that have lb NOTE since sheet last updated
add_to_sheet <- from_CRAN |>
  filter(Package %notin% current_sheet$Package)

all_rows <- bind_rows(rows_to_keep, add_to_sheet)

# Getting latest package version number and output
pdb_version <- pdb |>
  filter(Package %in% all_rows$Package) |>
  select(Package, Version)

Rd_NOTE_lb_vc_output <- Rd_NOTE_lb_vc |>
  filter(Package %in% all_rows$Package) |>
  select(Package, Output)

downloads <- cran_downloads(all_rows$Package, "last-month") |>
  summarise(downloads_last_month = sum(count), .by = package) |>
  rename(Package = package)

# Update rows for sheet
updated_rows <- all_rows |>
  mutate(has_lb_NOTE = Package %in% from_CRAN$Package) |>
  mutate(Version = if_else(Package %in% pdb$Package, Version, NA)) |>
  rows_update(pdb_version, by = "Package") |>
  mutate(Output = if_else(has_lb_NOTE, Output, NA)) |>
  rows_update(Rd_NOTE_lb_vc_output, by = "Package") |>
  rows_update(downloads, by = "Package")

# TODO: update programmatically:
# PR_status
# PR_link
# We get PR_info from track_PRs.R

PR_info_new <- PR_info |>
  mutate(
    PR_status = case_when(
      state == "open" ~ "PR opened",
      state == "closed" &
        is.na(merged_at) ~ "Fixed by maintainer on repo OR closed no fix",
      state == "closed" & !is.na(merged_at) ~ "PR merged"
    )
  ) |>
  mutate(
    PR_created_date = as.POSIXct(
      PR_created_date,
      format = "%Y-%m-%dT%H:%M:%SZ",
      tz = "UTC"
    )
  ) |>
  select(-state, -merged_at)

# Packages with a frozen/terminal status keep it regardless of new PR data;
# otherwise use the freshly computed status if we have one, else keep the
# existing status (a package can be absent from PR_info_new simply because
# it has no PR referenced in the r-dev-day tracking issue this run).
updated_rows_pr <- updated_rows |>
  left_join(
    PR_info_new |> select(Package, PR_status_new = PR_status),
    by = "Package"
  ) |>
  mutate(
    PR_status = if_else(
      PR_status %in%
        c(
          "Repository archived",
          "Repository unsupported",
          "Fixed by maintainer on repo",
          "PR closed (no fix)"
        ),
      PR_status,
      coalesce(PR_status_new, PR_status)
    )
  ) |>
  select(-PR_status_new)

# TODO: write back to GoogleSheets

# Next packages to submit manual PRs to:
updated_rows |>
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
