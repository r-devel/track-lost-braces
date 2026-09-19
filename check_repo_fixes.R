# check_repo_fixes.R
# Check repositories with Lost braces issues that have been fixed
# in the source repo, but not yet released to CRAN (addresses Issue #1).

library(httr2)
library(dplyr)
library(stringr)

# Source existing sheet if current_sheet is not already in environment
if (!exists("current_sheet")) {
  source("read_googlesheet.R")
}

# Prefer token from env (for CI), fallback to gitcreds for local runs
token <- Sys.getenv("GITHUB_TOKEN")
if (token == "") {
  cred <- gitcreds::gitcreds_get()
  if (!is.null(cred$password) && cred$password != "") {
    token <- cred$password
  }
}

# Helper: Extract GitHub repository "owner/repo" from URL or BugReports fields
extract_github_repo <- function(url_text, bugreports_text) {
  candidates <- c(bugreports_text, url_text)
  candidates <- candidates[!is.na(candidates) & candidates != "" & candidates != "NA"]

  for (cand in candidates) {
    match <- str_match(cand, "https?://github\\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)")
    if (!is.na(match[1, 2])) {
      repo_path <- match[1, 2]
      repo_path <- str_remove(repo_path, "\\.git$")
      parts <- str_split(repo_path, "/")[[1]]
      if (length(parts) >= 2 && !(parts[2] %in% c("issues", "pull", "pulls", "blob", "tree"))) {
        return(paste(parts[1], parts[2], sep = "/"))
      }
    }
  }
  NA_character_
}

# Helper: Parse target Rd filename(s) from CRAN check output
parse_rd_files <- function(output_text) {
  if (is.na(output_text) || output_text == "") {
    return(character(0))
  }
  matches <- str_match_all(output_text, "checkRd:\\s*(?:\\(-?\\d+\\)\\s*)?([A-Za-z0-9._-]+\\.Rd)")[[1]]
  if (nrow(matches) > 0) {
    return(unique(matches[, 2]))
  }
  character(0)
}

# Helper: Extract offending snippet lines from CRAN note output
parse_snippet_lines <- function(output_text) {
  if (is.na(output_text) || output_text == "") {
    return(character(0))
  }
  lines <- str_split(output_text, "\n")[[1]]
  snippet_lines <- character(0)
  for (line in lines) {
    # CRAN output format: "   21 | Reads a \url..."
    m <- str_match(line, "^\\s*\\d+\\s*\\|\\s*(.+)$")
    if (!is.na(m[1, 2])) {
      snippet_lines <- c(snippet_lines, str_trim(m[1, 2]))
    }
  }
  unique(snippet_lines[snippet_lines != ""])
}

# Check an individual package repository for fixes in Rd files
check_package_repo_fix <- function(pkg_name, repo, rd_files, snippets, auth_token) {
  if (is.na(repo) || length(rd_files) == 0) {
    return(NULL)
  }

  results <- list()

  for (rd in rd_files) {
    file_url <- sprintf("https://api.github.com/repos/%s/contents/man/%s", repo, rd)
    req <- request(file_url)

    if (auth_token != "") {
      req <- req |> req_headers("Authorization" = paste("Bearer", auth_token))
    }
    req <- req |> req_headers("Accept" = "application/vnd.github.v3.raw")

    resp <- tryCatch(
      req_perform(req),
      error = function(e) NULL
    )

    if (is.null(resp) || resp_status(resp) != 200) {
      next
    }

    content <- resp_body_string(resp)

    # Check if snippets identified in the CRAN note are missing in the repo file
    snippets_present <- vapply(snippets, function(s) str_detect(content, fixed(s)), logical(1))
    all_snippets_removed <- length(snippets) > 0 && !any(snippets_present)

    # Query latest commit for the file to get additional context
    commits_url <- sprintf("https://api.github.com/repos/%s/commits?path=man/%s&page=1&per_page=1", repo, rd)
    c_req <- request(commits_url)
    if (auth_token != "") {
      c_req <- c_req |> req_headers("Authorization" = paste("Bearer", auth_token))
    }

    c_resp <- tryCatch(
      req_perform(c_req),
      error = function(e) NULL
    )

    commit_date <- NA_character_
    commit_msg <- NA_character_

    if (!is.null(c_resp) && resp_status(c_resp) == 200) {
      commit_data <- resp_body_json(c_resp, simplifyVector = TRUE)
      if (length(commit_data) > 0) {
        commit_date <- commit_data$commit$committer$date[1]
        commit_msg <- str_split(commit_data$commit$message[1], "\n")[[1]][1]
      }
    }

    results[[length(results) + 1]] <- tibble(
      Package = pkg_name,
      Repository = repo,
      Rd_file = rd,
      Snippets_checked = length(snippets),
      Snippets_removed = all_snippets_removed,
      Latest_commit_date = commit_date,
      Latest_commit_message = commit_msg
    )
  }

  bind_rows(results)
}

# Main function to check candidate packages
find_repo_fixed_packages <- function(sheet = current_sheet, auth_token = token, limit = NULL) {
  # Candidate packages: still flagged with NOTE on CRAN, no PR_status yet
  candidates <- sheet |>
    filter(has_lb_NOTE) |>
    filter(is.na(PR_status) | PR_status == "" | PR_status == "Fixed by maintainer on repo")

  if (!is.null(limit) && limit > 0) {
    candidates <- head(candidates, limit)
  }

  all_results <- list()

  for (i in seq_len(nrow(candidates))) {
    row <- candidates[i, ]
    repo <- extract_github_repo(row$URL, row$BugReports)
    rd_files <- parse_rd_files(row$Output)
    snippets <- parse_snippet_lines(row$Output)

    res <- check_package_repo_fix(
      pkg_name = row$Package,
      repo = repo,
      rd_files = rd_files,
      snippets = snippets,
      auth_token = auth_token
    )

    if (!is.null(res) && nrow(res) > 0) {
      all_results[[length(all_results) + 1]] <- res
    }
  }

  bind_rows(all_results)
}
