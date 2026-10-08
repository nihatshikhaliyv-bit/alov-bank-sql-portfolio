# Validation record

Validated 6 October 2026. Reporting cutoff: 31 December 2025 inclusive.

## Executed checks

- **9 Python behavioural tests passed** against the actual generator: interest freeze while days overdue grow; fresh episode after cure; partial-payment non-reset; no future cash/restructuring; principal conservation; 12-calendar-month date; exclusion reset across another loan; no use of future arrears in current lending decisions; restructured rate effective from the correct day.
- **32 full-dataset SQL checks returned zero issues** in MySQL Community Server **8.4.11** on Linux. See `mysql_check_results.tsv`.
- All 30,000 customers and 16,000 loans were loaded, together with 1,980,000 monthly income observations, 654,730 payment records, 718,931 loan month-end records, 97,039 arrears episodes, 930 restructurings, and 360,000 lending assessments.
- SQL checks cover principal/interest conservation, no negative balances, the interest cap, cutoff dates, payment components, rate-change provenance, income coverage, premises counts, lease/asset/withholding rollforwards, corporate-tax reconciliation, branch totals and blocked lending limits.
- Generation also asserts every loan's original principal minus principal paid equals outstanding principal, and accrued interest minus interest paid equals interest receivable.
- The SQL artifact's SHA-256 matches `results.json`.

## Test environment and limits

The server was run through its disposable initialization SQL runner, not through a normal network connection. The harness joins SQL statement lines and supplies `root@localhost` as the view definer because initialization has no logged-in client identity. The distributed SQL leaves the definer to the importing user. All generated data and the check queries are otherwise the same.

An earlier draft failed because overlapping generation left malformed trailing text. It was replaced by a clean, sequential rebuild and its hash was verified. The generator now uses an exclusive build lock and writes SQL to a temporary file before replacement. A separate bootstrap-only view-definer issue was handled in the test harness. Neither failed draft is the delivered SQL.

The delivered artifact completed the full import and checks successfully. The user's Windows MySQL 26.7 installation, normal CLI connection, concurrent transactions, performance on the user's computer, and real banking permissions were **not** tested here. No claims are made about production readiness, complete legal/tax compliance, regulatory returns, or a consolidated historical GL.

Run `06_checks.sql` after the local import; do not rely solely on a completion message.
