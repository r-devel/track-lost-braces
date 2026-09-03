# NOTES
# Script takes ~1 minute to run on an M5 MackBook Pro
# Script requires a Google account for authentication
# Tracking spreadsheet is
# https://docs.google.com/spreadsheets/d/1qL5s2okfQmh_ufwh3MS6rJPzIlLmJzIN2g9u2loFzkA/edit?gid=500184850#gid=500184850

library(httr2)
library(gitcreds)
library(dplyr)
library(stringr)

source("read_googlesheet.R")

# Get GitHub token stored with gitcreds_set()
cred <- gitcreds::gitcreds_get()
if (is.null(cred$password)) {
  stop("No GitHub PAT found in git credentials!")
}
token <- cred$password

# Define owner, repo, issue number
owner <- "r-devel"
repo <- "r-dev-day"
issue_number <- 110

# GraphQL query
query <- sprintf(
  '
{
  repository(owner: "%s", name: "%s") {
    issue(number: %d) {
      comments(first: 100) {
        nodes { body }
      }
      timelineItems(first: 100, itemTypes: CROSS_REFERENCED_EVENT) {
        nodes {
          ... on CrossReferencedEvent {
            source {
              __typename
              ... on PullRequest { url title author { login } }
            }
          }
        }
      }
    }
  }
}',
  owner,
  repo,
  issue_number
)

# Send request via httr2
res <- request("https://api.github.com/graphql") |>
  req_headers(
    "Authorization" = paste("Bearer", token),
    "Content-Type" = "application/json"
  ) |>
  req_body_json(list(query = query)) |>
  req_perform() |>
  resp_body_json(simplifyVector = TRUE)

# Get PRs mentioned in the comments
comments <- res[[1]]$repository$issue$comments$nodes$body
pattern <- "https://github\\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/pull/\\d+"
pr1 <- unlist(regmatches(comments, gregexpr(pattern, comments)))

# Get PRs that reference this issue
pr2 <- subset(
  res[[1]]$repository$issue$timelineItems$nodes$source,
  `__typename` == "PullRequest"
)$url

# Get PRs from the GoogleSheet
pr3 <- current_sheet$PR_link[
  !is.na(current_sheet$PR_link) & grepl("pull", current_sheet$PR_link)
]

prs <- unique(sort(c(pr1, pr2, pr3)))

# Get GitHub repos and usernames to query
package_urls <- str_remove(prs, "https://github.com") |> str_split("/")
owner <- sapply(package_urls, function(x) x[2])
repo <- sapply(package_urls, function(x) x[3])
pr_number <- sapply(package_urls, function(x) x[5])

pr_df <- bind_cols(
  URL = prs,
  Owner = owner,
  Package = repo,
  PR_number = pr_number
)

get_pr_info <- function(i) {
  pr_url <- sprintf(
    "https://api.github.com/repos/%s/%s/pulls/%s",
    pr_df$Owner[i],
    pr_df$Package[i],
    pr_df$PR_number[i]
  )
  res <- request(pr_url) |>
    req_headers(
      "Authorization" = paste("Bearer", token),
      "Content-Type" = "application/json"
    ) |>
    req_perform() |>
    resp_body_json(simplifyVector = TRUE)
  out_list <- vector("list")
  out_list$Package <- pr_df$Package[i]
  out_list$PR_link <- pr_df$URL[i]
  out_list$Contributor <- res$user$login # The R contributor who raised the PR
  out_list$state <- res$state
  out_list$PR_created_date <- res$created_at
  out_list$merged_at <- (if (is.null(res$merged_at)) {
    NA
  } else {
    res$merged_at
  })
  out_list
}


# Get PR details for each PR
PR_info <- lapply(seq_len(nrow(pr_df)), get_pr_info) |>
  bind_rows()
