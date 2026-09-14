# Advanced Testing Topics

## Skipping Tests

Skip tests conditionally when requirements aren't met:

### Built-in Skip Functions

```r
test_that("API integration works", {
  skip_if_offline()
  skip_if_not_installed("httr2")
  skip_on_cran()
  skip_on_os("windows")

  result <- call_external_api()
  expect_true(result$success)
})
```

**Common skip functions:**
- `skip()` - Skip unconditionally with message
- `skip_if()` - Skip if condition is TRUE
- `skip_if_not()` - Skip if condition is FALSE
- `skip_if_offline()` - Skip if no internet
- `skip_if_not_installed(pkg)` - Skip if package unavailable
- `skip_on_cran()` - Skip on CRAN checks
- `skip_on_os(os)` - Skip on specific OS
- `skip_on_ci()` - Skip on continuous integration
- `skip_unless_r(version)` - Skip unless R version requirement met (testthat 3.3.0+)

### Custom Skip Conditions

```r
skip_if_no_api_key <- function() {
  if (Sys.getenv("API_KEY") == "") {
    skip("API_KEY not available")
  }
}

skip_if_slow <- function() {
  if (!identical(Sys.getenv("RUN_SLOW_TESTS"), "true")) {
    skip("Slow tests not enabled")
  }
}

test_that("authenticated endpoint works", {
  skip_if_no_api_key()

  result <- call_authenticated_endpoint()
  expect_equal(result$status, "success")
})
```

## Testing Flaky Code

### retry with `try_again()`

Test code that may fail occasionally (network calls, timing-dependent code):

```r
test_that("flaky network call succeeds eventually", {
  result <- try_again(
    times = 3,
    {
      response <- make_network_request()
      expect_equal(response$status, 200)
      response
    }
  )

  expect_type(result, "list")
})
```

### Mark Tests as Flaky

```r
test_that("timing-sensitive operation", {
  skip_on_cran()  # Too unreliable for CRAN

  start <- Sys.time()
  result <- async_operation()
  duration <- as.numeric(Sys.time() - start)

  expect_lt(duration, 2)  # Should complete in < 2 seconds
})
```

## Managing Secrets in Tests

### Environment Variables

```r
test_that("authenticated API works", {
  # Skip if credentials unavailable
  api_key <- Sys.getenv("MY_API_KEY")
  skip_if(api_key == "", "MY_API_KEY not set")

  result <- call_api(api_key)
  expect_true(result$authenticated)
})
```

### Local Configuration Files

```r
test_that("service integration works", {
  config_path <- test_path("fixtures", "test_config.yml")
  skip_if_not(file.exists(config_path), "Test config not found")

  config <- yaml::read_yaml(config_path)
  result <- connect_to_service(config)
  expect_true(result$connected)
})
```

**Never commit secrets:**
- Add config files with secrets to `.gitignore`
- Use environment variables in CI/CD
- Provide example config files: `test_config.yml.example`

### Testing Without Secrets

Design tests to degrade gracefully:

```r
test_that("API client works", {
  api_key <- Sys.getenv("API_KEY")

  if (api_key == "") {
    # Mock the API when credentials unavailable
    local_mocked_bindings(
      make_api_call = function(...) list(status = "success", data = "mocked")
    )
  }

  result <- my_api_wrapper()
  expect_equal(result$status, "success")
})
```

## Custom Expectations

Create domain-specific expectations for clearer tests:

### Simple Custom Expectations

```r
# In helper-expectations.R
expect_valid_email <- function(email) {
  expect_match(email, "^[^@]+@[^@]+\\.[^@]+$")
}

expect_positive <- function(x) {
  expect_true(all(x > 0), info = "All values should be positive")
}

expect_named_list <- function(object, names) {
  expect_type(object, "list")
  expect_named(object, names, ignore.order = TRUE)
}
```

Usage:

```r
test_that("user validation works", {
  user <- create_user("test@example.com")
  expect_valid_email(user$email)
})
```

### Complex Custom Expectations

```r
expect_valid_model <- function(model) {
  act <- quasi_label(rlang::enquo(model))

  expect(
    inherits(act$val, "lm") && !is.null(act$val$coefficients),
    sprintf("%s is not a valid linear model", act$lab)
  )

  invisible(act$val)
}
```

## State Inspection

Detect unintended global state changes:

```r
# In setup-state.R
set_state_inspector(function() {
  list(
    options = options(),
    env_vars = Sys.getenv(),
    search = search()
  )
})
```

testthat will warn if state changes between tests.

## CRAN-Specific Considerations

### Time Limits

Tests must complete in under 1 minute:

```r
test_that("slow operation completes", {
  skip_on_cran()  # Takes 2 minutes

  result <- expensive_computation()
  expect_equal(result$status, "complete")
})
```

