# Validation record

## V2 upgrade

The earlier upgrade was exercised on a full restored seed copy with MySQL 8.4.11 using its initialization SQL runner. The runner was used because normal local socket connections were unavailable. Test-only explicit root definers replaced implicit definers; the delivered upgrade uses the installing administrator as its definer.

The record contains **45 successful assertions**, including original row counts, two successive installations, opening balance reconciliations, deposits, transfers, reversals, fees, withdrawals, invalid amounts, duplicate keys, missing accounts, frozen-account rejection, repayment allocation, interest posting, immutable records, and an injected ledger error proving rollback of the account, transaction and operation.

A repeated approval rejection appears twice in the count; the count does not mean 45 distinct system capabilities. One test labeled a closed-account case had no Closed account available and therefore exercised rejection of a missing account. The high loan-payment test can fail at the funds check before reaching the overpayment check. These do not establish dedicated coverage of all closed-account and overpayment paths.

Approval logic was tested by changing a test fixture's requester identity, not by logging in as two real users. Live role authentication, concurrent sessions, event-scheduler operation, DbGate execution and MySQL 26.7 remain unverified.

[Recorded assertions](../tests/upgrade_test_results.tsv) are included. [mysql_smoke_test.sql](../tests/mysql_smoke_test.sql) is for a disposable SEED database only: it deliberately changes test balances and creates helper objects. It is not an installation script and is not valid for the expanded count baseline without adapting assertions.

## Snapshot analysis

Amounts are parsed as integer AZN cents before aggregation. The seed checks include nonpositive transaction amounts, ownership/branch mismatches, orphan samples, negative balances, invalid outstanding principal, impossible chronology, annual-summary arithmetic, account balance replay and branch balance rollups. These checks passed for the supplied snapshot. A pass does not establish realism or completeness.

## Expanded history

The generation manifest in analysis/expanded_metrics.json records the final count and generation checks. Each customer has 1–80 rows in every month of 2025. The generator replays each account's activity in date order and asserts nonnegative running balances, unchanged closing balances and unchanged fees. Counts and dates are derived from the generated rows.

An independent streaming replay of the written SQL passed: **14,585,400 transactions**, **360,000 customer-months**, monthly minimum **1**, maximum **80**, and zero closing-balance mismatches, fee mismatches, negative running balances, ID gaps/duplicates or owner/branch mismatches. See [expanded_validation.json](../analysis/expanded_validation.json).

Generation and replay validation are not the same as a full MySQL import. The multi-million-row expanded restore and V2 on that larger instance require the user's import/health-check evidence. No successful full expanded import is claimed.
