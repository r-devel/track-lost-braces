library(googlesheets4)

# read in sheet

ss <- "1qL5s2okfQmh_ufwh3MS6rJPzIlLmJzIN2g9u2loFzkA"

current_sheet <- read_sheet(
  ss,
  sheet = "Latest",
  col_types = "cclcTccccccii"
)
