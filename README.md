# track-lost-braces

This repo contains scripts to identify R packages which generate a 'Lost braces' `NOTE` in CRAN checks, and to keep track of which have been fixed as a result of R Contributor input. 

It is associated with <https://github.com/r-devel/r-dev-day/issues/110>.

The [tracking spreadsheet](https://docs.google.com/spreadsheets/d/1qL5s2okfQmh_ufwh3MS6rJPzIlLmJzIN2g9u2loFzkA) is updated daily at 6am UTC via a [GitHub Action](.github/workflows/update-googlesheet.yml) which runs [write_googlesheet.R](write_googlesheet.R).

## Workflow for folks making PRs to fix lost braces NOTES

- Look at the [tracking spreadsheet](https://docs.google.com/spreadsheets/d/1qL5s2okfQmh_ufwh3MS6rJPzIlLmJzIN2g9u2loFzkA) to identify a package to fix:
  - Filter Column B to `(Blank)` - these are the packages that haven't had a fix yet
  - Prioritise packages near the top of the sheet (these are the ones with the most downloads in the last month)
  - Find the GitHub repo: this should be either in the URL or BugReport column
- Fork the package repo, make the fix and submit a PR to the package. In the PR, link to <https://github.com/r-devel/r-dev-day/issues/110>. Linking to this issue is **crucial** to ensure that the spreadsheet is properly updated (as well as to give context to the package owner)
- If you come across a package in the spreadsheet where the repository has been archived on GitHub (or equivalent), please make a comment to report this in <https://github.com/r-devel/r-dev-day/issues/110> and tag @EllaKaye.

Note that the tracking spreadsheet is *read only*. Your contributions are programmatically added to the spreadsheet providing the PR is linked to as described avove.

We also do not expect folks to run any of the R scripts themselves, nor manually trigger the GitHub Action. 
The contributor workflow only involves the tracking spreadsheet and <https://github.com/r-devel/r-dev-day/issues/110>.

## Repo setup

The scripts in this repo do the following:

- [read_googlesheet.R](read_googlesheet.R) reads in the `Latest` tab from the [tracking spreadsheet](https://docs.google.com/spreadsheets/d/1qL5s2okfQmh_ufwh3MS6rJPzIlLmJzIN2g9u2loFzkA).
- [track_PRs.R](track_PRs.R) finds all PRs made to fix Lost Braces issues: those mentioned in comments in <https://github.com/r-devel/r-dev-day/issues/110>, those that directly link to <https://github.com/r-devel/r-dev-day/issues/110>, and those already in the tracking spreadsheet. It then queries the GitHub API for their status and other associated info. It creates the `PR_info` data frame, which is then used in [track_lost_braces.R](track_lost_braces.R). 
- [track_lost_braces.R](track_lost_braces.R) contains the code that identifies packages on CRAN with the `NOTE` and compares them with the latest version of the [tracking spreadsheet](https://docs.google.com/spreadsheets/d/1qL5s2okfQmh_ufwh3MS6rJPzIlLmJzIN2g9u2loFzkA), and updates accordingly. The script produces a `track_lost_braces` data frame, which combines the latest information from CRAN with the PR info. `track_lost_braces` contains packages which still have the `NOTE`, and any packages that previously had the `NOTE` but have been fixed as a result of a PR from an R Contributor.
- [write_googlesheet.R](write_googlesheet.R) creates `updated_sheet`, with some tweaks to `track_lost_braces` to prepare it for GoogleSheets, then writes it to the `Latest` tab of the [tracking spreadsheet](https://docs.google.com/spreadsheets/d/1qL5s2okfQmh_ufwh3MS6rJPzIlLmJzIN2g9u2loFzkA).
- [analyse_track_lost_braces.R](analyse_track_lost_braces.R) contains some code to analyse `track_lost_braces` in R. This is useful for CRAN maintainers and the RCWG:
  - see which packages have fixed the issue on the repo but not yet released to CRAN
  - see which packages have received a PR to fix the issue, but are yet to merge it
  - see the impact of R Contributor work (e.g. at Sprints and R Dev Days) in making progress towards closing <https://github.com/r-devel/r-dev-day/issues/110>