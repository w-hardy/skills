# Language and Framework Checklists

Read this file when the change is in one of the languages below and you are tracing a concrete failure mode. Every entry is a prompt to investigate, not a finding. Confirm the actual behavior in the language version, framework version, and toolchain the repository uses, and confirm the code path is reachable, before reporting anything from this list. Several entries are version- or configuration-dependent, and a linter or type checker already configured in the repository may make some of them unreportable.

For a language not listed here, work from the priorities in "Language- and Framework-Aware Review" in `SKILL.md` and from the repository's own conventions. Do not invent language-specific rules you cannot verify.

## Python

- Mutable default argument (`def f(x=[])`, `={}`) shared across every call.
- `except:` or `except BaseException:`, which also catches `KeyboardInterrupt` and `SystemExit` and so swallows Ctrl-C and interpreter shutdown.
- `except Exception:` or `except ...: pass` that discards the error with no logging, no context, and no re-raise; check whether a bare `raise` or `raise ... from e` was meant.
- Late binding in a loop-created closure or `lambda`; the captured variable holds its final value.
- Mutating a list or dict while iterating over it.
- `is` used for value comparison (`is ""`, `is 0`, small-int and string interning) instead of `==`.
- Truthiness where `0`, `""`, `[]`, or `False` are legal values: `if not count:` is not `if count is None:`.
- Resource opened without a context manager on a path that can raise; `close()` skipped on the exception branch.
- `async def` containing a blocking call (`requests`, `time.sleep`, synchronous file or DB IO); `asyncio.create_task` whose result is never awaited and whose reference is not held (the task can be garbage collected, and its exception is lost).
- Type hints that do not match runtime: `Optional[T]` returned but dereferenced by callers, `Any` at an API boundary, a `TypedDict`/dataclass trusted for data that arrives from JSON without validation.
- `subprocess` with `shell=True` on interpolated input; `eval`, `pickle.loads`, or `yaml.load` without `SafeLoader` on untrusted data.
- Module-level mutable state or import-time side effects in code that serves concurrent requests.
- Naive vs timezone-aware `datetime` mixed in comparisons or arithmetic; `datetime.now()` where `utcnow`/aware time is meant.
- pandas: chained assignment (`df[mask]['col'] = v`) that silently writes to a copy; `inplace=True` on a slice; a merge whose key is not unique on the side assumed to be unique (row fan-out); dtype silently widened to `object` or `float` with `NaN` after a merge or `concat`; comparison against `np.nan` with `==`; `.apply` row-wise where a vectorized operation exists (report only with a measured cost or an obvious scale argument).

## R

- Silent vector recycling between unequal lengths; `if` given a condition of length other than one.
- `1:n` where `n` can be `0` (iterates `1, 0`); use `seq_len`/`seq_along`.
- `sapply` or `apply` whose return type depends on the data (list vs vector vs matrix); `apply` on a data frame coercing everything to character. `vapply` with an explicit `FUN.VALUE` is the checkable form.
- `NA` handling: `sum`/`mean`/`any`/`all` without `na.rm` where `NA` is possible, `==` against `NA` instead of `is.na()`, `%in%` treating `NA` as a match.
- `[` on a data frame or matrix dropping to a vector because `drop = TRUE` is the default.
- Partial matching on `$` for lists, and partial argument matching, both of which break when a new name is added.
- Tidy evaluation: a bare column name where a variable was meant, missing `{{ }}` or `.data[[var]]` in a function wrapping dplyr, `&&`/`||` used on vectors inside `filter`.
- Global state changed without restoration: `options()`, `par()`, `setwd()`, connections, or `set.seed()` inside a function, with no `on.exit(..., add = TRUE)`.
- `library()` or `require()` called from package code; a `require()` return value ignored so the failure surfaces later as "object not found".
- S3: method not registered in `NAMESPACE`, method signature missing `...`, `print` method that does not return its argument invisibly.
- `data.table`: `:=` modifying a caller's table by reference without `copy()`.
- `T`/`F` instead of `TRUE`/`FALSE`; `sample()` given a length-one numeric `x` (samples `1:x`).
- Shiny: reactive value read outside a reactive context, missing `req()` before a value that starts `NULL`, an observer that writes state another observer also owns.

## JavaScript and TypeScript

- A promise-returning call without `await` or `.catch` (floating promise); `array.map(asyncFn)` without `Promise.all`; `forEach` with an async callback, which does not wait.
- `??` vs `||` where `0` or `""` are legal values; `==` where `===` is meant.
- `JSON.parse` on unvalidated input; `innerHTML` or `dangerouslySetInnerHTML` with data that can come from a user (XSS).
- Number precision used for money; `new Date(string)` on a non-ISO format; timezone assumed to be the server's.
- Listener, timer, subscription, or `AbortController` created without cleanup on the path that unmounts or errors.
- A later async response overwriting an earlier one because requests are not sequenced, keyed, or aborted.
- React: effect dependency array that omits a used value or includes an unstable one; effect with no cleanup for a subscription or timer; state derived in an effect that should be computed during render; a stale closure capturing old props; `key` taken from the array index in a list that reorders; state mutated in place rather than replaced.
- TypeScript: `as` assertion or non-null `!` that hides a value which really can be `null` or a different shape at runtime; `any` at a module or API boundary; a type used as a guarantee for data crossing a network or serialization boundary without a runtime check.

## SQL and data access

- Query assembled by string interpolation instead of parameter binding.
- `NULL` semantics: `NOT IN` against a subquery that can yield `NULL`, `= NULL`, `COUNT(col)` vs `COUNT(*)`, an outer join whose right-side predicate sits in `WHERE` and silently makes it an inner join.
- Join fan-out: a many-to-many join under a one-to-many assumption, double-counting a `SUM` or inflating row counts.
- Implicit type coercion or collation mismatch on a join key.
- Non-sargable predicate (function applied to an indexed column, leading-wildcard `LIKE`) or a missing index — report with measured evidence or a clear cardinality argument, not on sight.
- Multi-statement write with no transaction; read-modify-write with no locking or conditional update (lost update); a retried operation that is not idempotent; behavior that depends on an isolation level the code does not set.
- Migrations: a locking DDL statement or a single-statement backfill against a large table; a `NOT NULL` column added without a default; a column or table dropped while deployed code still reads it (no expand-contract sequence); no down path or no plan for a partial failure.
- `SELECT *` in a view, migration, or stored artifact that changes meaning when a column is added.
- Pagination by `LIMIT` without a deterministic `ORDER BY`, or by `OFFSET` over data that changes between pages.
- Date range expressed as a closed `BETWEEN` over a timestamp column (misses the last day's rows), or bucketing that ignores the session time zone.

## Front-end markup and styling

Applies when the change renders a user interface. See "Accessibility as Design Completeness" in `SKILL.md` for scope and severity.

- Interactive behavior attached to a `div` or `span` instead of a button, link, or form control: no keyboard activation, no role, no focus.
- Focus not moved into a dialog or newly rendered view, not trapped while a modal is open, and not restored when it closes.
- Form control with no programmatic label, and a validation message not associated with its field or not announced when it appears.
- Information conveyed by color alone; text or a control below the contrast threshold.
- Content hidden visually but still focusable, or hidden from assistive technology while still visible; any positive `tabindex`.
- Layout that breaks at 320 CSS pixels wide or at 200% zoom; motion or autoplay with no `prefers-reduced-motion` path.