### File System Discipline

Only write to temp directory:

```r
test_that("file output works", {
  # Good
  output <- withr::local_tempfile(fileext = ".csv")
  write.csv(data, output)

  # Bad - writes to package directory
  # write.csv(data, "output.csv")
})
```

### No External Dependencies

Avoid relying on:
- Network access
- External processes
- System commands
- Clipboard access

```r
test_that("external dependency", {
  skip_on_cran()

  # Code requiring network or system calls
})
```

### Platform Differences

Use `expect_equal()` for numeric comparisons (allows tolerance):

```r
test_that("calculation works", {
  result <- complex_calculation()

  # Good: tolerant to floating point differences
  expect_equal(result, 1.234567)

  # Bad: fails due to platform differences
  # expect_identical(result, 1.234567)
})
```

## Test Performance

### Identify Slow Tests

```r
devtools::test(reporter = "slow")
```

The `SlowReporter` highlights performance bottlenecks.

### Test Shuffling

Detect unintended test dependencies:

```r
# Randomly reorder tests
devtools::test(shuffle = TRUE)

# In test file
test_dir("tests/testthat", shuffle = TRUE)
```

If tests fail when shuffled, they have unintended dependencies on execution order.

## Reviewing an Existing Suite

Reviewing a suite asks a different question from writing one: not "is this test well written?"
but "what would have to break before this suite went red?" Work from the code under test
towards the tests, not the other way round.

This applies to any `tests/testthat/` directory, package or not. A repository with tests but no
`DESCRIPTION` runs under `testthat::test_dir("tests/testthat")`; `devtools::test()` and
`load_all()` are unavailable there, so the code under test is normally sourced from a
`helper-*.R` file. There is no `Config/testthat/edition: 3` either, so such a suite runs the 2nd
edition unless a `setup-*.R` file opts in with
`testthat::local_edition(3, .env = testthat::teardown_env())` — worth checking before you conclude
that a suite avoids 3e features by choice. The review material below works the same either way.

**Check the record before reporting.** Where the work has one — an issue tracker, NEWS.md, a design
doc, prior review threads — search it for the finding before you write it up, and say what you
searched. A deviation that is documented, ruled on and justified is a conforming outcome, not a
defect, and reporting it as one costs the reader more than it saves. Where there is no such record,
say so: "not addressed anywhere I could find" is itself part of the finding. This applies to
substantive findings, not to every observation — do not spend a search on a typo. This retires a
deviation from a plan, a convention or a prior recommendation; a test that cannot fail, a false
green, or a defect in the code under test stays a finding however well documented — cite the ruling
and report it anyway, because a record that acknowledges a defect documents it, it does not fix it.

**Size the finding before you grade it.** Say what the finding moves, and by how much, before
assigning severity: the behaviour under test, the failure it would catch, the runtime, the
confidence a green run buys. A defect in a path nothing exercises — a test for deleted code, a
helper nothing calls, an expectation on a value nothing returns — is not the same as one in a test
somebody relies on, and grading them alike makes the whole list harder to act on. Note the trap in
the other direction: a test that runs anywhere still gates something, tests behind `skip_on_cran()`
or an environment guard included, so "it only runs on CI" is not a reason to downgrade a test that
cannot fail.

### Mutation Testing: What Does the Suite Actually Pin?

A green suite proves the tests ran, not that they constrain anything. Establish what is pinned
by breaking the code on purpose:

1. Copy the project to a scratch location outside the working tree (`cp -r` into a temp
   directory). Never mutate the tree under review. Run the suite there once unmutated and record
   the baseline pass, fail and skip counts.
2. Break exactly one rule in the copy: delete a validation branch, invert a comparison, drop a
   filter, remove a rounding or unit conversion, return an argument unchanged.
3. Re-run the whole suite against the copy, naming the copy in the call:
   `devtools::test("<scratch>")` for a package, `testthat::test_dir("<scratch>/tests/testthat")`
   otherwise. `devtools::test()` defaults to `pkg = "."` and a relative `test_dir()` path resolves
   against the working directory, so a bare call issued from the tree under review tests the
   unmutated original and reports every rule as unpinned. Set `NOT_CRAN=true` in the environment
   as well: `devtools::test()` sets it for you, `Rscript -e 'testthat::test_dir(...)'` does not,
   and without it every snapshot test and every `skip_on_cran()` test skips.
4. Red means the rule is pinned — revert it and move to the next rule. Green means the rule is
   **unpinned**: nothing in the suite depends on it — but only if the skip count still matches the
   baseline, because a mutation that turns a test into a skip is evidence of nothing. Record the
   file and line, and report the missing test, not the mutation.

