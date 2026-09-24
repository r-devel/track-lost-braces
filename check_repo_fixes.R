# check_repo_fixes.R
# Functions to check repositories with Lost braces issues that have been fixed
# in the source repo, but not yet released to CRAN (addresses Issue #1).
# Sourced and called by track_lost_braces.R.

# Helper: Extract GitHub repository "owner/repo" from URL or BugReports fields.
#
# Regex Explanation:
# "https?://github\\.com/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)"
# - https?://      : Matches the URL scheme ("http://" or "https://").
# - github\\.com/  : Matches the literal domain "github.com/".
# - ([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+) : Captures the "owner/repo" path.
#     * [A-Za-z0-9_.-]+ matches valid GitHub owner and repository characters
#       (alphanumeric characters, underscores, dots, and hyphens).
#     * The slash "/" separates the repository owner and repository name.
#
# Follow-up sanitisation:
# - str_remove(repo_path, "\\.git$") strips any trailing ".git" suffix.
# - If the path segment after owner is a sub-directory or action such as
#   "issues", "pull", "pulls", "blob", or "tree", it is ignored so that
#   only genuine repository roots are returned.
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

# Helper: Parse target Rd filename(s) from CRAN check output.
#
# Regex Explanation:
# "checkRd:\\s*(?:\\(-?\\d+\\)\\s*)?([A-Za-z0-9._-]+\\.Rd)"
# - checkRd:               : Matches the literal "checkRd:" prefix emitted by CRAN check logs.
# - \\s*                   : Matches optional whitespace after the colon.
# - (?:\\(-?\\d+\\)\\s*)?  : Non-capturing group matching an optional severity/offset code
#                            enclosed in parentheses, such as "(-1)" or "(0)", followed by
#                            optional whitespace.
# - ([A-Za-z0-9._-]+\\.Rd) : Capturing group for the Rd filename ending in ".Rd"
#                            (e.g., "my_function.Rd" or "data-set.Rd").
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

# Helper: Extract offending snippet lines from CRAN note output.
#
# Regex Explanation:
# "^\\s*\\d+\\s*\\|\\s*(.+)$"
# CRAN check logs print the source code line containing the lost brace with line numbering:
# "   21 | Reads a \url{https://...}{Variant Call Format (VCF)} file into a BED object,"
# - ^\\s*   : Anchors to start of line, matching optional leading whitespace.
# - \\d+    : Matches one or more digits representing the source line number (e.g., "21").
# - \\s*\\| : Matches optional whitespace followed by the literal pipe "|" separator.
# - \\s*    : Matches optional whitespace after the pipe.
# - (.+)$   : Captures the offending code snippet text up to the end of the line.
parse_snippet_lines <- function(output_text) {
  if (is.na(output_text) || output_text == "") {
    return(character(0))
  }
  lines <- str_split(output_text, "\n")[[1]]
  snippet_lines <- character(0)
  for (line in lines) {
    m <- str_match(line, "^\\s*\\d+\\s*\\|\\s*(.+)$")
    if (!is.na(m[1, 2])) {
      snippet_lines <- c(snippet_lines, str_trim(m[1, 2]))
    }
  }
  unique(snippet_lines[snippet_lines != ""])
}

# Check an individual package repository for fixes in Rd files
check_package_repo_fix <- function(pkg_name, repo, rd_files, snippets, auth_token = "") {
  if (is.na(repo) || length(rd_files) == 0) {
    return(NULL)
  }

  results <- list()

  for (rd in rd_files) {
    file_url <- sprintf("https://api.github.com/repos/%s/contents/man/%s", repo, rd)
    req <- request(file_url)

    if (!is.null(auth_token) && auth_token != "") {
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

    results[[length(results) + 1]] <- tibble(
      Package = pkg_name,
      Repository = repo,
      Rd_file = rd,
      Snippets_checked = length(snippets),
      Snippets_removed = all_snippets_removed
    )
  }

  bind_rows(results)
}

# Main function to check candidate packages
find_repo_fixed_packages <- function(df, auth_token = if (exists("token")) token else Sys.getenv("GITHUB_TOKEN"), limit = NULL) {
  # Candidate packages: still flagged with NOTE on CRAN, no PR_status yet
  candidates <- df |>
    filter(has_lb_NOTE) |>
    filter(is.na(PR_status) | PR_status == "")

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
