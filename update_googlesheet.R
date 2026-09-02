library(googlesheets4)
library(tools)
library(dplyr)
library(stringr)
library(cranlogs)

# NOTE: lb is shorthand for Lost Braces, a type of documentation NOTE

# Latest CRAN details
details <- tools::CRAN_check_details(
  flavors = "r-devel-linux-x86_64-debian-gcc"
)
Rd_NOTE <- subset(details, Check == "Rd files" & Status == "NOTE")

pdb <- CRAN_package_db()
Rd_NOTE <- merge(Rd_NOTE, pdb)

# restrict to packages that use GitHub or equivalent to report issues
TODO <- Rd_NOTE[
  grepl(
    "^http?s://(github.com|gitlab.com|bitbucket.org).*issues",
    Rd_NOTE$BugReports
  ),
]

# Find packages with "Lost braces" in the Rd NOTE
Rd_NOTE_lb <- TODO[grep("Lost braces", TODO$Output), ]

# CRAN info for GoogleSheet
from_CRAN <- Rd_NOTE_lb |>
  select(Package, Version, Maintainer, Output, URL, BugReports)

# read in sheet
current_sheet <- read_sheet(
  "https://docs.google.com/spreadsheets/d/1qL5s2okfQmh_ufwh3MS6rJPzIlLmJzIN2g9u2loFzkA/edit?gid=1451772479#gid=1451772479",
  col_types = "cclcccccccii"
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

Rd_NOTE_lb_output <- Rd_NOTE_lb |>
  filter(Package %in% all_rows$Package) |>
  select(Package, Output)

downloads <- cran_downloads(all_rows$Package, "last-month") |>
  summarise(downloads_last_month = sum(count), .by = package) |>
  rename(Package = package)

# Update rows for sheet
updated_rows <- all_rows |>
  mutate(has_lb_NOTE = Package %in% from_CRAN$Package) |>
  rows_update(pdb_version, by = "Package") |>
  mutate(Output = if_else(has_lb_NOTE, Output, NA)) |>
  rows_update(Rd_NOTE_lb_output, by = "Package") |>
  rows_update(downloads, by = "Package")

# TODO: update programmatically:
# PR_status
# PR_link

# TODO: write back to GoogleSheets

# Next packages to submit PRs to:
updated_rows |>
  arrange(desc(downloads_last_month)) |>
  filter(is.na(PR_status)) |>
  head() |>
  select(Package, BugReports)
