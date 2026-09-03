library(googlesheets4)

# read in sheet
sheet_url <- "https://docs.google.com/spreadsheets/d/1qL5s2okfQmh_ufwh3MS6rJPzIlLmJzIN2g9u2loFzkA/edit?gid=1451772479#gid=1451772479"
current_sheet <- read_sheet(
  sheet_url,
  sheet = "Latest",
  col_types = "cclcTccccccii"
)
