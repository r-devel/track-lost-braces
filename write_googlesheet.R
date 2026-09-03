# Script takes ~1 minute to run on an M5 MackBook Pro
# Script requires access to the rowforwards Google account for authentication
# Any "PROBLEMS" showing in Positron resolve after source("track_lost_braces.R") is run
# Tracking spreadsheet is
# https://docs.google.com/spreadsheets/d/1qL5s2okfQmh_ufwh3MS6rJPzIlLmJzIN2g9u2loFzkA

source("track_lost_braces.R")

updated_sheet <- track_lost_braces |>
  #GoogleSheets/googlesheets4 allows writing of max 50,000 chars to a cell
  mutate(Output = stringr::str_trunc(Output, 49000)) |>
  mutate(
    URL = gs4_formula(ifelse(
      URL == "NA",
      NA_character_,
      sprintf('=HYPERLINK("%s","%s")', URL, URL)
    ))
  ) |>
  mutate(
    BugReports = gs4_formula(ifelse(
      BugReports == "NA",
      NA_character_,
      sprintf('=HYPERLINK("%s","%s")', BugReports, BugReports)
    ))
  ) |>
  mutate(
    PR_link = gs4_formula(ifelse(
      PR_link == "NA",
      NA_character_,
      sprintf('=HYPERLINK("%s","%s")', PR_link, PR_link)
    ))
  )

# ss defined in read_googlesheet.R
write_sheet(updated_sheet, ss, sheet = "Latest")

# Apply the data validation rule to the PR_status column

# Get the numeric sheetId for the "Latest" tab
props <- sheet_properties(ss)
sheet_id_latest <- props$id[props$name == "Latest"]

# Build and send the setDataValidation request
req <- list(
  setDataValidation = list(
    range = list(
      sheetId = sheet_id_latest,
      startRowIndex = 1, # 0-indexed -> row 2, i.e. skips the header
      endRowIndex = 400, # last row with data
      startColumnIndex = 1, # 0-indexed -> column B, PR_status
      endColumnIndex = 2
    ),
    rule = list(
      condition = list(
        type = "ONE_OF_RANGE",
        values = list(
          list(userEnteredValue = "='Data Validation'!A2:A10")
        )
      ),
      showCustomUi = TRUE,
      strict = TRUE
    )
  )
)

bu_req <- request_generate(
  "sheets.spreadsheets.batchUpdate",
  params = list(spreadsheetId = ss, requests = list(req))
)
resp_raw <- request_make(bu_req)
gargle::response_process(resp_raw)