Mutate the rules that carry consequence first: validation branches, unit conversions, index and
lookup routing, discounting, rounding, and anything deciding which row or column is used.
Delete the scratch copy when finished, and size each unpinned rule with the rule above before
grading it — an unpinned branch in a code path nothing calls is a note, not a defect.

**Validator corollary.** A conforming input exercises none of a validator's rule branches, so
those branches are reached only by fixtures that violate them. A validator that returns or aborts
at the first violation therefore needs one violating fixture per branch; a validator that
accumulates violations — collecting a character vector of problems and reporting them together —
reaches every branch its input violates, so one fixture can pin several. Count the branches, then
name the ones no fixture reaches: report those, not the arithmetic. Seen in review: eight branches
of a cost-table validator, an entire index-routing policy among them, could each be deleted with
the suite fully green, purely because every fixture row the tests constructed was valid.

### Skip Honesty

A test that always skips is a false green, and it reads as a pass in any summary that counts
only failures. For each `skip_if*()` guard, establish that there is an environment somebody
actually runs in which the guard does not fire and the test executes: a
`skip_if_not_installed()` for a package absent from both `Suggests` and the CI image, or a
`skip_if(Sys.getenv("API_KEY") == "")` for a variable set in no CI secret and no setup document,
means that test has never executed anywhere. Check too that the skip count reaches a human —
testthat reports skips in its summary, but a CI job surfacing only "0 failures" hides them.
Report an always-skipped test as untested code, not as a passing test.

Guards that stand down somewhere real are not findings: `skip_on_cran()` in a package whose CI
runs the test, `skip_on_os()` for a platform the CI matrix covers, `skip_if_offline()` on a
runner with network access.

### Fixture Values Must Not Coincide with Production Constants

If a fixture's numbers are the real tariff, the real unit cost, or the real discount rate, a
test can pass because a stray literal in the code happens to equal the fixture value rather
than because the logic is right — and the mutation that replaces a lookup with a hard-coded
constant stays green. Choose fixture values that are deliberately not real and mutually
distinct (unit costs of 1, 2, 4; identifiers and dates outside any real study range), so that a
matching result can only mean the value travelled through the code path under test.

The exception is a regression test that deliberately reproduces a published or externally
supplied figure. There the real value is the point of the test; say so in the test description,
and take the constant from the same source the code does rather than retyping the literal.

## Parallel Testing

Enable parallel test execution in `DESCRIPTION`:

```
Config/testthat/parallel: true
```

**Requirements for parallel tests:**
- Tests must be independent
- No shared state between tests
- Use `local_*()` functions for all side effects
- Snapshot tests work correctly in parallel (testthat 3.2.0+)

## Testing Edge Cases

### Boundary Conditions

```r
test_that("handles boundary conditions", {
  expect_equal(my_func(0), expected_at_zero)
  expect_equal(my_func(-1), expected_negative)
  expect_equal(my_func(Inf), expected_infinite)
  expect_true(is.nan(my_func(NaN)))
})
```

### Empty Inputs

```r
test_that("handles empty inputs", {
  expect_equal(process(character()), character())
  expect_equal(process(NULL), NULL)
  expect_equal(process(data.frame()), data.frame())
})
```

### Type Validation

```r
test_that("validates input types", {
  expect_error(my_func("string"), class = "vctrs_error_cast")
  expect_error(my_func(list()), "must be atomic")
  expect_no_error(my_func(1:10))
})
```

## Debugging Failed Tests

### Interactive Debugging

```r
# Run test interactively
devtools::load_all()
test_that("problematic test", {
  # Add browser() to pause execution
  browser()

  result <- problematic_function()
  expect_equal(result, expected)
})
```

### Print Debugging in Tests

```r
test_that("debug output", {
  data <- prepare_data()
  print(str(data))  # Visible when test fails

  result <- process(data)
  print(result)

  expect_equal(result, expected)
})
```

### Capture Output for Inspection

```r
test_that("inspect messages", {
  messages <- capture_messages(
    result <- function_with_messages()
  )

  print(messages)  # See all messages when test fails
  expect_match(messages, "Processing complete")
})
```

## Testing R6 Classes

```r
test_that("R6 class works", {
  obj <- MyClass$new(value = 10)

  expect_r6_class(obj, "MyClass")  # testthat 3.3.0+
  expect_equal(obj$value, 10)

  obj$increment()
  expect_equal(obj$value, 11)
})
```

## Testing S4 Classes

```r
test_that("S4 validity works", {
  obj <- new("MyClass", slot1 = 10, slot2 = "test")

  expect_s4_class(obj, "MyClass")
  expect_equal(obj@slot1, 10)

  expect_error(
    new("MyClass", slot1 = -1),
    "slot1 must be positive"
  )
})
```
