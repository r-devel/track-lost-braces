library(googlesheets4)

# Programmatic auth for unattended runs (e.g. GitHub Actions)
if (Sys.getenv("GOOGLE_SERVICE_ACCOUNT_PATH") != "") {
  gs4_auth(path = Sys.getenv("GOOGLE_SERVICE_ACCOUNT_PATH"))
} else {
  gs4_auth() # local interactive flow, cached as before
}

# read in sheet
ss <- "1qL5s2okfQmh_ufwh3MS6rJPzIlLmJzIN2g9u2loFzkA"


current_sheet <- read_sheet(
  ss,
  sheet = 1, # "Latest (YYYY-MM-DD)", where date is the last updated.
  col_types = "cclcTccccccii"
)
