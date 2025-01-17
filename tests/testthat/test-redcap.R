conn <- dbConnect(RSQLite::SQLite(), dbname = ":memory:")

create_test_table(conn, "redcap_user_information")

get_institutional_person_output <- dplyr::tribble(
  ~user_id, ~email,
  "site_admin", "joe.user@projectredcap.org",
  "admin", "admin@example.org",
  "alice", "real_alice@example.org",
  "bob",   "bob_b@example.org",
  "carol", "carol_a@example.org",
  "dan", "daniel@example.org"
)

get_bad_redcap_email_output <- dplyr::tribble(
  ~ui_id, ~username, ~email_field_name, ~email,
  1, "site_admin", "user_email", "joe.user@projectredcap.org",
  3, "alice", "user_email",  "alice@example.org",
  4, "bob",   "user_email",  "bob_a@example.org",
  5, "carol", "user_email2", "carol_b@example.org",
  6, "dan",   "user_email",  "dan_a@example.org",
  6, "dan",   "user_email2", "dan_b@example.org",
  6, "dan",   "user_email3", "dan_c@example.org"
) %>% dplyr::mutate(ui_id = as.integer(ui_id))

get_updated_redcap_email_addresses <- dplyr::tribble(
  ~ui_id, ~username, ~user_email, ~user_email2, ~user_email3,
  1, "site_admin", NA_character_, NA_character_, NA_character_,
  2, "admin", "admin@example.org", NA_character_, NA_character_,
  3, "alice", "real_alice@example.org",  NA_character_, NA_character_,
  4, "bob",   "bob_b@example.org", "bob_b@example.org", NA_character_,
  5, "carol", "carol_a@example.org", "carol_a@example.org", NA_character_,
  6, "dan",   "daniel@example.org", "daniel@example.org", "daniel@example.org"
)

test_that("get_redcap_emails returns the correct dataframe", {
  expect_identical(get_redcap_emails(conn), get_redcap_emails_output)
})

test_that("get_redcap_email_revisions returns the proper data frame", {
  result <- get_redcap_email_revisions(get_bad_redcap_email_output, get_institutional_person_output)

  expect_named(result, c("ui_id", "email_field_name", "username", "corrected_email", "email"))
})

test_that("get_redcap_email_revisions returns unique entries for ui_id and email_field_name" ,{
  result <- get_redcap_email_revisions(get_bad_redcap_email_output, get_institutional_person_output) %>%
    dplyr::group_by(ui_id, email_field_name) %>%
    dplyr::count() %>%
    dplyr::filter(n > 1)

  expect_equal(nrow(result), 0)
})

test_that("get_redcap_email_revisions properly removes site_admin's email", {
  result <- get_redcap_email_revisions(get_bad_redcap_email_output, get_institutional_person_output)

  site_admin_new_email <- result %>%
    filter(username == "site_admin") %>%
    pull(corrected_email)

  expect_equal(is.na(site_admin_new_email), TRUE)
})

test_that("get_redcap_email_revisions properly updates alice's email", {
  result <- get_redcap_email_revisions(get_bad_redcap_email_output, get_institutional_person_output)

  alice_new_email <- result %>%
    filter(username == "alice") %>%
    pull(corrected_email)

  alice_correct_email <- get_institutional_person_output %>%
    filter(user_id == "alice") %>%
    pull(email)

  expect_equal(alice_new_email, alice_correct_email)
})

test_that("update_redcap_email_addresses properly updates email addresses in redcap_user_information", {

  redcap_email_revisions <- get_redcap_email_revisions(get_bad_redcap_email_output, get_institutional_person_output)
  update_redcap_email_addresses(conn, redcap_email_revisions)

  result <- DBI::dbGetQuery(
    conn,
    "select ui_id, username, user_email, user_email2, user_email3 from redcap_user_information"
  ) %>%
    tibble::tibble()

  expect_equal(get_updated_redcap_email_addresses, result)
})
